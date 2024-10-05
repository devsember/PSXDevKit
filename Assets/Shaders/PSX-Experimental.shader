Shader "PSX/Experimental"
{
    Properties
    {
		[MainColor] [HDR] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
		[MainTexture] _BaseMap("Base Texture", 2D) = "white" {}
		_ResolutionLimit("Resolution Limit (Power of 2)", Integer) = 64
		_SnapsPerUnit("Snapping Points per Unit", Range(32, 100)) = 50
		_ColorBitDepth("Bit Depth", Integer) = 64
		_ColorBitDepthOffset("Bit Depth Offset", Range(0.0, 1.0)) = 0.0
		_AmbientLight("Ambient Light Strength", Range(0.0, 1.0)) = 0.2
		_MaxLightIntensity("Max Light Intensity", Range(0.0, 10.0)) = 2.0
    	_ZBias("Z-Bias", Range(-1, 10)) = 0
		[Toggle] _USE_FOG("Use Fog", Float) = 1
		[Toggle] _USE_AFFINE_TEXTURES("Use Affine Texture Mapping", Float) = 1
		[Toggle] _USE_POINT_FILTER("Use Point Filtering", Float) = 1
		[Toggle] _USE_AMBIENT_OVERRIDE("Ambient Light Override", Float) = 1
		[ToggleUI] _AlphaClip("Alpha Clip", Float) = 0.0
		[HideInInspector] _Cutoff("Alpha Clip Threshold", Range(0.0, 1.0)) = 0.5
		[HideInInspector] _SrcBlend("__src", Float) = 1.0
		[HideInInspector] _DstBlend("__dst", Float) = 0.0
		[HideInInspector] _ZWrite("__zw", Float) = 1.0
		[HideInInspector] _Cull("_Cull", Float) = 2.0
		[HideInInspector] _Surface("_Surface", Float) = 0.0

    	// Fog properties (to be set by the material component)
        [HideInInspector] _FogColor("Fog Color", Color) = (0.5, 0.5, 0.5, 1.0)
        [HideInInspector] _FogDepthMin("Fog Depth Min", Float) = 0.0
        [HideInInspector] _FogDepthMax("Fog Depth Max", Float) = 20.0
    }
    SubShader
    {
		Tags
		{
			"RenderType" = "Opaque"
			"Queue" = "Geometry"
			"RenderPipeline" = "UniversalPipeline"
		}

		HLSLINCLUDE
		#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
		#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/GlobalSamplers.hlsl"
		ENDHLSL

        Pass
        {
			Name "VertexLit"

			Tags
			{
				"LightMode" = "UniversalForwardOnly"
			}

			Blend[_SrcBlend][_DstBlend]
			ZWrite[_ZWrite]
			Cull[_Cull]

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_fog
			#pragma multi_compile_instancing
			#include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
			#pragma multi_compile _ _ADDITIONAL_LIGHTS
			#pragma multi_compile _ _ADDITIONAL_LIGHT_SHADOWS
			#pragma multi_compile_fragment _ _SHADOWS_SOFT
			#pragma multi_compile _ _FORWARD_PLUS

			#pragma shader_feature_local_fragment _ALPHATEST_ON
			#pragma shader_feature_local _USE_AFFINE_TEXTURES_ON
			#pragma shader_feature_local _USE_POINT_FILTER_ON
			#pragma shader_feature_local _USE_AMBIENT_OVERRIDE
            #pragma shader_feature_local _USE_FOG_ON
            #pragma shader_feature_local _FOG_OVERRIDE_ON

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "PSXSurfaceInput.hlsl"

			#define EPSILON 1e-06
            

            struct appdata
		    {
		        float4 positionOS : POSITION;
		        float4 color : COLOR;
		        float3 normalOS : NORMAL;
		        float2 uv : TEXCOORD0;
		        UNITY_VERTEX_INPUT_INSTANCE_ID
		    };

		    struct v2f
		    {
		        float4 positionCS : SV_POSITION;
		    	float4 color : COLOR;
		#if _USE_AFFINE_TEXTURES_ON
		        noperspective float2 uv : TEXCOORD0;
		#else
		        float2 uv : TEXCOORD0;
		#endif
		        float3 positionWS : TEXCOORD1;
		        float3 lightColor : TEXCOORD2;
		        float fogDensity : TEXCOORD3;
		        UNITY_VERTEX_INPUT_INSTANCE_ID
		        UNITY_VERTEX_OUTPUT_STEREO
		    };



			v2f vert(appdata v)
			{
			    v2f o = (v2f)0;
			    UNITY_SETUP_INSTANCE_ID(v);
			    UNITY_TRANSFER_INSTANCE_ID(v, o);
			    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);
				
			    // Improved Vertex Snapping
                float4 positionVS = mul(UNITY_MATRIX_V, mul(UNITY_MATRIX_M, v.positionOS));
                positionVS.xyz = floor(positionVS.xyz * (_SnapsPerUnit * 3)) / (_SnapsPerUnit * 3);
                
                // Apply Z-bias
                positionVS.z += _ZBias * 0.01;
                
                o.positionCS = mul(UNITY_MATRIX_P, positionVS);

			    o.positionWS = TransformObjectToWorld(v.positionOS.xyz);
			    o.uv = TRANSFORM_TEX(v.uv, _BaseMap);

			    // Depth cueing calculation
			    float depth = abs(mul(UNITY_MATRIX_MV, float4(v.positionOS.xyz, 1.0)).z);
			    o.fogDensity = saturate((depth - _FogDepthMin) / (_FogDepthMax - _FogDepthMin));

			    float3 normalWS = normalize(TransformObjectToWorldNormal(v.normalOS));

			    // Modified lighting calculation
			    float3 ambientLight = _AmbientLight;
			    float4 shadowCoord = TransformWorldToShadowCoord(mul(UNITY_MATRIX_M, v.positionOS));
			    float4 shadowMask = SAMPLE_SHADOWMASK(v.dynamicLightmapUV);

			    Light light = GetMainLight(shadowCoord);
			    float lightAmount = saturate(dot(normalWS, light.direction) * light.distanceAttenuation * light.shadowAttenuation);
			    float3 lightColor = lerp(ambientLight, 1.0f, min(lightAmount, _MaxLightIntensity)) * light.color;

			    #ifdef _USE_AMBIENT_OVERRIDE
			        lightColor += ambientLight;
			    #endif

			    #ifdef _ADDITIONAL_LIGHTS
			        uint lightCount = GetAdditionalLightsCount();
			        for (uint lightIndex = 0; lightIndex < lightCount; ++lightIndex)
			        {
			            Light light = GetAdditionalLight(lightIndex, mul(UNITY_MATRIX_M, v.positionOS), shadowMask);
			            float3 color = dot(light.direction, normalWS) * light.color * light.distanceAttenuation * light.shadowAttenuation;
			            lightColor += max(min(color, _MaxLightIntensity), 0.0f);
			        }
			    #endif
				o.color = v.color; // Pass vertex color to fragment shader

			    o.lightColor = lightColor * v.color;
			    return o;
			}

		float4 frag(v2f i) : SV_TARGET
		{
		    UNITY_SETUP_INSTANCE_ID(i);
		    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

		    int lod = (int)log2(_BaseMap_TexelSize.zw) - (int)log2(_ResolutionLimit);

		    #if _USE_POINT_FILTER_ON
		        float4 baseColor = _BaseColor * SAMPLE_TEXTURE2D_LOD(_BaseMap, sampler_PointRepeat, i.uv, lod);
		    #else
		        float4 baseColor = _BaseColor * SAMPLE_TEXTURE2D_LOD(_BaseMap, sampler_LinearRepeat, i.uv, lod);
		    #endif

		    #ifdef _ALPHATEST_ON
		        clip(baseColor.a - _Cutoff);
		    #endif

		    float3 posterizedColor = float3(
		        (baseColor.r - EPSILON) * _ColorBitDepth,
		        (baseColor.g - EPSILON) * _ColorBitDepth,
		        (baseColor.b - EPSILON) * _ColorBitDepth
		    ) / (_ColorBitDepth - 1.0f) + 1.0f / _ColorBitDepth * _ColorBitDepthOffset;

		    float3 finalColor = posterizedColor * i.lightColor * i.color.rgb;
            
            #if _USE_FOG_ON
            finalColor = lerp(finalColor, _FogColor.rgb, i.fogDensity);
            #endif

		    return float4(finalColor, baseColor.a);
			}
            ENDHLSL
        }

		Pass
		{
			Name "ShadowCaster"

			Tags
			{
				"LightMode" = "ShadowCaster"
			}

			ZWrite On
			ZTest LEqual

			HLSLPROGRAM
			#pragma vertex shadowPassVert
			#pragma fragment shadowPassFrag

			#pragma multi_compile_instancing
			#include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

			#pragma shader_feature_local_fragment _ALPHATEST_ON
			#pragma shader_feature_local _USE_POINT_FILTER_ON

			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/Common.hlsl"
			#include "Packages/com.unity.render-pipelines.core/ShaderLibrary/CommonMaterial.hlsl"
			#include "PSXSurfaceInput.hlsl"
			#include "PSXShadowCasterPass.hlsl"
			ENDHLSL
		}

		Pass
		{
			Name "DepthOnly"

			Tags
			{
				"LightMode" = "DepthOnly"
			}

			ZWrite On
			ColorMask R
			Cull[_Cull]

			HLSLPROGRAM
			#pragma target 2.0
			#pragma vertex depthOnlyVert
			#pragma fragment depthOnlyFrag

			#pragma multi_compile_instancing
			#include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

			#pragma shader_feature_local_fragment _ALPHATEST_ON
			#pragma shader_feature_local _USE_POINT_FILTER_ON

			#include "PSXSurfaceInput.hlsl"
			#include "PSXDepthOnlyPass.hlsl"

			ENDHLSL
		}

		Pass
		{
			Name "DepthNormals"

			Tags
			{
				"LightMode" = "DepthNormals"
			}

			ZWrite On
			Cull[_Cull]

			HLSLPROGRAM
			#pragma target 2.0
			#pragma vertex depthNormalsVert
			#pragma fragment depthNormalsFrag

			#pragma multi_compile_instancing
			#include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

			#pragma shader_feature_local_fragment _ALPHATEST_ON
			#pragma shader_feature_local _USE_POINT_FILTER_ON

			#include "PSXSurfaceInput.hlsl"
			#include "PSXDepthNormalsPass.hlsl"
			ENDHLSL
		}

		Pass
		{
			Name "Meta"

			Tags
			{
				"LightMode" = "Meta"
			}

			Cull Off

			HLSLPROGRAM
			#pragma target 2.0
			#pragma vertex metaVert
			#pragma fragment metaFrag

			#pragma shader_feature_local_fragment _ALPHATEST_ON
			#pragma shader_feature_local _USE_AFFINE_TEXTURES_ON
			#pragma shader_feature_local _USE_POINT_FILTER_ON
			#pragma shader_feature EDITOR_VISUALIZATION

			#include "PSXSurfaceInput.hlsl"
			#include "PSXMetaPass.hlsl"
			ENDHLSL
		}
    }

	CustomEditor "PSXShaderGUI"
}
Shader "PSX/Vertex Lit"
{
    Properties
    {
		[MainColor] [HDR] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
		[MainTexture] _BaseMap("Base Texture", 2D) = "white" {}
		_ResolutionLimit("Resolution Limit (Power of 2)", Integer) = 64
		_SnapsPerUnit("Snapping Points per Meter", Integer) = 64
		_ColorBitDepth("Bit Depth", Integer) = 64
		_ColorBitDepthOffset("Bit Depth Offset", Range(0.0, 1.0)) = 0.0
		_AmbientLight("Ambient Light Strength", Range(0.0, 1.0)) = 0.2
		_MaxLightIntensity("Max Light Intensity", Range(0.0, 10.0)) = 2.0
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

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "PSXSurfaceInput.hlsl"

			#define EPSILON 1e-06

            struct appdata
            {
				float4 positionOS : POSITION;
				float4 color : COLOR;
				float3 normalOS : NORMAL;
                float2 uv : TEXCOORD0;
				float2 dynamicLightmapUV : TEXCOORD1;
				UNITY_VERTEX_INPUT_INSTANCE_ID
            };

            struct v2f
            {
				float4 positionCS : SV_POSITION;
#if _USE_AFFINE_TEXTURES_ON
				noperspective float2 uv : TEXCOORD0;
#else
				float2 uv : TEXCOORD0;
#endif
				float fog : TEXCOORD1;
				float3 lightColor : TEXCOORD2;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
            };

			v2f vert(appdata v)
			{
			    v2f o = (v2f)0;
			    UNITY_SETUP_INSTANCE_ID(v);
			    UNITY_TRANSFER_INSTANCE_ID(v, o);
			    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				// Vertex Snapping
			    float4 positionVS = mul(UNITY_MATRIX_MV, v.positionOS);
			    positionVS = floor(positionVS * _SnapsPerUnit) / _SnapsPerUnit;
			    o.positionCS = mul(UNITY_MATRIX_P, positionVS);

			    o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
			    o.fog = ComputeFogFactor(o.positionCS.z);

			    float3 normalWS = TransformObjectToWorldNormal(v.normalOS);
			    float3 normalDir = normalize(normalWS);

			    // Modified lighting calculation
			    float3 ambientLight = _AmbientLight;
			    float3 positionWS = mul(UNITY_MATRIX_M, v.positionOS);
			    float4 shadowCoord = TransformWorldToShadowCoord(positionWS);
			    float4 shadowMask = SAMPLE_SHADOWMASK(v.dynamicLightmapUV);

			    // Apply the main light with intensity control
			    Light light = GetMainLight(shadowCoord);
			    float lightAmount = saturate(dot(normalDir, light.direction) * light.distanceAttenuation * light.shadowAttenuation);
			    lightAmount = min(lightAmount, _MaxLightIntensity); // Clamp the light intensity
			    float3 lightColor = lerp(ambientLight, 1.0f, lightAmount) * light.color;

			    // Apply ambient override if enabled
			    #ifdef _USE_AMBIENT_OVERRIDE
			        lightColor += ambientLight;
			    #endif

			#ifdef _ADDITIONAL_LIGHTS
			    // Apply secondary lights.
			    uint lightCount = GetAdditionalLightsCount();
			    for (uint lightIndex = 0; lightIndex < lightCount; ++lightIndex)
			    {
			        Light light = GetAdditionalLight(lightIndex, positionWS, shadowMask);

			        float3 color = dot(light.direction, normalDir);
			        color *= light.color;
			        color *= light.distanceAttenuation;
			        color *= light.shadowAttenuation;
			        color = min(color, _MaxLightIntensity); // Clamp the additional light intensity
			        color = max(color, 0.0f);

			        lightColor += color;
			    }
			#endif
			    o.lightColor = lightColor * v.color;

			    return o;
			}

			float4 frag(v2f i) : SV_TARGET
			{
				UNITY_SETUP_INSTANCE_ID(i);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

				int targetResolution = (int)log2(_ResolutionLimit);
				int actualResolution = (int)log2(_BaseMap_TexelSize.zw);
				int lod = actualResolution - targetResolution;

#if _USE_POINT_FILTER_ON
				float4 baseColor = _BaseColor * SAMPLE_TEXTURE2D_LOD(_BaseMap, sampler_PointRepeat, i.uv, lod);
#else
				float4 baseColor = _BaseColor * SAMPLE_TEXTURE2D_LOD(_BaseMap, sampler_LinearRepeat, i.uv, lod);
#endif

#ifdef _ALPHATEST_ON
				clip(baseColor.a - _Cutoff);
#endif

				int r = (baseColor.r - EPSILON) * _ColorBitDepth;
				int g = (baseColor.g - EPSILON) * _ColorBitDepth;
				int b = (baseColor.b - EPSILON) * _ColorBitDepth;

				float divisor = _ColorBitDepth - 1.0f;

				float3 posterizedColor = float3(r, g, b) / divisor;
				posterizedColor += 1.0f / _ColorBitDepth * _ColorBitDepthOffset;

				float3 finalColor = posterizedColor * i.lightColor;
				finalColor = MixFog(finalColor.rgb, i.fog);

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

	CustomEditor "PSXShadersPro.URP.PSXLitShaderGUI"
}
Shader "PSX Shaders Pro/PSX Lit"
{
    Properties
    {
		[MainColor] [HDR] _BaseColor("Base Color", Color) = (1, 1, 1, 1)
		[MainTexture] _BaseMap("Base Texture", 2D) = "white" {}
		_ResolutionLimit("Resolution Limit (Power of 2)", Integer) = 64
		_SnapsPerUnit("Snapping Points per Meter", Integer) = 64
		_ColorBitDepth("Bit Depth", Integer) = 64
		_ColorBitDepthOffset("Bit Depth Offset", Range(0.0, 1.0)) = 0.0
		_AmbientLight("Ambient Light Strength", Range(0.0, 1.0)) = 0.02
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
			Tags
			{
				"LightMode" = "UniversalForward"
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

			#pragma multi_compile _ EVALUATE_SH_MIXED EVALUATE_SH_VERTEX
			#pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
			#pragma multi_compile _ SHADOWS_SHADOWMASK
			#pragma multi_compile _ DIRLIGHTMAP_COMBINED
			#pragma multi_compile _ LIGHTMAP_ON
			#pragma multi_compile _ DYNAMICLIGHTMAP_ON

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
				float4 color : COLOR;
#if _USE_AFFINE_TEXTURES_ON
                noperspective float2 uv : TEXCOORD0;
#else
				float2 uv : TEXCOORD0;
#endif
				float fog : TEXCOORD1;
				float3 normalWS : TEXCOORD2;
				float3 positionWS : TEXCOORD3;
				float3 viewWS : TEXCOORD4;
				float2 dynamicLightmapUV : TEXCOORD5;
				UNITY_VERTEX_INPUT_INSTANCE_ID
				UNITY_VERTEX_OUTPUT_STEREO
            };

			v2f vert(appdata v)
			{
				v2f o = (v2f)0;
				UNITY_SETUP_INSTANCE_ID(v);
				UNITY_TRANSFER_INSTANCE_ID(v, o);
				UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

				float4 positionVS = mul(UNITY_MATRIX_MV, v.positionOS);
				positionVS = floor(positionVS * _SnapsPerUnit) / _SnapsPerUnit;
				o.positionCS = mul(UNITY_MATRIX_P, positionVS);

				o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
				o.fog = ComputeFogFactor(o.positionCS.z);
				o.normalWS = TransformObjectToWorldNormal(v.normalOS);
				o.positionWS = mul(UNITY_MATRIX_M, v.positionOS);
				o.viewWS = GetWorldSpaceNormalizeViewDir(o.positionWS);
				o.dynamicLightmapUV = v.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
				o.color = v.color;

				return o;
			}

			float4 frag(v2f i) : SV_TARGET
			{
				UNITY_SETUP_INSTANCE_ID(i);
				UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

				// Apply resolution limit to the base texture.
				int targetResolution = (int)log2(_ResolutionLimit);
				int actualResolution = (int)log2(_BaseMap_TexelSize.zw);
				int lod = actualResolution - targetResolution;

#if _USE_POINT_FILTER_ON
				float4 baseColor = _BaseColor * SAMPLE_TEXTURE2D_LOD(_BaseMap, sampler_PointRepeat, i.uv, lod) * i.color;
#else
				float4 baseColor = _BaseColor * SAMPLE_TEXTURE2D_LOD(_BaseMap, sampler_LinearRepeat, i.uv, lod) * i.color;
#endif

				// Clip pixels based on alpha.
#ifdef _ALPHATEST_ON
				clip(baseColor.a - _Cutoff);
#endif

				// Posterize the base color.
				int r = (baseColor.r - EPSILON) * _ColorBitDepth;
				int g = (baseColor.g - EPSILON) * _ColorBitDepth;
				int b = (baseColor.b - EPSILON) * _ColorBitDepth;

				float divisor = _ColorBitDepth - 1.0f;

				float3 posterizedColor = float3(r, g, b) / divisor;
				posterizedColor += 1.0f / _ColorBitDepth * _ColorBitDepthOffset;

				float4 shadowCoord = TransformWorldToShadowCoord(i.positionWS);
				float4 shadowMask = SAMPLE_SHADOWMASK(i.dynamicLightmapUV);

				// Apply the main light.
				Light light = GetMainLight(shadowCoord);

				float3 normalDir = normalize(i.normalWS);
				float lightAmount = saturate(dot(normalDir, light.direction) * light.distanceAttenuation * light.shadowAttenuation);
#ifndef _USE_AMBIENT_OVERRIDE
				float3 lightColor = lerp(SampleSH(normalDir), 1.0f, lightAmount) * light.color;
#else
				float3 lightColor = lerp(_AmbientLight, 1.0f, lightAmount) * light.color;
#endif

#ifdef _ADDITIONAL_LIGHTS

				// Apply secondary lights.
				uint lightCount = GetAdditionalLightsCount();

#if USE_FORWARD_PLUS
				InputData inputData = (InputData)0;
				inputData.positionWS = i.positionWS;
				inputData.normalWS = i.normalWS;
				inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(i.positionWS);
				inputData.shadowCoord = shadowCoord;

				float4 screenPos = float4(i.positionCS.x, (_ScaledScreenParams.y - i.positionCS.y), 0, 0);
				inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(screenPos);

				// Apply secondary lights (Forward+ rendering).
				LIGHT_LOOP_BEGIN(lightsCount)
					Light light = GetAdditionalLight(lightIndex, i.positionWS, shadowMask);

					float3 color = dot(light.direction, normalDir);
					color *= light.color;
					color *= light.distanceAttenuation;
					color *= light.shadowAttenuation;
					//color = max(color, 0.0f);

					lightColor += color;
				LIGHT_LOOP_END

#else
				// Apply secondary lights (Forward rendering).
				for (uint lightIndex = 0; lightIndex < lightCount; ++lightIndex) 
				{
					Light light = GetAdditionalLight(lightIndex, i.positionWS, shadowMask);

					float3 color = dot(light.direction, normalDir);
					color *= light.color;
					color *= light.distanceAttenuation;
					color *= light.shadowAttenuation;
					//color = max(color, 0.0f);

					lightColor += color;
				}
#endif
#endif

				// Combine everything.
				float3 finalColor = posterizedColor * lightColor;
				finalColor = MixFog(finalColor, i.fog);

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
			ColorMask 0
			Cull[_Cull]

			HLSLPROGRAM
			#pragma vertex shadowPassVert
			#pragma fragment shadowPassFrag

			#pragma multi_compile_instancing
			#include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

			#pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
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
			Name "GBuffer"

			Tags
			{
				"LightMode" = "UniversalGBuffer"
			}

			ZWrite[_ZWrite]
			ZTest LEqual
			Cull[_Cull]

			HLSLPROGRAM
			#pragma target 4.5
			#pragma exclude_renderers gles3 glcore

			//#pragma vertex gBufferVert
			//#pragma fragment gBufferFrag

			#pragma multi_compile_instancing
			#include_with_pragmas "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DOTS.hlsl"

			#pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
			#pragma multi_compile _ SHADOWS_SHADOWMASK
			#pragma multi_compile_fragment _ _SHADOWS_SOFT

			#pragma multi_compile _ LIGHTMAP_ON
			#pragma multi_compile _ DIRLIGHTMAP_COMBINED                       
			#pragma multi_compile _ LIGHTMAP_SHADOW_MIXING
			#pragma multi_compile _ DYNAMICLIGHTMAP_ON

			#pragma multi_compile_fragment _ _GBUFFER_NORMALS_OCT

			#pragma shader_feature_local_fragment _ALPHATEST_ON
			#pragma shader_feature_local _USE_AFFINE_TEXTURES_ON
			#pragma shader_feature_local _USE_POINT_FILTER_ON

			#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
			#include "PSXSurfaceInput.hlsl"
			#include "PSXGBufferPass.hlsl"

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

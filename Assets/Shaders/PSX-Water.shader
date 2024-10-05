Shader "PSX/Water"
{
    Properties
    {
        [MainColor] [HDR] _BaseColor("Base Color", Color) = (0.2, 0.6, 0.8, 0.6)
        [MainTexture] _BaseMap("Base Texture", 2D) = "white" {}
        _WaveTexture("Wave Texture", 2D) = "bump" {}
        _WaveSpeed("Wave Speed", Float) = 0.5
        _WaveStrength("Wave Strength", Range(0, 1)) = 0.1
        _ResolutionLimit("Resolution Limit (Power of 2)", Int) = 64
        _SnapsPerUnit("Snapping Points per Unit", Range(32, 100)) = 50
        _ColorBitDepth("Bit Depth", Int) = 64
        _ColorBitDepthOffset("Bit Depth Offset", Range(0.0, 1.0)) = 0.0
        _AmbientLight("Ambient Light Strength", Range(0.0, 1.0)) = 0.2
        _MaxLightIntensity("Max Light Intensity", Range(0.0, 10.0)) = 2.0
        _FogColor("Fog Color", Color) = (0.5, 0.5, 0.5, 1.0)
        _FogDepthMin("Fog Depth Min", Float) = 0.0
        _FogDepthMax("Fog Depth Max", Float) = 20.0
        [Toggle] _USE_FOG("Use Fog", Float) = 1
        [Toggle] _USE_AFFINE_TEXTURES("Use Affine Texture Mapping", Float) = 1
        [Toggle] _USE_POINT_FILTER("Use Point Filtering", Float) = 1
        [Toggle] _USE_AMBIENT_OVERRIDE("Ambient Light Override", Float) = 1

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
            "RenderType" = "Transparent"
            "Queue" = "Transparent"
            "RenderPipeline" = "UniversalPipeline"
        }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
        ENDHLSL

        Pass
        {
            Name "WaterForward"

            Tags
            {
                "LightMode" = "UniversalForward"
            }

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite[_ZWrite]
            Cull[_Cull]

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma multi_compile_fog
            #pragma multi_compile_instancing
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS _MAIN_LIGHT_SHADOWS_CASCADE _MAIN_LIGHT_SHADOWS_SCREEN
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #pragma shader_feature_local _USE_AFFINE_TEXTURES
            #pragma shader_feature_local _USE_POINT_FILTER
            #pragma shader_feature_local _USE_AMBIENT_OVERRIDE
            #pragma shader_feature_local _USE_FOG

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
                #if _USE_AFFINE_TEXTURES
                noperspective float2 uv : TEXCOORD0;
                #else
                float2 uv : TEXCOORD0;
                #endif
                float3 positionWS : TEXCOORD1;
                float3 normalWS : TEXCOORD2;
                float fogFactor : TEXCOORD3;
                float4 color : COLOR;
                UNITY_VERTEX_INPUT_INSTANCE_ID
                UNITY_VERTEX_OUTPUT_STEREO
            };

            CBUFFER_START(UnityPerMaterial)
            float4 _BaseColor;
            float4 _BaseMap_ST;
            float4 _WaveTexture_ST;
            float _WaveSpeed;
            float _WaveStrength;
            int _ResolutionLimit;
            float _SnapsPerUnit;
            int _ColorBitDepth;
            float _ColorBitDepthOffset;
            float _AmbientLight;
            float _MaxLightIntensity;
            float4 _FogColor;
            float _FogDepthMin;
            float _FogDepthMax;
            CBUFFER_END

            TEXTURE2D(_BaseMap);
            SAMPLER(sampler_BaseMap);
            TEXTURE2D(_WaveTexture);
            SAMPLER(sampler_WaveTexture);

            #define EPSILON 1e-06

            v2f vert(appdata v)
            {
                v2f o = (v2f)0;
                UNITY_SETUP_INSTANCE_ID(v);
                UNITY_TRANSFER_INSTANCE_ID(v, o);
                UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

                // Improved Vertex Snapping
                float4 positionVS = mul(UNITY_MATRIX_V, mul(UNITY_MATRIX_M, v.positionOS));
                positionVS.xyz = floor(positionVS.xyz * (_SnapsPerUnit * 3)) / (_SnapsPerUnit * 3);
                o.positionCS = mul(UNITY_MATRIX_P, positionVS);

                o.positionWS = TransformObjectToWorld(v.positionOS.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _BaseMap);
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);

                // Fog calculation
                o.fogFactor = ComputeFogFactor(o.positionCS.z);

                // Lighting calculation
                float3 ambientLight = _AmbientLight;
                float3 lightColor = 0;

                #ifdef _MAIN_LIGHT_SHADOWS
                    float4 shadowCoord = TransformWorldToShadowCoord(o.positionWS);
                    Light mainLight = GetMainLight(shadowCoord);
                #else
                    Light mainLight = GetMainLight();
                #endif

                float lightAmount = saturate(dot(o.normalWS, mainLight.direction) * mainLight.distanceAttenuation * mainLight.shadowAttenuation);
                lightColor = lerp(ambientLight, 1.0f, min(lightAmount, _MaxLightIntensity)) * mainLight.color;

                #ifdef _USE_AMBIENT_OVERRIDE
                    lightColor += ambientLight;
                #endif

                #ifdef _ADDITIONAL_LIGHTS_VERTEX
                    uint lightsCount = GetAdditionalLightsCount();
                    for (uint lightIndex = 0u; lightIndex < lightsCount; ++lightIndex)
                    {
                        Light light = GetAdditionalLight(lightIndex, o.positionWS);
                        float3 color = light.color * light.distanceAttenuation * light.shadowAttenuation;
                        lightColor += max(min(color, _MaxLightIntensity), 0.0f);
                    }
                #endif

                o.color = float4(lightColor * v.color.rgb, v.color.a);
                return o;
            }

            float4 frag(v2f i) : SV_TARGET
            {
                UNITY_SETUP_INSTANCE_ID(i);
                UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(i);

                float2 uv = i.uv;
                #if _USE_POINT_FILTER
                    float4 baseColor = _BaseColor * SAMPLE_TEXTURE2D(_BaseMap, sampler_PointClamp, uv);
                #else
                    float4 baseColor = _BaseColor * SAMPLE_TEXTURE2D(_BaseMap, sampler_BaseMap, uv);
                #endif

                // Sample wave texture
                float2 waveUV = uv * _WaveTexture_ST.xy + _WaveTexture_ST.zw + _Time.y * _WaveSpeed;
                float3 waveNormal = UnpackNormal(SAMPLE_TEXTURE2D(_WaveTexture, sampler_WaveTexture, waveUV));

                // Apply wave distortion
                float3 viewDir = GetWorldSpaceNormalizeViewDir(i.positionWS);
                float3 reflectionDir = reflect(-viewDir, normalize(i.normalWS + waveNormal * _WaveStrength));
                float fresnel = pow(1.0 - saturate(dot(viewDir, reflectionDir)), 5.0);

                float3 posterizedColor = float3(
                    (baseColor.r - EPSILON) * _ColorBitDepth,
                    (baseColor.g - EPSILON) * _ColorBitDepth,
                    (baseColor.b - EPSILON) * _ColorBitDepth
                ) / (_ColorBitDepth - 1.0f) + 1.0f / _ColorBitDepth * _ColorBitDepthOffset;

                float3 finalColor = posterizedColor * i.color.rgb;
                finalColor = lerp(finalColor, finalColor + fresnel, _WaveStrength);
        
                #if defined(_USE_FOG)
                    float3 foggedColor = MixFog(finalColor, i.fogFactor);
                    finalColor = lerp(finalColor, foggedColor, smoothstep(_FogDepthMin, _FogDepthMax, length(i.positionWS - _WorldSpaceCameraPos)));
                #endif

                return float4(finalColor, baseColor.a);
            }
            ENDHLSL
        }
    }

    //CustomEditor "PSX.URP.PSXShaderGUI"
}
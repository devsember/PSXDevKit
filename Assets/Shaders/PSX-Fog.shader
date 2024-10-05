Shader "Hidden/PSX/Fog"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _FogColor ("Fog Color", Color) = (0.5, 0.5, 0.5, 1)
        _FogDepthMin ("Fog Depth Min", Float) = 0.0
        _FogDepthMax ("Fog Depth Max", Float) = 20.0
        _EnableDithering ("Enable Dithering", Float) = 1.0
        _DitheringIntensity ("Dithering Intensity", Float) = 1.0
        _DownscaleFactor ("Downscale Factor", Float) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline"}
        LOD 100

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
        
        ENDHLSL

        Pass
        {
            Name "PSX Fog with Linear Depth Cueing and Dithering"
            ZTest Always
            ZWrite Off
            Cull Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float2 uv : TEXCOORD0;
                float4 positionCS : SV_POSITION;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);
            float4 _MainTex_ST;

            float4 _FogColor;
            float _FogDepthMin;
            float _FogDepthMax;
            float _EnableDithering;
            float _DitheringIntensity;
            float _DownscaleFactor;

            // PS1 dither table
            static const float4x4 psx_dither_table = float4x4
            (
                0,    8,    2,    10,
                12,   4,    14,   6, 
                3,    11,   1,    9, 
                15,   7,    13,   5
            );

            float3 DitherCrunch(float3 col, float2 pos)
            {
                col *= 255.0;
                float3 result = col;
                if (_EnableDithering > 0.5)
                {
                    int2 p = int2(pos);
                    int dither = psx_dither_table[p.x % 4][p.y % 4];
                    result += (dither / 2.0 - 4.0) * _DitheringIntensity;
                }
                result = lerp(floor(result / 8.0) * 8.0, 248.0, step(248.0, result));
                result /= 255.0;
                return result;
            }

            Varyings vert (Attributes input)
            {
                Varyings output;
                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                return output;
            }

            float4 frag (Varyings input) : SV_Target
            {
                float4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
                
                // Sample the depth texture
                float rawDepth = SampleSceneDepth(input.uv);
                
                // Convert to linear depth
                float sceneDepth = LinearEyeDepth(rawDepth, _ZBufferParams);
                
                // Calculate fog factor using linear interpolation
                float fogFactor = saturate((sceneDepth - _FogDepthMin) / (_FogDepthMax - _FogDepthMin));
                
                // Apply fog
                float4 foggedColor = lerp(col, _FogColor, fogFactor);
                
                // Apply dithering
                float2 fragCoord = floor(input.positionCS.xy / _DownscaleFactor);
                foggedColor.rgb = DitherCrunch(foggedColor.rgb, fragCoord);
                
                return foggedColor;
            }
            ENDHLSL
        }
    }
}
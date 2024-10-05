Shader "Hidden/PSX/PSXEffects"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _DownscaleFactor ("Downscale Factor", Float) = 1.0
        _DitheringIntensity ("Dithering Intensity", Float) = 1.0
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline"}
        
        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        
        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        float4 _CameraAspectModeUVScaleBias;
        float _EnableDithering;
        float _DitheringIntensity;
        float _DownscaleFactor;
        CBUFFER_END
        
        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        
        struct Attributes
        {
            float4 positionOS : POSITION;
            float2 uv : TEXCOORD0;
        };
        
        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float2 uv : TEXCOORD0;
        };
        
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
        
        Varyings Vert(Attributes input)
        {
            Varyings output;
            output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
            output.uv = TRANSFORM_TEX(input.uv, _MainTex);
            return output;
        }
        
        float2 ApplyAspectRatio(float2 uv)
        {
            float2 scaledUV = uv * _CameraAspectModeUVScaleBias.xy + _CameraAspectModeUVScaleBias.zw;
            float2 outsideRange = step(1.0, abs(scaledUV - 0.5) * 2.0);
            return lerp(scaledUV, float2(-1, -1), max(outsideRange.x, outsideRange.y));
        }
        
        ENDHLSL
        
        Pass
        {
            Name "PSXEffects"
            
            HLSLPROGRAM
            #pragma vertex Vert
            #pragma fragment Frag
            
            float4 Frag(Varyings input) : SV_Target
            {
                float2 aspectCorrectedUV = ApplyAspectRatio(input.uv);
                
                if (any(aspectCorrectedUV < 0))
                {
                    return float4(0, 0, 0, 1); // Return black for areas outside the corrected aspect ratio
                }
                
                // Apply downscaling
                float2 target_res = _ScreenParams.xy / _DownscaleFactor;
                float2 pixelated_uv = floor(aspectCorrectedUV * target_res) / target_res;
                
                float4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, pixelated_uv);
                
                // Apply dithering
                float2 fragCoord = floor(input.positionCS.xy / _DownscaleFactor);
                color.rgb = DitherCrunch(color.rgb, fragCoord);
                
                return color;
            }
            ENDHLSL
        }
    }
}
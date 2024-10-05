Shader "PSX/Lit Water"
{
    Properties
    {
        _MainTex("Main Texture", 2D) = "white" {}
        _Color("Color Tint", Color) = (1, 1, 1, 1)
        _SpecGlossMap("Specular Map", 2D) = "white" {}
        _SpecColor("Specular Color", Color) = (0, 0, 0, 1)
        _Smoothness("Smoothness", Range(0.01, 1.0)) = 0.5
        [HDR] _EmissionColor("Emission Color", Color) = (0, 0, 0, 1)
        [HDR] _EmissionMap("Emission Map", 2D) = "black" {}

        _VertJitter("Jitter", Range(0.0, 0.999)) = 0.95
        _AffineMapIntensity("Affine Texture Mapping", Range(0.0, 1.0)) = 1.0
        _DrawDist("Draw Distance", Float) = 100.0
    }

    SubShader
    {
        Tags {"RenderType" = "Transparent" "RenderPipeline" = "UniversalPipeline" "Queue" = "Transparent"}

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

        CBUFFER_START(UnityPerMaterial)
        float4 _MainTex_ST;
        half4 _Color;
        half4 _SpecColor;
        half _Smoothness;
        half4 _EmissionColor;
        half _VertJitter;
        half _AffineMapIntensity;
        float _DrawDist;
        CBUFFER_END

        TEXTURE2D(_MainTex);
        SAMPLER(sampler_MainTex);
        TEXTURE2D(_SpecGlossMap);
        SAMPLER(sampler_SpecGlossMap);
        TEXTURE2D(_EmissionMap);
        SAMPLER(sampler_EmissionMap);

        struct Attributes
        {
            float4 positionOS : POSITION;
            float3 normalOS : NORMAL;
            float2 uv : TEXCOORD0;
        };

        struct Varyings
        {
            float4 positionCS : SV_POSITION;
            float2 uv : TEXCOORD0;
            float3 uv_affine : TEXCOORD1;
            half3 normalWS : TEXCOORD2;
            half3 viewDirWS : TEXCOORD3;
            half3 diffuse : COLOR0;
            half3 specular : COLOR1;
            float drawDistClip : TEXCOORD4;
        };

        float4 ScreenSnap(float4 vertex)
        {
            float geoRes = _VertJitter * 125.0f + 1.0f;
            float2 pixelPos = round((vertex.xy / vertex.w) * _ScreenParams.xy / geoRes) * geoRes;
            vertex.xy = pixelPos / _ScreenParams.xy * vertex.w;
            return vertex;
        }
        ENDHLSL

        Pass
        {
            Name "ForwardLit"
            Tags {"LightMode" = "UniversalForward"}

            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #pragma shader_feature_local _ENABLE_SCREENSPACE_JITTER
            #pragma shader_feature_local _SPECULAR_SETUP
            #pragma shader_feature_local _EMISSION
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _ADDITIONAL_LIGHTS_VERTEX _ADDITIONAL_LIGHTS
            #pragma multi_compile_fragment _ _ADDITIONAL_LIGHT_SHADOWS
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            Varyings vert(Attributes input)
            {
                Varyings output = (Varyings)0;

                VertexPositionInputs vertexInput = GetVertexPositionInputs(input.positionOS.xyz);
                VertexNormalInputs normalInput = GetVertexNormalInputs(input.normalOS);

                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                output.normalWS = normalInput.normalWS;
                output.viewDirWS = GetWorldSpaceViewDir(float4(vertexInput.positionWS, 1.0));

                #ifdef _ENABLE_SCREENSPACE_JITTER
                    output.positionCS = ScreenSnap(vertexInput.positionCS);
                #else
                    float geoRes = (_VertJitter - 1.0f) * -1000.0f;
                    float3 viewPos = TransformWorldToView(vertexInput.positionWS);
                    viewPos = floor(viewPos * geoRes) / geoRes;
                    output.positionCS = TransformWViewToHClip(viewPos);
                #endif

                float wVal = output.positionCS.w;
                output.uv_affine = float3(input.uv * wVal, wVal);

                output.drawDistClip = 0;
                if (distance(vertexInput.positionWS, GetCameraPositionWS()) > _DrawDist && _DrawDist != 0)
                    output.drawDistClip = 1;

                // Calculate lighting
                float3 normalWS = normalInput.normalWS;

                float3 vertexLight = VertexLighting(vertexInput.positionWS, normalWS);
                float3 baseColor = vertexLight;

                // Create InputData struct for GetMainLight function
                InputData inputData = (InputData)0;
                inputData.positionWS = vertexInput.positionWS;
                inputData.normalWS = normalWS;
                inputData.viewDirectionWS = output.viewDirWS;
                inputData.shadowCoord = TransformWorldToShadowCoord(vertexInput.positionWS);

                Light mainLight = GetMainLight(inputData.shadowCoord);
                float3 attenuatedLightColor = mainLight.color * mainLight.distanceAttenuation;
                float3 diffuseColor = LightingLambert(attenuatedLightColor, mainLight.direction, normalWS);
                float3 specularColor = LightingSpecular(attenuatedLightColor, mainLight.direction, normalWS, output.viewDirWS, float4(_SpecColor.rgb, _Smoothness), mainLight.shadowAttenuation);
                output.diffuse = baseColor + diffuseColor;
                output.specular = specularColor;

                return output;
            }

            half4 frag(Varyings input) : SV_Target
            {
                float2 correctUV = input.uv;
                float2 affineUV = (input.uv_affine / input.uv_affine.z).xy;
                float2 finalUV = lerp(correctUV, affineUV, _AffineMapIntensity);

                half4 color = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, finalUV) * _Color;

                #ifdef _SPECULAR_SETUP
                    half4 specGloss = SAMPLE_TEXTURE2D(_SpecGlossMap, sampler_SpecGlossMap, finalUV);
                    half3 specular = specGloss.rgb * _SpecColor.rgb;
                #else
                    half3 specular = _SpecColor.rgb;
                #endif

                #ifdef _EMISSION
                    half3 emission = SAMPLE_TEXTURE2D(_EmissionMap, sampler_EmissionMap, finalUV).rgb * _EmissionColor.rgb;
                #else
                    half3 emission = 0;
                #endif

                color.rgb = (color.rgb * input.diffuse + input.specular * specular + emission);

                if (input.drawDistClip != 0)
                    clip(-1);

                return color;
            }
            ENDHLSL
        }

        // Add Shadow Caster pass if needed
    }
}
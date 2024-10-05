#ifndef PSX_GBUFFER_PASS_INCLUDED
#define PSX_GBUFFER_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/UnityGBuffer.hlsl"
#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"
#include "PSXSurfaceInput.hlsl"

struct Attributes
{
    float4 positionOS : POSITION;
    float4 color : COLOR;
    float3 normalOS : NORMAL;
    float2 uv : TEXCOORD0;
    float2 staticLightmapUV : TEXCOORD1;
    #ifdef DYNAMICLIGHTMAP_ON
    float2 dynamicLightmapUV : TEXCOORD2;
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float4 color : COLOR;
    #if _USE_AFFINE_TEXTURES_ON
    noperspective float2 uv : TEXCOORD0;
    #else
    float2 uv : TEXCOORD0;
    #endif
    DECLARE_LIGHTMAP_OR_SH(staticLightmapUV, vertexSH, 1);
    float3 normalWS : TEXCOORD2;
    float3 positionWS : TEXCOORD3;
    #ifdef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
    float4 shadowCoord : TEXCOORD4;
    #endif
    #ifdef DYNAMICLIGHTMAP_ON
    float2 dynamicLightmapUV : TEXCOORD5;
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

FragmentOutput EncodeGBuffer(InputData inputData, SurfaceData surfaceData)
{
    FragmentOutput output;

    uint materialFlags = 0;
    #ifdef _RECEIVE_SHADOWS_OFF
    materialFlags |= kMaterialFlagReceiveShadowsOff;
    #endif
    materialFlags |= kMaterialFlagSpecularHighlightsOff;
    float materialFlagsPacked = PackMaterialFlags(materialFlags);

    // Encode normal
    output.GBuffer2.rgb = inputData.normalWS * 0.5 + 0.5;
    output.GBuffer2.a = surfaceData.smoothness;

    // Encode albedo and material flags
    output.GBuffer0 = half4(surfaceData.albedo, materialFlagsPacked);

    // Encode specular and occlusion
    output.GBuffer1 = half4(surfaceData.specular, surfaceData.occlusion);

    // Encode emission and fog
    //float3 giEmission = GlobalIllumination(BRDFData(surfaceData), inputData.bakedGI, surfaceData.occlusion, inputData.positionWS, inputData.normalWS, inputData.viewDirectionWS);
    //output.GBuffer3 = half4(giEmission + surfaceData.emission, 1.0);

    #if OUTPUT_SHADOWMASK
    output.GBUFFER_SHADOWMASK = inputData.shadowMask;
    #endif

    return output;
}

Varyings GBufferVert(Attributes input)
{
    Varyings output = (Varyings)0;
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_TRANSFER_INSTANCE_ID(input, output);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(output);

    // Improved Vertex Snapping
    float4 positionVS = mul(UNITY_MATRIX_MV, input.positionOS);
    positionVS.xyz = floor(positionVS.xyz * (_SnapsPerUnit * 3)) / (_SnapsPerUnit * 3);
    output.positionCS = mul(UNITY_MATRIX_P, positionVS);

    output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
    output.uv = TRANSFORM_TEX(input.uv, _BaseMap);

    OUTPUT_LIGHTMAP_UV(input.staticLightmapUV, unity_LightmapST, output.staticLightmapUV);
    OUTPUT_SH(output.normalWS, output.vertexSH);

    #ifdef REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR
    output.shadowCoord = TransformWorldToShadowCoord(output.positionWS);
    #endif

    #ifdef DYNAMICLIGHTMAP_ON
    output.dynamicLightmapUV = input.dynamicLightmapUV.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
    #endif

    output.color = input.color;

    return output;
}

FragmentOutput GBufferFrag(Varyings input)
{
    UNITY_SETUP_INSTANCE_ID(input);
    UNITY_SETUP_STEREO_EYE_INDEX_POST_VERTEX(input);

    int lod = (int)log2(_BaseMap_TexelSize.zw) - (int)log2(_ResolutionLimit);

    #if _USE_POINT_FILTER_ON
    float4 baseColor = _BaseColor * SAMPLE_TEXTURE2D_LOD(_BaseMap, sampler_PointRepeat, input.uv, lod) * input.color;
    #else
    float4 baseColor = _BaseColor * SAMPLE_TEXTURE2D_LOD(_BaseMap, sampler_LinearRepeat, input.uv, lod) * input.color;
    #endif

    #ifdef _ALPHATEST_ON
    clip(baseColor.a - _Cutoff);
    #endif

    // Color bit depth reduction
    baseColor.rgb = floor(baseColor.rgb * _ColorBitDepth) / (_ColorBitDepth - 1.0f) + 1.0f / _ColorBitDepth * _ColorBitDepthOffset;

    InputData inputData = (InputData)0;
    inputData.positionWS = input.positionWS;
    inputData.normalWS = normalize(input.normalWS);
    inputData.viewDirectionWS = GetWorldSpaceNormalizeViewDir(input.positionWS);

    #if defined(REQUIRES_VERTEX_SHADOW_COORD_INTERPOLATOR)
    inputData.shadowCoord = input.shadowCoord;
    #elif defined(MAIN_LIGHT_CALCULATE_SHADOWS)
    inputData.shadowCoord = TransformWorldToShadowCoord(inputData.positionWS);
    #else
    inputData.shadowCoord = float4(0, 0, 0, 0);
    #endif

    inputData.fogCoord = 0; // We don't use fog in the GBuffer pass
    inputData.vertexLighting = 0;
    inputData.bakedGI = SAMPLE_GI(input.staticLightmapUV, input.vertexSH, inputData.normalWS);
    inputData.normalizedScreenSpaceUV = GetNormalizedScreenSpaceUV(input.positionCS);
    inputData.shadowMask = SAMPLE_SHADOWMASK(input.staticLightmapUV);

    SurfaceData surfaceData = (SurfaceData)0;
    surfaceData.albedo = baseColor.rgb;
    surfaceData.alpha = baseColor.a;
    surfaceData.metallic = 0;
    surfaceData.specular = 0;
    surfaceData.smoothness = 0;
    surfaceData.occlusion = 1;
    surfaceData.emission = 0;
    surfaceData.clearCoatMask = 0;
    surfaceData.clearCoatSmoothness = 1;

    // Calculate lighting
    #ifdef _USE_AMBIENT_OVERRIDE
    float3 ambientLight = _AmbientLight;
    #else
    float3 ambientLight = 0;
    #endif

    Light mainLight = GetMainLight(inputData.shadowCoord, inputData.positionWS, inputData.shadowMask);
    float lightAmount = saturate(dot(inputData.normalWS, mainLight.direction) * mainLight.distanceAttenuation * mainLight.shadowAttenuation);
    float3 lightColor = lerp(ambientLight, 1.0f, min(lightAmount, _MaxLightIntensity)) * mainLight.color;

    #ifdef _ADDITIONAL_LIGHTS
    uint pixelLightCount = GetAdditionalLightsCount();
    for (uint lightIndex = 0u; lightIndex < pixelLightCount; ++lightIndex)
    {
        Light light = GetAdditionalLight(lightIndex, inputData.positionWS, inputData.shadowMask);
        float3 attenuatedLightColor = light.color * (light.distanceAttenuation * light.shadowAttenuation);
        lightColor += max(min(attenuatedLightColor, _MaxLightIntensity), 0.0f);
    }
    #endif

    surfaceData.emission = surfaceData.albedo * lightColor;

    return EncodeGBuffer(inputData, surfaceData);
}

#endif // PSX_GBUFFER_PASS_INCLUDED
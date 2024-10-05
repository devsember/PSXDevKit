#ifndef RETRO_META_PASS_INCLUDED
#define RETRO_META_PASS_INCLUDED

#include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/MetaInput.hlsl"

struct appdata
{
	float4 positionOS : POSITION;
	float3 normalOS : NORMAL;
	float2 uv0 : TEXCOORD0;
	float2 uv1 : TEXCOORD1;
	float2 uv2 : TEXCOORD2;
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

#ifdef EDITOR_VISUALIZATION
	float2 vizUV : TEXCOORD1;
	float4 lightCoord : TEXCOORD2;
#endif
};

v2f metaVert(appdata v)
{
	v2f o = (v2f)0;

	float3 vertex = v.positionOS.xyz;

#ifndef EDITOR_VISUALIZATION
	if (unity_MetaVertexControl.x)
	{
		vertex.xy = v.uv1 * unity_LightmapST.xy + unity_LightmapST.zw;
		vertex.z = vertex.z > 0 ? REAL_MIN : 0.0f;
	}
	if (unity_MetaVertexControl.y)
	{
		vertex.xy = v.uv2 * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
		vertex.z = vertex.z > 0 ? REAL_MIN : 0.0f;
	}
	float4 positionVS = mul(UNITY_MATRIX_V, vertex);
	//o.positionCS = TransformWorldToHClip(vertex);
#else
	float4 positionVS = mul(UNITY_MATRIX_MV, v.positionOS);
	//o.positionCS = TransformObjectToHClip(vertex);
#endif

	positionVS = floor(positionVS * _SnapsPerUnit) / _SnapsPerUnit;
	o.positionCS = mul(UNITY_MATRIX_P, positionVS);

	o.uv = TRANSFORM_TEX(v.uv0, _BaseMap);
#ifdef EDITOR_VISUALIZATION
	UnityEditorVizData(v.positionOS.xyz, v.uv0, v.uv1, v.uv2, o.vizUV, o.lightCoord);
#endif

	return o;
}

float4 metaFrag(v2f i) : SV_TARGET
{
	int targetResolution = (int)log2(_ResolutionLimit);
	int actualResolution = (int)log2(_BaseMap_TexelSize.zw);
	int lod = actualResolution - targetResolution;

#if _USE_POINT_FILTER_ON
	float4 baseColor = _BaseColor * SAMPLE_TEXTURE2D_LOD(_BaseMap, sampler_PointRepeat, i.uv, lod);
#else
	float4 baseColor = _BaseColor * SAMPLE_TEXTURE2D_LOD(_BaseMap, sampler_LinearRepeat, i.uv, lod);
#endif

	MetaInput metaInput;
	metaInput.Albedo = baseColor;
	metaInput.Emission = 1;

#ifdef EDITOR_VISUALIZATION
	metaInput.VizUV = i.vizUV;
	metaInput.LightCoord = i.lightCoord;
#endif

	return UnityMetaFragment(metaInput);
}

#endif // RETRO_META_PASS_INCLUDED

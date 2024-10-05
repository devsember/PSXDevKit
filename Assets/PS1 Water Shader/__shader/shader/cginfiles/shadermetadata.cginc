#ifndef _PS1_VERTEX_LIT_SHADER_
#define _PS1_VERTEX_LIT_SHADER_

sampler2D _MainTex;
float4 _MainTex_ST; 
float4 _Color;
sampler2D _SpecGlossMap;
float4 _SpecColor;
float _Glossiness;
float4 _EmissionColor;
sampler2D _EmissionMap;
float _VertJitter;
float _AffineMapIntensity; 
float _DrawDist;


struct v2f
{
	float4 vertex : SV_POSITION;
	float2 uv : TEXCOORD0;
	float3 uv_affine : TEXCOORD2;
	fixed3 diffuse : COLOR;
	fixed3 specular : TEXCOORD1;
	float drawDistClip : TEXCOORD3;
    UNITY_FOG_COORDS(4)
};


float4 ScreenSnap(float4 vertex)
{
	float geoRes = _VertJitter * 125.0f + 1.0f;	
	float2 pixelPos = round((vertex.xy / vertex.w) * _ScreenParams.xy / geoRes) * geoRes;
	vertex.xy = pixelPos / _ScreenParams.xy * vertex.w;
	return vertex;
}


v2f vert(appdata_full v)
{
	v2f o;	

	
	#ifdef ENABLE_SCREENSPACE_JITTER
		float4 viewPos = float4(UnityObjectToViewPos(v.vertex.xyz).xyz, 1);
		o.vertex = UnityObjectToClipPos(v.vertex);
		o.vertex = ScreenSnap(o.vertex); 
	#else
		float geoRes = (_VertJitter - 1.0f) * -1000.0f;
		float4 viewPos = float4(UnityObjectToViewPos(v.vertex.xyz).xyz, 1);
		viewPos.xyz = floor(viewPos.xyz * geoRes) / geoRes;
		float4 clipPos = mul(UNITY_MATRIX_P, viewPos);
		o.vertex = clipPos;
	#endif	
		   
	o.uv = v.texcoord;

	
	float wVal = mul(UNITY_MATRIX_P, o.vertex).z;
	o.uv_affine = float3(v.texcoord.xy * wVal, wVal);
	   
	
	o.drawDistClip = 0;
	float4 worldPos = mul(unity_ObjectToWorld, v.vertex);
	if (distance(worldPos, _WorldSpaceCameraPos) > _DrawDist && _DrawDist != 0)
		o.drawDistClip = 1;

	
	o.diffuse = UNITY_LIGHTMODEL_AMBIENT.xyz;
	o.specular = 0;
	fixed3 viewDirObj = normalize(ObjSpaceViewDir(v.vertex));
	for (int i = 0; i < 4; i++)
	{
		half3 toLight = unity_LightPosition[i].xyz - viewPos.xyz * unity_LightPosition[i].w;
		half lengthSq = dot(toLight, toLight);
		half atten = 1.0 / (1.0 + lengthSq * unity_LightAtten[i].z);
		fixed3 lightDirObj = mul((float3x3)UNITY_MATRIX_T_MV, toLight);
		lightDirObj = normalize(lightDirObj);

		fixed diffuse = max(0, dot(v.normal, lightDirObj));
		o.diffuse += unity_LightColor[i].rgb * (diffuse * atten);

		fixed3 h = normalize(viewDirObj + lightDirObj);
		fixed nh = max(0, dot(v.normal, h));
		fixed specular = pow(nh, _Glossiness * 128.0) * 0.5;
		o.specular += specular * unity_LightColor[i].rgb * atten;
	}

	float4 emissionParameter = float4(0, 0, 0, 0);
	#ifdef EMISSION_ENABLED
		emissionParameter = _EmissionColor;
		#ifdef USING_EMISSION_MAP
			emissionParameter *= tex2Dlod(_EmissionMap, float4(v.texcoord.xy, 0, 0));
		#endif
	#endif
	o.diffuse = (o.diffuse * _Color + emissionParameter.rgb) * 2;
	   
	float4 specularParameter = _SpecColor;
	#ifdef USING_SPECULAR_MAP
		specularParameter = tex2Dlod(_SpecGlossMap, float4(v.texcoord.xy, 0, 0));
	#endif
	o.specular *= specularParameter * 2;	

	UNITY_TRANSFER_FOG(o, o.vertex);

	return o;
}


fixed4 frag(v2f i) : COLOR
{	
	
	float2 correctUV = TRANSFORM_TEX(i.uv, _MainTex);
	float2 affineUV = TRANSFORM_TEX((i.uv_affine / i.uv_affine.z).xy, _MainTex);
	float2 finalUV = lerp(correctUV, affineUV, _AffineMapIntensity);

	fixed4 col = tex2D(_MainTex, finalUV);
	col.rgb = (col.rgb * i.diffuse + i.specular);
	col.a = col.a * _Color.a;
	
	UNITY_APPLY_FOG(i.fogCoord, col);

	
	if (i.drawDistClip != 0)
		clip(-1);

	return col;
}

#endif
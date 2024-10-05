using System;
using UnityEngine;
using UnityEditor;

internal class PSXShaderGUI : ShaderGUI
{
    private MaterialProperty baseColorProp, baseTexProp, resolutionLimitProp, snapsPerUnitProp;
    private MaterialProperty colorBitDepthProp, colorBitDepthOffsetProp;
    private MaterialProperty ambientLightProp, lightIntensityProp, ambientToggleProp, useScreenSpaceShadowsProp, screenSpaceShadowIntensityProp,  useAffineTexturesProp, usePointFilteringProp;
    private MaterialProperty vertexJitterProp, zBiasProp, alphaClipProp, alphaClipThresholdProp, cullProp;
    private MaterialProperty useFogProp, fogColorProp, fogDepthMinProp, fogDepthMaxProp;   
    
    private const string baseColorName = "_BaseColor", baseTexName = "_BaseMap", resolutionLimitName = "_ResolutionLimit";
    private const string snapsPerUnitName = "_SnapsPerUnit";
    private const string colorBitDepthName = "_ColorBitDepth", colorBitDepthOffsetName = "_ColorBitDepthOffset";
    private const string vertexJitterName = "_VertexJitter", zBiasName = "_ZBias";
    private const string ambientLightName = "_AmbientLight", lightIntensityName = "_MaxLightIntensity";
    private const string ambientToggleName = "_USE_AMBIENT_OVERRIDE", useAffineTexturesName = "_USE_AFFINE_TEXTURES";
    private const string useScreenSpaceShadowsName = "_USE_SCREEN_SPACE_SHADOWS";
    private const string screenSpaceShadowIntensityName = "_ScreenSpaceShadowIntensity";
    private const string usePointFilteringName = "_USE_POINT_FILTER";
    private const string alphaClipName = "_AlphaClip", alphaClipThresholdName = "_Cutoff", cullName = "_Cull";
    private const string cullLabel = "Render Face", alphaClipLabel = "Alpha Clip", alphaClipThresholdLabel = "Threshold";
    private const string useFogName = "_USE_FOG";
    private const string fogColorName = "_FogColor";
    private const string fogDepthMinName = "_FogDepthMin";
    private const string fogDepthMaxName = "_FogDepthMax";
    
    private bool showFogOptions = false;
    
    private static readonly string[] surfaceTypeNames = Enum.GetNames(typeof(SurfaceType));
    private static readonly string[] renderFaceNames = Enum.GetNames(typeof(RenderFace));

    private enum SurfaceType { Opaque, Transparent }
    private enum RenderFace { Front = 2, Back = 1, Both = 0 }

    private SurfaceType surfaceType = SurfaceType.Opaque;
    private RenderFace renderFace = RenderFace.Front;
    private bool showSurfaceOptions = false;

    private void FindProperties(MaterialProperty[] props)
    {
        baseColorProp = FindProperty(baseColorName, props);
        baseTexProp = FindProperty(baseTexName, props);
        resolutionLimitProp = FindProperty(resolutionLimitName, props);
        snapsPerUnitProp = FindProperty(snapsPerUnitName, props, false);
        colorBitDepthProp = FindProperty(colorBitDepthName, props);
        colorBitDepthOffsetProp = FindProperty(colorBitDepthOffsetName, props);
        ambientLightProp = FindProperty(ambientLightName, props, false);
        lightIntensityProp = FindProperty(lightIntensityName, props, false);
        ambientToggleProp = FindProperty(ambientToggleName, props, false);
        useScreenSpaceShadowsProp = FindProperty(useScreenSpaceShadowsName, props, false);
        screenSpaceShadowIntensityProp = FindProperty(screenSpaceShadowIntensityName, props, false);
        vertexJitterProp = FindProperty(vertexJitterName, props, false);
        zBiasProp = FindProperty(zBiasName, props, false);
        useAffineTexturesProp = FindProperty(useAffineTexturesName, props, false);
        usePointFilteringProp = FindProperty(usePointFilteringName, props, false);
        cullProp = FindProperty(cullName, props);
        alphaClipProp = FindProperty(alphaClipName, props);
        alphaClipThresholdProp = FindProperty(alphaClipThresholdName, props);
        useFogProp = FindProperty(useFogName, props, false);
        fogColorProp = FindProperty(fogColorName, props, false);
        fogDepthMinProp = FindProperty(fogDepthMinName, props, false);
        fogDepthMaxProp = FindProperty(fogDepthMaxName, props, false);
    }

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        if (materialEditor == null) throw new ArgumentNullException("No MaterialEditor found (RetroLitShaderGUI).");

        Material material = materialEditor.target as Material;
        FindProperties(properties);

        surfaceType = (SurfaceType)material.GetFloat("_Surface");
        renderFace = (RenderFace)material.GetFloat("_Cull");

        showSurfaceOptions = EditorGUILayout.Foldout(showSurfaceOptions, "Surface Options", EditorStyles.foldoutHeader);
        if (showSurfaceOptions)
        {
            EditorGUI.indentLevel++;
            surfaceType = (SurfaceType)EditorGUILayout.EnumPopup("Surface Type", surfaceType);
            renderFace = (RenderFace)EditorGUILayout.EnumPopup(cullLabel, renderFace);
            material.SetFloat("_Cull", (float)renderFace);

            materialEditor.ShaderProperty(alphaClipProp, alphaClipLabel);
            bool alphaClip = material.GetFloat(alphaClipName) >= 0.5f;
            if (alphaClip) material.EnableKeyword("_ALPHATEST_ON");
            else material.DisableKeyword("_ALPHATEST_ON");

            if (surfaceType == SurfaceType.Opaque)
            {
                material.SetOverrideTag("RenderType", "Opaque");
                material.SetFloat("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
                material.SetFloat("_DstBlend", (int)UnityEngine.Rendering.BlendMode.Zero);
                material.SetFloat("_ZWrite", 1);
                material.renderQueue = alphaClip ? (int)UnityEngine.Rendering.RenderQueue.AlphaTest : (int)UnityEngine.Rendering.RenderQueue.Geometry;
            }
            else
            {
                material.SetOverrideTag("RenderType", "Transparent");
                material.SetFloat("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
                material.SetFloat("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                material.SetFloat("_ZWrite", 0);
                material.renderQueue = (int)UnityEngine.Rendering.RenderQueue.Transparent;
            }

            if (alphaClip) materialEditor.ShaderProperty(alphaClipThresholdProp, alphaClipThresholdLabel);
            EditorGUI.indentLevel--;
        }

        EditorGUILayout.LabelField("Material Properties", EditorStyles.boldLabel);
        materialEditor.ShaderProperty(baseColorProp, "Base Color");
        materialEditor.ShaderProperty(baseTexProp, "Base Texture");
        materialEditor.ShaderProperty(resolutionLimitProp, "Resolution Limit");
        if (snapsPerUnitProp != null) materialEditor.ShaderProperty(snapsPerUnitProp, "Snaps Per Unit");
        if (vertexJitterProp != null) materialEditor.ShaderProperty(vertexJitterProp, "Vertex Jitter");
        if (zBiasProp != null) materialEditor.ShaderProperty(zBiasProp, "Z Bias");
        
        EditorGUILayout.Space();
        EditorGUILayout.LabelField("Color Settings", EditorStyles.boldLabel);
        materialEditor.ShaderProperty(colorBitDepthProp, "Color Depth");
        materialEditor.ShaderProperty(colorBitDepthOffsetProp, "Color Depth Offset");
        
        EditorGUILayout.Space();
        EditorGUILayout.LabelField("Light Settings", EditorStyles.boldLabel);
        if (ambientLightProp != null)
        {
            materialEditor.ShaderProperty(ambientToggleProp, "Ambient Light Override");
            if (material.GetFloat(ambientToggleName) >= 0.5f)
            {
                material.EnableKeyword("_USE_AMBIENT_OVERRIDE");


                //materialEditor.ShaderProperty(ambientOverrideColorProp, "Ambient Override Color");
                materialEditor.ShaderProperty(ambientLightProp, "Ambient Light Strength");

            }
            else
            {
                material.DisableKeyword("_USE_AMBIENT_OVERRIDE");
            }
        }

        if (lightIntensityProp != null) materialEditor.ShaderProperty(lightIntensityProp, "Light Intensity");
        
       
        if (useScreenSpaceShadowsProp != null && screenSpaceShadowIntensityProp != null)
        {
            EditorGUILayout.Space();
            EditorGUILayout.LabelField("Screen Space Shadows", EditorStyles.boldLabel);
            materialEditor.ShaderProperty(useScreenSpaceShadowsProp, "Use Screen Space Shadows");
            if (useScreenSpaceShadowsProp.floatValue >= 0.5f)
            {
                EditorGUI.indentLevel++;
                materialEditor.ShaderProperty(screenSpaceShadowIntensityProp, "Shadow Intensity");
                EditorGUI.indentLevel--;
            }
        }
        else
        {
            //EditorGUILayout.HelpBox("Screen space shadow properties not found in shader.", MessageType.Warning);
        }
        
        EditorGUILayout.Space();
        EditorGUILayout.LabelField("Fog Settings", EditorStyles.boldLabel);

        materialEditor.ShaderProperty(FindProperty("_USE_FOG", properties), "Enable Fog");
        if (material.IsKeywordEnabled("_USE_FOG_ON"))
        {

            materialEditor.ColorProperty(FindProperty("_FogColor", properties), "Fog Color");
            materialEditor.FloatProperty(FindProperty("_FogDepthMin", properties), "Fog Depth Min");
            materialEditor.FloatProperty(FindProperty("_FogDepthMax", properties), "Fog Depth Max");

        }

        materialEditor.ShaderProperty(useAffineTexturesProp, "Affine Texture Mapping");
        materialEditor.ShaderProperty(usePointFilteringProp, "Point Filtering");
    }
}

using UnityEngine;

public class TextureWaveDistortion : MonoBehaviour
{
    public float waveSpeed = 1.0f;
    public float waveIntensity = 0.1f;
    public float patternIntensity = 0.5f;
    public float overallDistortion = 0.2f;
    public float textureDistortionSpeed = 2.0f;
    public float textureDistortionAmount = 0.1f;

    private MeshRenderer meshRenderer;
    private Vector2 originalTiling;

    void Start()
    {
        // Make sure the GameObject has a MeshRenderer component
        meshRenderer = GetComponent<MeshRenderer>();
        if (meshRenderer == null || meshRenderer.material == null)
        {
            Debug.LogError("MeshRenderer or Material not found on the GameObject.");
            return;
        }

        // Store the original texture tiling
        originalTiling = meshRenderer.material.mainTextureScale;
    }

    void Update()
    {
        DistortTexture();
    }

    void DistortTexture()
    {
        // Get the current material's main texture offset
        Vector2 textureOffset = meshRenderer.material.mainTextureOffset;

        // Calculate the wave offset based on time and speed
        float waveOffset = Mathf.Sin(Time.time * waveSpeed) * waveIntensity;

        // Apply the overall distortion intensity
        waveOffset *= overallDistortion;

        // Apply the wave offset to the material's main texture offset
        meshRenderer.material.mainTextureOffset = new Vector2(waveOffset, textureOffset.y);

        // Calculate the texture distortion offset based on time and speed
        float textureDistortionOffset = Mathf.Sin(Time.time * textureDistortionSpeed) * textureDistortionAmount;

        // Apply the texture distortion offset to the material's texture scale
        Vector2 newTiling = originalTiling + new Vector2(textureDistortionOffset, 0);
        meshRenderer.material.mainTextureScale = newTiling;

        // Modify the intensity of the pattern being added
        Color patternColor = new Color(1f, 1f, 1f, patternIntensity);

        // Apply the pattern intensity to the material's color
        meshRenderer.material.SetColor("_PatternColor", patternColor);
    }
}

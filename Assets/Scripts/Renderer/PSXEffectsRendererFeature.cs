using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

public class PSXEffectsRendererFeature : ScriptableRendererFeature
{
    [System.Serializable]
    public class PSXEffectsSettings
    {
        public RenderPassEvent renderPassEvent = RenderPassEvent.BeforeRenderingPostProcessing;
    }

    public PSXEffectsSettings settings = new PSXEffectsSettings();

    private PSXEffectsRenderPass m_RenderPass;
    private Shader psxEffectsShader;


    public override void Create()
    {
        psxEffectsShader = Shader.Find("Hidden/PSX/PSXEffects");

        m_RenderPass = new PSXEffectsRenderPass(settings.renderPassEvent, psxEffectsShader);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        renderer.EnqueuePass(m_RenderPass);
    }

    protected override void Dispose(bool disposing)
    {
        m_RenderPass.Dispose();

    }

    private class PSXEffectsRenderPass : ScriptableRenderPass
    {
        private Material m_Material;
        private RenderTargetIdentifier source;
        private RenderTextureDescriptor m_Descriptor;
        private const string k_RenderTag = "Render PSX Effects";
        private const string k_ShaderPath = "Hidden/PSX/PSXEffects";
        private PSXEffectsVolume m_VolumeComponent;
        private RenderTargetHandle m_TemporaryRT;

        public PSXEffectsRenderPass(RenderPassEvent evt, Shader shader)
        {
            renderPassEvent = evt;
            m_Material = CoreUtils.CreateEngineMaterial(shader);
            m_TemporaryRT.Init("_TemporaryPSXEffectsTexture");
        }

        public override void Configure(CommandBuffer cmd, RenderTextureDescriptor cameraTextureDescriptor)
        {
            m_Descriptor = cameraTextureDescriptor;
        }

        public override void Execute(ScriptableRenderContext context, ref RenderingData renderingData)
        {
            if (!GetVolumeComponent(ref renderingData) || m_Material == null)
                return;

            CommandBuffer cmd = CommandBufferPool.Get(k_RenderTag);
            source = renderingData.cameraData.renderer.cameraColorTarget;

            RenderTextureDescriptor outputDescriptor = m_Descriptor;
            outputDescriptor.width = m_VolumeComponent.resolutionWidth.value;
            outputDescriptor.height = m_VolumeComponent.resolutionHeight.value;

            int rasterizationWidth, rasterizationHeight;
            Vector4 cameraAspectModeUVScaleBias;
            CalculateRasterizationResolution(renderingData.cameraData.camera, outputDescriptor.width, outputDescriptor.height, out rasterizationWidth, out rasterizationHeight, out cameraAspectModeUVScaleBias);

            SetMaterialProperties(cameraAspectModeUVScaleBias);

            cmd.GetTemporaryRT(m_TemporaryRT.id, outputDescriptor);

            Blit(cmd, source, m_TemporaryRT.Identifier(), m_Material);
            Blit(cmd, m_TemporaryRT.Identifier(), source);

            context.ExecuteCommandBuffer(cmd);
            CommandBufferPool.Release(cmd);
        }

        public override void FrameCleanup(CommandBuffer cmd)
        {
            cmd.ReleaseTemporaryRT(m_TemporaryRT.id);
        }

        private bool GetVolumeComponent(ref RenderingData renderingData)
        {
            var stack = VolumeManager.instance.stack;
            m_VolumeComponent = stack.GetComponent<PSXEffectsVolume>();
            return m_VolumeComponent != null && m_VolumeComponent.active;
        }
        

        private void SetMaterialProperties(Vector4 cameraAspectModeUVScaleBias)
        {
            m_Material.SetVector("_CameraAspectModeUVScaleBias", cameraAspectModeUVScaleBias);
            m_Material.SetFloat("_EnableDithering", m_VolumeComponent.enableDithering.value ? 1f : 0f);
            m_Material.SetFloat("_DitheringIntensity", m_VolumeComponent.ditheringIntensity.value);
            m_Material.SetFloat("_DownscaleFactor", m_VolumeComponent.downscaleFactor.value);
            
        }

        private void CalculateRasterizationResolution(Camera camera, int targetWidth, int targetHeight, out int rasterizationWidth, out int rasterizationHeight, out Vector4 cameraAspectModeUVScaleBias)
        {
            int screenWidth = camera.pixelWidth;
            int screenHeight = camera.pixelHeight;

            rasterizationWidth = Mathf.Min(screenWidth, targetWidth);
            rasterizationHeight = Mathf.Min(screenHeight, targetHeight);
            cameraAspectModeUVScaleBias = new Vector4(1.0f, 1.0f, 0.0f, 0.0f);

            if (m_VolumeComponent.aspectMode.value != PSXEffectsVolume.CameraAspectMode.Native)
            {
                if (camera.cameraType != CameraType.Game ||
                    m_VolumeComponent.aspectMode.value == PSXEffectsVolume.CameraAspectMode.FreeStretch ||
                    m_VolumeComponent.aspectMode.value == PSXEffectsVolume.CameraAspectMode.FreeFitPixelPerfect ||
                    m_VolumeComponent.aspectMode.value == PSXEffectsVolume.CameraAspectMode.FreeCropPixelPerfect ||
                    m_VolumeComponent.aspectMode.value == PSXEffectsVolume.CameraAspectMode.FreeBleedPixelPerfect)
                {
                    if (screenWidth >= screenHeight)
                    {
                        rasterizationWidth = Mathf.FloorToInt((float)rasterizationHeight * screenWidth / screenHeight + 0.5f);
                    }
                    else
                    {
                        rasterizationHeight = Mathf.FloorToInt((float)rasterizationWidth * screenHeight / screenWidth + 0.5f);
                    }
                }

                float ratioX = (float)rasterizationWidth / screenWidth;
                float ratioY = (float)rasterizationHeight / screenHeight;

                switch (m_VolumeComponent.aspectMode.value)
                {
                    case PSXEffectsVolume.CameraAspectMode.FreeBleedPixelPerfect:
                        rasterizationWidth = screenWidth / Mathf.CeilToInt((float)screenWidth / rasterizationWidth);
                        rasterizationHeight = screenHeight / Mathf.CeilToInt((float)screenHeight / rasterizationHeight);
                        break;

                    case PSXEffectsVolume.CameraAspectMode.FreeFitPixelPerfect:
                    case PSXEffectsVolume.CameraAspectMode.LockedFitPixelPerfect:
                        float ratioMax = Mathf.Max(ratioX, ratioY);
                        float scaleX = 1.0f / (ratioX * Mathf.Floor(1.0f / ratioMax));
                        float scaleY = 1.0f / (ratioY * Mathf.Floor(1.0f / ratioMax));
                        cameraAspectModeUVScaleBias = new Vector4(scaleX, scaleY, 0.5f - (0.5f * scaleX), 0.5f - (0.5f * scaleY));
                        break;

                    case PSXEffectsVolume.CameraAspectMode.FreeCropPixelPerfect:
                        float ratioMin = Mathf.Min(ratioX, ratioY);
                        scaleX = 1.0f / (ratioX * Mathf.Ceil(1.0f / ratioMin));
                        scaleY = 1.0f / (ratioY * Mathf.Ceil(1.0f / ratioMin));
                        cameraAspectModeUVScaleBias = new Vector4(scaleX, scaleY, 0.5f - (0.5f * scaleX), 0.5f - (0.5f * scaleY));
                        break;

                    case PSXEffectsVolume.CameraAspectMode.LockedFit:
                        ratioMax = Mathf.Max(ratioX, ratioY);
                        scaleX = 1.0f / (ratioX / ratioMax);
                        scaleY = 1.0f / (ratioY / ratioMax);
                        cameraAspectModeUVScaleBias = new Vector4(scaleX, scaleY, 0.5f - (0.5f * scaleX), 0.5f - (0.5f * scaleY));
                        break;
                }

                camera.aspect = (float)rasterizationWidth / rasterizationHeight;
            }
        }

        public void Dispose()
        {
            CoreUtils.Destroy(m_Material);
        }
    }

}
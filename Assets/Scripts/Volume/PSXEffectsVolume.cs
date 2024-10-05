using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;

[System.Serializable, VolumeComponentMenu("PSX/PSX Effects")]
public class PSXEffectsVolume : VolumeComponent, IPostProcessComponent
{
    public enum CameraAspectMode
    {
        FreeStretch = 0,
        FreeFitPixelPerfect,
        FreeCropPixelPerfect,
        FreeBleedPixelPerfect,
        LockedFitPixelPerfect,
        LockedFit,
        Native
    }

    [Tooltip("Target width for the PSX-style resolution")]
    public ClampedIntParameter resolutionWidth = new ClampedIntParameter(640, 1, 1920);

    [Tooltip("Target height for the PSX-style resolution")]
    public ClampedIntParameter resolutionHeight = new ClampedIntParameter(360, 1, 1080);

    [Tooltip("Aspect ratio mode for the PSX effect")]
    public EnumParameter<CameraAspectMode> aspectMode = new EnumParameter<CameraAspectMode>(CameraAspectMode.FreeBleedPixelPerfect);
    
    [Tooltip("Enable PSX-style dithering")]
    public BoolParameter enableDithering = new BoolParameter(true);

    [Tooltip("Dithering intensity")]
    public ClampedFloatParameter ditheringIntensity = new ClampedFloatParameter(1f, 0f, 1f);

    [Tooltip("Downscale factor for pixelation effect")]
    public ClampedFloatParameter downscaleFactor = new ClampedFloatParameter(1f, 1f, 10f);

    [Tooltip("Enable frame rate limiting")]
    public BoolParameter enableFrameRateLimiting = new BoolParameter(false);

    [Tooltip("Target frame rate for PSX effect")]
    public ClampedIntParameter targetFrameRate = new ClampedIntParameter(30, -1, 60);

    [Header("Fog Settings")]
    public BoolParameter enableFog = new BoolParameter(false);
    public ColorParameter fogColor = new ColorParameter(Color.gray);
    public FloatParameter fogDepthMin = new FloatParameter(0f);
    public FloatParameter fogDepthMax = new FloatParameter(20f);

    public bool IsActive() => true;

    public bool IsTileCompatible() => false;
    
    public void ApplyFPSLimit()
    {
        if (enableFrameRateLimiting.value)
        {
            Application.targetFrameRate = targetFrameRate.value;
        }
        else
        {
            Application.targetFrameRate = -1; // Unlimited frame rate
        }
    }
}

[System.Serializable]
public sealed class EnumParameter<T> : VolumeParameter<T> where T : System.Enum
{
    public EnumParameter(T value, bool overrideState = false)
        : base(value, overrideState) { }
}
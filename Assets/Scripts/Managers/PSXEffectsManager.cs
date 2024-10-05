using UnityEngine;
using UnityEngine.Rendering;

public class PSXEffectsManager : MonoBehaviour
{
    public Volume postProcessingVolume;
    private PSXEffectsVolume psxEffects;

    void Start()
    {
        // Get the PSXEffectsVolume component from the Volume
        postProcessingVolume.profile.TryGet(out psxEffects);
    }

    void Update()
    {
        // Apply the FPS limit every frame (or you could do this only when settings change)
        if (psxEffects != null)
        {
            psxEffects.ApplyFPSLimit();
        }
    }

    // You can also create methods to modify the FPS settings
    public void SetEnableFPSLimit(bool enable)
    {
        if (psxEffects != null)
        {
            psxEffects.enableFrameRateLimiting.Override(enable);
            psxEffects.ApplyFPSLimit();
        }
    }

    public void SetTargetFrameRate(int fps)
    {
        if (psxEffects != null)
        {
            psxEffects.targetFrameRate.Override(fps);
            psxEffects.ApplyFPSLimit();
        }
    }
}
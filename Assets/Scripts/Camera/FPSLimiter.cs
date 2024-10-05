using UnityEngine;

[ExecuteAlways]
public class FPSLimiter : MonoBehaviour
{
    [SerializeField] private int targetFrameRate = 60;
    [SerializeField] private bool vSyncEnabled = false;

    private void Start()
    {
        // Set the target frame rate
        Application.targetFrameRate = targetFrameRate;

        // Enable or disable VSync
        QualitySettings.vSyncCount = vSyncEnabled ? 1 : 0;
    }

    private void OnValidate()
    {
        // Update settings when changed in the inspector
        if (Application.isPlaying)
        {
            Application.targetFrameRate = targetFrameRate;
            QualitySettings.vSyncCount = vSyncEnabled ? 1 : 0;
        }
    }
}
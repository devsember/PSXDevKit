using UnityEngine;
using Cinemachine;
using System.Collections.Generic;

public class FixedCameraController : MonoBehaviour
{
    [System.Serializable]
    public class CameraSetup
    {
        public CinemachineVirtualCamera virtualCamera;
        public Collider triggerZone;
    }

    public List<CameraSetup> cameraSetups = new List<CameraSetup>();

    private void Start()
    {
        InitializeCameras();
    }

    private void InitializeCameras()
    {
        foreach (CameraSetup setup in cameraSetups)
        {
            if (setup.virtualCamera != null && setup.triggerZone != null)
            {
                setup.virtualCamera.Priority = 1;
                setup.triggerZone.isTrigger = true;
                CameraTrigger trigger = setup.triggerZone.gameObject.GetComponent<CameraTrigger>();
                if (trigger == null)
                {
                    trigger = setup.triggerZone.gameObject.AddComponent<CameraTrigger>();
                }
                trigger.Initialize(this, setup.virtualCamera);
            }
            else
            {
                Debug.LogWarning("Incomplete camera setup found. Make sure both virtualCamera and triggerZone are assigned.");
            }
        }
    }

    public void SwitchCamera(CinemachineVirtualCamera newCamera)
    {
        foreach (CameraSetup setup in cameraSetups)
        {
            if (setup.virtualCamera == newCamera)
            {
                setup.virtualCamera.Priority = 10;
            }
            else
            {
                setup.virtualCamera.Priority = 1;
            }
        }
    }
}
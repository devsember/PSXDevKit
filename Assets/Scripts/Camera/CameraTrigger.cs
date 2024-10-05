using UnityEngine;
using Cinemachine;
using System.Collections.Generic;
public class CameraTrigger : MonoBehaviour
{
    private FixedCameraController controller;
    private CinemachineVirtualCamera associatedCamera;

    public void Initialize(FixedCameraController controller, CinemachineVirtualCamera camera)
    {
        this.controller = controller;
        this.associatedCamera = camera;
    }

    private void OnTriggerEnter(Collider other)
    {
        if (other.CompareTag("Player"))
        {
            controller.SwitchCamera(associatedCamera);
        }
    }
}
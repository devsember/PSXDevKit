using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using Cinemachine;

public class RotateCamera : MonoBehaviour
{
    public CinemachineVirtualCamera virtualCamera;
    public float rotationSpeed = 20f; // The speed at which the camera rotates

    private Transform virtualCameraTransform; // Reference to the virtual camera's Transform component
    private Vector3 lastMousePosition; // The last recorded mouse position

    // Start is called before the first frame update
    void Start()
    {
        
        if (virtualCamera != null)
        {
            // Get the Transform component of the virtual camera
            virtualCameraTransform = virtualCamera.transform;
        }
    }

    // Update is called once per frame
    void Update()
    {
        if (virtualCameraTransform != null)
        {
            // Check for left mouse button press
            if (Input.GetMouseButtonDown(1))
            {
                // Record the initial mouse position
                lastMousePosition = Input.mousePosition;
            }

            // Check for left mouse button hold
            if (Input.GetMouseButton(1))
            {
                // Calculate mouse movement since last frame
                float deltaX = Input.mousePosition.x - lastMousePosition.x;

                // Calculate the new Y-axis rotation
                float newYRotation = virtualCameraTransform.eulerAngles.y + deltaX * rotationSpeed * Time.deltaTime;

                // Rotate only the Y-axis of the virtual camera
                virtualCameraTransform.rotation = Quaternion.Euler(virtualCameraTransform.eulerAngles.x, newYRotation, virtualCameraTransform.eulerAngles.z);

                // Record the current mouse position for the next frame
                lastMousePosition = Input.mousePosition;
            }
        }
    }
}

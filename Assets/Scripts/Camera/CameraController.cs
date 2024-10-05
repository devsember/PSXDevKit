using UnityEngine;
using Cinemachine;

public class CameraController : MonoBehaviour
{
    [SerializeField] private CinemachineVirtualCamera virtualCamera;
    [SerializeField] private Transform player;
    [SerializeField] private float transitionSpeed = 5f;
    [SerializeField] private float minDistance = 2f;
    [SerializeField] private float maxDistance = 5f;
    [SerializeField] private float minFieldOfView = 60f;
    [SerializeField] private float maxFieldOfView = 75f;
    [SerializeField] private LayerMask obstacleLayer;
    [SerializeField] private float maxYRotationOffset = 30f;
    [SerializeField] private float xRotation = 8f;
    [SerializeField] private float smoothTime = 0.3f;
    [SerializeField] private float fullRotationThreshold = 0.8f; // Threshold to reach full rotation
    [SerializeField] private float tightSpaceBuffer = 0.5f; // Buffer distance for tight spaces

    private CinemachineFramingTransposer framingTransposer;
    private float currentYRotationOffset = 0f;
    private float yRotationVelocity;

    private void Start()
    {
        Debug.Assert(virtualCamera != null, "Camera Controller: Virtual Camera reference is missing.");
        Debug.Assert(player != null, "Camera Controller: Player reference is missing.");

        framingTransposer = virtualCamera.GetCinemachineComponent<CinemachineFramingTransposer>();
        Debug.Assert(framingTransposer != null, "Camera Controller: Virtual Camera must have a Framing Transposer component.");
    }

    private void LateUpdate()
    {
        AdjustCameraBasedOnRotation();
        HandleTightSpaces();
    }

    private void AdjustCameraBasedOnRotation()
    {
        if (player == null || virtualCamera == null) return;

        Vector3 playerToCameraDirection = (virtualCamera.transform.position - player.position).normalized;
        float dotProduct = Vector3.Dot(player.forward, playerToCameraDirection);
        float facingRatio = CalculateFacingRatio(dotProduct);

        float targetDistance = Mathf.Lerp(minDistance, maxDistance, facingRatio);
        float targetFOV = Mathf.Lerp(minFieldOfView, maxFieldOfView, facingRatio);

        if (framingTransposer != null)
        {
            framingTransposer.m_CameraDistance = Mathf.Lerp(framingTransposer.m_CameraDistance, targetDistance, Time.deltaTime * transitionSpeed);
        }

        if (Mathf.Abs(virtualCamera.m_Lens.FieldOfView - targetFOV) > 0.01f)
        {
            virtualCamera.m_Lens.FieldOfView = Mathf.Lerp(virtualCamera.m_Lens.FieldOfView, targetFOV, Time.deltaTime * transitionSpeed);
        }

        Vector3 playerRight = player.right;
        Vector3 cameraForward = virtualCamera.transform.forward;
        playerRight.y = 0f;
        cameraForward.y = 0f;
        playerRight.Normalize();
        cameraForward.Normalize();

        float rotationDot = Vector3.Dot(playerRight, cameraForward);
        float angle = Mathf.Asin(Mathf.Clamp(rotationDot, -1f, 1f)) * Mathf.Rad2Deg;

        // Calculate rotation strength based on how close we are to 90 or -90 degrees
        float rotationStrength = Mathf.Abs(angle) / 65f;
        rotationStrength = Mathf.Clamp01((rotationStrength - fullRotationThreshold) / (1f - fullRotationThreshold));

        float targetYRotationOffset = -angle * (maxYRotationOffset / 65f) * rotationStrength;

        currentYRotationOffset = Mathf.SmoothDamp(currentYRotationOffset, targetYRotationOffset, ref yRotationVelocity, smoothTime, Mathf.Infinity, Time.deltaTime);

        if (!float.IsNaN(currentYRotationOffset) && !float.IsInfinity(currentYRotationOffset))
        {
            virtualCamera.transform.localRotation = Quaternion.Euler(xRotation, currentYRotationOffset, 0f);
        }
    }

    private void HandleTightSpaces()
    {
        RaycastHit hit;
        Vector3 directionToCamera = (virtualCamera.transform.position - player.position).normalized;

        if (Physics.Raycast(player.position, directionToCamera, out hit, maxDistance, obstacleLayer))
        {
            float newDistance = hit.distance - tightSpaceBuffer; // Keep a small buffer
            framingTransposer.m_CameraDistance = Mathf.Min(framingTransposer.m_CameraDistance, newDistance);
        }
    }

    private float CalculateFacingRatio(float dotProduct)
    {
        return Mathf.Clamp01((dotProduct + 1) / 2);
    }
}
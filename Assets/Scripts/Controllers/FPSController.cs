using UnityEngine;

public class FPSController : MonoBehaviour
{
    [Header("Movement")]
    public float walkSpeed = 3f;
    public float runSpeed = 6f;
    public float smoothMoveTime = 0.1f;
    public float jumpForce = 5f;
    public float gravity = -9.81f;

    [Header("Look")]
    public float mouseSensitivity = 2f;
    public float smoothLookTime = 0.1f;
    public float maxLookAngle = 90f;

    [Header("Head Bob")]
    public float bobFrequency = 2f;
    public float bobHorizontalAmplitude = 0.1f;
    public float bobVerticalAmplitude = 0.05f;

    [Header("Interaction")]
    public float interactionDistance = 2f;
    public LayerMask interactionLayer;

    private CharacterController controller;
    private Camera playerCamera;
    private Vector3 smoothMoveVelocity;
    private Vector3 moveAmount;
    private Vector3 smoothLookVelocity;
    private float verticalLookRotation;
    private bool isGrounded;
    private float yVelocity;
    private float originalCameraY;
    private float bobTimer;

    private InputManager inputManager;

    void Start()
    {
        controller = GetComponent<CharacterController>();
        playerCamera = GetComponentInChildren<Camera>();
        originalCameraY = playerCamera.transform.localPosition.y;
        inputManager = InputManager.Instance;
        inputManager.OnInteractPressed += OnInteract;
        Cursor.lockState = CursorLockMode.Locked;
        Cursor.visible = false;
    }

    void OnDestroy()
    {
        if (inputManager != null)
        {
            inputManager.OnInteractPressed -= OnInteract;
        }
    }

    void Update()
    {
        Look();
        Move();
        HeadBob();
        Jump();
    }

    void Look()
    {
        Vector2 lookInput = inputManager.GetLookInput() * mouseSensitivity;

        verticalLookRotation += -lookInput.y;
        verticalLookRotation = Mathf.Clamp(verticalLookRotation, -maxLookAngle, maxLookAngle);

        playerCamera.transform.localRotation = Quaternion.Euler(verticalLookRotation, 0f, 0f);
        transform.Rotate(Vector3.up * lookInput.x);
    }

    void Move()
    {
        Vector2 input = inputManager.GetMoveInput();
        Vector3 inputDir = new Vector3(input.x, 0, input.y).normalized;
        Vector3 worldInputDir = transform.TransformDirection(inputDir);

        float currentSpeed = inputManager.IsRunning() ? runSpeed : walkSpeed;
        Vector3 targetVelocity = worldInputDir * currentSpeed;
        moveAmount = Vector3.SmoothDamp(moveAmount, targetVelocity, ref smoothMoveVelocity, smoothMoveTime);

        yVelocity += gravity * Time.deltaTime;
        moveAmount.y = yVelocity;

        CollisionFlags flags = controller.Move(moveAmount * Time.deltaTime);
        isGrounded = flags == CollisionFlags.Below;

        if (isGrounded)
        {
            yVelocity = -0.5f;
        }
    }

    void HeadBob()
    {
        if (moveAmount.magnitude > 0.1f)
        {
            bobTimer += Time.deltaTime * bobFrequency;
            float bobOffsetX = Mathf.Sin(bobTimer) * bobHorizontalAmplitude;
            float bobOffsetY = Mathf.Sin(bobTimer * 2) * bobVerticalAmplitude;
            playerCamera.transform.localPosition = new Vector3(bobOffsetX, originalCameraY + bobOffsetY, playerCamera.transform.localPosition.z);
        }
        else
        {
            bobTimer = 0;
            playerCamera.transform.localPosition = new Vector3(0, Mathf.Lerp(playerCamera.transform.localPosition.y, originalCameraY, Time.deltaTime * 5f), playerCamera.transform.localPosition.z);
        }
    }

    void Jump()
    {
        // Note: You'll need to add a Jump action to your InputManager if you want jumping functionality
        // For now, this method is left empty
    }

    void OnInteract()
    {
        Ray ray = playerCamera.ViewportPointToRay(new Vector3(0.5f, 0.5f, 0));
        if (Physics.Raycast(ray, out RaycastHit hit, interactionDistance, interactionLayer))
        {
            IInteractable interactable = hit.collider.GetComponent<IInteractable>();
            if (interactable != null)
            {
                interactable.Interact();
            }
        }
    }
}


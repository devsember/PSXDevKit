using UnityEngine;
using System.Collections;

public class PlayerController : MonoBehaviour
{
    [Header("Movement")]
    [SerializeField] private float walkSpeed = 2f;
    [SerializeField] private float runSpeed = 4f;
    [SerializeField] private float backwardsSpeedMultiplier = 0.7f;
    [SerializeField] private float turnSpeed = 100f;
    [SerializeField] private float speedThreshold = 0.01f;
    
    [Header("Input Delay")]
    [SerializeField] private float inputDelay = 0.2f;

    [Header("Interaction")]
    [SerializeField] private float interactionDistance = 2f;
    [SerializeField] private LayerMask interactableLayer;

    private CharacterController characterController;
    private PlayerAnimationController animationController;
    private float currentSpeed;
    private Vector3 moveDirection;
    private bool isRunning;
    private bool isWalking;
    private bool isWalkingBackwards;
    private Vector2 delayedInput;
    private bool delayedRunning;
    private bool isRotating;
    private bool isActive = true;
    private Coroutine inputDelayCoroutine;

    private void Start()
    {
        characterController = GetComponent<CharacterController>();
        animationController = GetComponent<PlayerAnimationController>();
        currentSpeed = 0f;
        delayedInput = Vector2.zero;
        delayedRunning = false;
        
        if (InputManager.Instance != null)
        {
            InputManager.Instance.OnInteractPressed += HandleInteraction;
        }
        inputDelayCoroutine = StartCoroutine(InputDelayCoroutine());
    }

    private void OnDestroy()
    {
        if (InputManager.Instance != null)
        {
            InputManager.Instance.OnInteractPressed -= HandleInteraction;
        }
        if (inputDelayCoroutine != null)
        {
            StopCoroutine(inputDelayCoroutine);
        }
    }

    private void FixedUpdate()
    {
        HandleRotation();
        HandleMovement();
    }

    private void HandleRotation()
    {
        float horizontalInput = delayedInput.x;
        isRotating = Mathf.Abs(horizontalInput) > 0.1f;

        // Turn player based on horizontal input (tank control style)
        float rotation = horizontalInput * turnSpeed * Time.deltaTime;
        transform.Rotate(Vector3.up * rotation);
    }

    private void HandleMovement()
    {
        float verticalInput = delayedInput.y;

        // Determine movement state
        isRunning = delayedRunning && verticalInput > 0;
        isWalkingBackwards = verticalInput < 0;
        isWalking = Mathf.Abs(verticalInput) > 0.1f;

        // Determine speed based on input and state
        float maxSpeed = isRunning ? runSpeed : walkSpeed;
        if (isWalkingBackwards)
        {
            maxSpeed *= backwardsSpeedMultiplier;
        }

        currentSpeed = isWalking ? maxSpeed * Mathf.Abs(verticalInput) : 0f;

        // Apply movement (tank control style, always move forward/backward relative to the character's facing direction)
        moveDirection = transform.forward * Mathf.Sign(verticalInput);
        if (Mathf.Abs(currentSpeed) > speedThreshold)
        {
            characterController.Move(moveDirection * currentSpeed * Time.deltaTime);
        }
        else
        {
            currentSpeed = 0f;
            isWalking = false;
            isWalkingBackwards = false;
        }
        
    }
    
    private IEnumerator InputDelayCoroutine()
    {
        while (isActive)
        {
            Vector2 currentInput = InputManager.Instance.GetMoveInput();
            bool currentRunning = InputManager.Instance.IsRunning();

            yield return new WaitForSecondsRealtime(inputDelay);

            delayedInput = currentInput;
            delayedRunning = currentRunning;
        }
    }

    private void HandleInteraction()
    {
        RaycastHit hit;
        if (Physics.Raycast(transform.position, transform.forward, out hit, interactionDistance, interactableLayer))
        {
            Debug.DrawRay(transform.position, transform.forward * interactionDistance, Color.red, 1f);
            Debug.Log("Raycast hit: " + hit.collider.name);
            IInteractable interactable = hit.collider.GetComponent<IInteractable>();
            if (interactable != null)
            {
                interactable.Interact();
                if (animationController != null)
                {
                    animationController.TriggerInteractionAnimation("Interact");
                }
            }
        }
    }

    // Public methods for PlayerAnimationController
    public bool IsWalking() => isWalking && !isWalkingBackwards && !isRunning;
    public bool IsWalkingBackwards() => isWalkingBackwards;
    public bool IsRunning() => isRunning;
    public float GetCurrentAngularSpeed() => isRotating ? turnSpeed * delayedInput.x : 0f;

    // Public method to deactivate player controller
    public void SetActive(bool active)
    {
        isActive = active;
        if (!isActive && inputDelayCoroutine != null)
        {
            StopCoroutine(inputDelayCoroutine);
        }
    }
}
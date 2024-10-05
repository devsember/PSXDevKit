using UnityEngine;
using UnityEngine.InputSystem;

public class InputManager : MonoBehaviour
{
    public static InputManager Instance { get; private set; }

    private InputSystem_Actions inputActions;

    // Action values
    private Vector2 moveInput;
    private Vector2 lookInput;
    private bool isRunning;
    private bool isInteracting;

    // Events
    public delegate void InteractInputEvent();
    public event InteractInputEvent OnInteractPressed;

    private void Awake()
    {
        // Singleton pattern
        if (Instance == null)
        {
            Instance = this;
            DontDestroyOnLoad(gameObject);
        }
        else
        {
            Destroy(gameObject);
            return;
        }

        inputActions = new InputSystem_Actions();
    }

    private void OnEnable()
    {
        inputActions.Enable();

        // Subscribe to events
        inputActions.Player.Move.performed += OnMovePerformed;
        inputActions.Player.Move.canceled += OnMoveCanceled;
        inputActions.Player.Look.performed += OnLookPerformed;
        inputActions.Player.Look.canceled += OnLookCanceled;
        inputActions.Player.Run.performed += OnRunPerformed;
        inputActions.Player.Run.canceled += OnRunCanceled;
        inputActions.Player.Interact.performed += OnInteractPerformed;
    }

    private void OnDisable()
    {
        inputActions.Disable();

        // Unsubscribe from events
        inputActions.Player.Move.performed -= OnMovePerformed;
        inputActions.Player.Move.canceled -= OnMoveCanceled;
        inputActions.Player.Look.performed -= OnLookPerformed;
        inputActions.Player.Look.canceled -= OnLookCanceled;
        inputActions.Player.Run.performed -= OnRunPerformed;
        inputActions.Player.Run.canceled -= OnRunCanceled;
        inputActions.Player.Interact.performed -= OnInteractPerformed;
    }

    // Input event handlers
    private void OnMovePerformed(InputAction.CallbackContext context) => moveInput = context.ReadValue<Vector2>();
    private void OnMoveCanceled(InputAction.CallbackContext context) => moveInput = Vector2.zero;
    private void OnLookPerformed(InputAction.CallbackContext context) => lookInput = context.ReadValue<Vector2>();
    private void OnLookCanceled(InputAction.CallbackContext context) => lookInput = Vector2.zero;
    private void OnRunPerformed(InputAction.CallbackContext context) => isRunning = true;
    private void OnRunCanceled(InputAction.CallbackContext context) => isRunning = false;
    private void OnInteractPerformed(InputAction.CallbackContext context)
    {
        isInteracting = true;
        OnInteractPressed?.Invoke();
    }

    // Public methods to access input values
    public Vector2 GetMoveInput() => moveInput;
    public Vector2 GetLookInput() => lookInput;
    public bool IsRunning() => isRunning;
    public bool IsInteracting() => isInteracting;
}
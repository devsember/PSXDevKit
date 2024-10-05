using UnityEngine;

public class PlayerAnimationController : MonoBehaviour
{
    private Animator animator;
    private PlayerController playerController;

    [Header("Animation Smoothing")]
    [SerializeField] private float angularSpeedDampTime = 0.25f;
    [SerializeField] private float animationBlendSpeed = 3.0f;

    // Animation parameter hashes for efficiency
    private int isWalkingHash;
    private int isWalkingBackwardsHash;
    private int isRunningHash;
    private int angularSpeedHash;

    private float currentAngularSpeedParameter = 0f;

    private void Start()
    {
        animator = GetComponentInChildren<Animator>();
        playerController = GetComponent<PlayerController>();

        // Cache parameter hashes
        isWalkingHash = Animator.StringToHash("IsWalking");
        isWalkingBackwardsHash = Animator.StringToHash("IsWalkingBackwards");
        isRunningHash = Animator.StringToHash("IsRunning");
        angularSpeedHash = Animator.StringToHash("AngularSpeed");
    }

    private void Update()
    {
        UpdateMovementAnimation();
        UpdateRotationAnimation();
    }

    public void UpdateMovementAnimation()
    {
        animator.SetBool(isWalkingHash, playerController.IsWalking());
        animator.SetBool(isWalkingBackwardsHash, playerController.IsWalkingBackwards());
        animator.SetBool(isRunningHash, playerController.IsRunning());
    }

    public void UpdateRotationAnimation()
    {
        float targetAngularSpeed = playerController.GetCurrentAngularSpeed();
        currentAngularSpeedParameter = Mathf.Lerp(currentAngularSpeedParameter, targetAngularSpeed, Time.deltaTime * animationBlendSpeed);
        animator.SetFloat(angularSpeedHash, currentAngularSpeedParameter, angularSpeedDampTime, Time.deltaTime);
    }

    // Public method to trigger other animations (e.g., interaction animations)
    public void TriggerInteractionAnimation(string triggerName)
    {
        animator.SetTrigger(triggerName);
    }
}
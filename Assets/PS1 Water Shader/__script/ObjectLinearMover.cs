using UnityEngine;

public class ObjectLinearMover : MonoBehaviour
{
    public float moveSpeed = 1.0f;

    void Update()
    {
        // Move the GameObject along the Z-axis over time
        float zOffset = moveSpeed * Time.deltaTime;
        transform.Translate(Vector3.forward * zOffset);
    }
}

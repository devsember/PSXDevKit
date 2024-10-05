using UnityEngine;

public class ScrollTexture : MonoBehaviour
{
    public float scrollSpeed = 0.5f;

    void Update()
    {
        // Calculate the offset based on time and speed
        float offset = Time.time * scrollSpeed;

        // Apply the offset to the material's main texture offset
        GetComponent<Renderer>().material.mainTextureOffset = new Vector2(offset, 0);

        // If you want to tile the texture, you can set the main texture tiling as well
        // Uncomment the line below if you want to tile the texture horizontally
        // GetComponent<Renderer>().material.mainTextureScale = new Vector2(2, 1); // Adjust the values accordingly
    }
}

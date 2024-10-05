using UnityEngine;
using UnityEngine.UI;

[ExecuteAlways]
public class RuleOfThirdsGuide : MonoBehaviour
{
    public Color guideColor = Color.white; // Color of the guide lines
    public bool showGuides = true; // Toggle for showing/hiding guides

    private void OnGUI()
    {
        if (!showGuides)
            return;

        GUI.color = guideColor;

        float screenWidth = Screen.width;
        float screenHeight = Screen.height;

        // Vertical lines (Rule of Thirds)
        float thirdWidth = screenWidth / 3.0f;
        DrawLine(new Vector2(thirdWidth, 0), new Vector2(thirdWidth, screenHeight));
        DrawLine(new Vector2(2 * thirdWidth, 0), new Vector2(2 * thirdWidth, screenHeight));

        // Horizontal lines (Rule of Thirds)
        float thirdHeight = screenHeight / 3.0f;
        DrawLine(new Vector2(0, thirdHeight), new Vector2(screenWidth, thirdHeight));
        DrawLine(new Vector2(0, 2 * thirdHeight), new Vector2(screenWidth, 2 * thirdHeight));
    }

    private void DrawLine(Vector2 start, Vector2 end, float thickness = 2.0f)
    {
        Vector2 d = end - start;
        float angle = Mathf.Rad2Deg * Mathf.Atan2(d.y, d.x);
        float length = d.magnitude;
        GUIUtility.RotateAroundPivot(angle, start);
        GUI.DrawTexture(new Rect(start.x, start.y, length, thickness), Texture2D.whiteTexture);
        GUIUtility.RotateAroundPivot(-angle, start);
    }

    private void Update()
    {
        // Toggle the guide lines with the "G" key
        if (Input.GetKeyDown(KeyCode.G))
        {
            showGuides = !showGuides;
        }
    }
}
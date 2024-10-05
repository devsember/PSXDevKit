using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class GameManager : MonoBehaviour
{
    // Start is called before the first frame update
    void Start()
    {
        //Screen.fullScreenMode = FullScreenMode.ExclusiveFullScreen;
        //Screen.SetResolution(1920, 1080, true);
        // Hide the cursor
        Cursor.visible = false;

        // Lock the cursor to the center of the screen
        Cursor.lockState = CursorLockMode.None;
    }

    // Update is called once per frame
    void Update()
    {
        // Check if the Escape key is pressed
        if (Input.GetKeyDown(KeyCode.Escape))
        {
            // If running in the Unity editor, stop play mode
#if UNITY_EDITOR
            UnityEditor.EditorApplication.isPlaying = false;
#else
            // If running a build, quit the application
            Application.Quit();
#endif
        }
    }
}

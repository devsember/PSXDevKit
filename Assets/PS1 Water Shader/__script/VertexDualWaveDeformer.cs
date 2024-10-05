using UnityEngine;

public class VertexDualWaveDeformer : MonoBehaviour
{
    public float waveSpeed = 1.0f;
    public float waveHeight = 0.1f;
    public float waveOffset = 0.5f;

    private Vector3[] originalVertices;
    private Mesh mesh;

    void Start()
    {
        // Make sure the GameObject has a MeshFilter component
        MeshFilter meshFilter = GetComponent<MeshFilter>();
        if (meshFilter == null || meshFilter.sharedMesh == null)
        {
            Debug.LogError("MeshFilter or Mesh not found on the GameObject.");
            return;
        }

        // Store the original vertices of the mesh
        mesh = meshFilter.mesh;
        originalVertices = mesh.vertices.Clone() as Vector3[];
    }

    void Update()
    {
        DeformMesh();
    }

    void DeformMesh()
    {
        // Get the current vertices of the mesh
        Vector3[] vertices = mesh.vertices;

        // Deform the vertices over time with two independent waves
        for (int i = 0; i < vertices.Length; i++)
        {
            float leftWave = Mathf.Sin((Time.time * waveSpeed + vertices[i].x));
            float rightWave = Mathf.Sin((Time.time * waveSpeed + vertices[i].x + waveOffset));

            vertices[i].y = originalVertices[i].y + (leftWave + rightWave) * 0.5f * waveHeight;
        }

        // Update the mesh with the deformed vertices
        mesh.vertices = vertices;
        mesh.RecalculateNormals();
    }
}

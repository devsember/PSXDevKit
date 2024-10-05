using UnityEngine;

public class VertexComplexWaveDeformer : MonoBehaviour
{
    public float waveSpeed = 1.0f;
    public float waveHeight = 0.1f;
    public float waveOffset = 0.5f;
    public float smallWaveSpeed = 3.0f;
    public float smallWaveHeight = 0.02f;
    public float waveScale = 1.0f; // New variable for wave scale

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
            float leftWave = Mathf.Sin((Time.time * waveSpeed + vertices[i].x) * waveScale);
            float rightWave = Mathf.Sin((Time.time * waveSpeed + vertices[i].x + waveOffset) * waveScale);
            float topWave = Mathf.Sin((Time.time * waveSpeed + vertices[i].z) * waveScale);
            float bottomWave = Mathf.Sin((Time.time * waveSpeed + vertices[i].z + waveOffset) * waveScale);
            
            float smallWaveX = Mathf.Sin(Time.time * smallWaveSpeed + vertices[i].x * waveScale);
            float smallWaveZ = Mathf.Sin(Time.time * smallWaveSpeed + vertices[i].z * waveScale);

            vertices[i].y = originalVertices[i].y + (leftWave + rightWave + topWave + bottomWave + smallWaveX + smallWaveZ) * 0.5f * waveHeight;
        }

        // Update the mesh with the deformed vertices
        mesh.vertices = vertices;
        mesh.RecalculateNormals();
    }
}

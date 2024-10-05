Its as Simple as it goes, There are a few scripts and a Water shader that is Lit and Transparent, for now i cant find a way to make sure that the
water is unlit but i suppose a lit shader is good enough for any sort of ps1 game since it dsnt have shadows anyway,

# PS1 Shader
the shader consists of a few values such as Jittering and Affine Texture mapping which can be found on any PSX style shader
the Jittering value contains how much the vertex jittering affects the model, the higher the value the more the inconsistency 
on the mesh

the Affine Texture mapping is in charge of controlling how much affine texture mapping is applied to the given material, if
you dont know about what affine texture mapping is then visit here https://danielilett.com/2021-11-06-tut5-21-ps1-affine-textures/ 
the higher the value the more the camera angle will stretch the texture and distort it

then there are your Main Texture, Specular map Tint and smoothness which operates the same as a normal material does
the alpha value on the Main texture Color is what controls the transparency on the water meshes, the materials are to attached 
to a plane (in this demo i used the default unity plane 3d object and it worked just fine with the waves and etc)




# The Wave System (Normal Wave System)

there are a few scripts to control the wave on the object, attach scripts to your water plane and set the values which will
deform and move the vertex geometry of your mesh thus making a wave like system, its very light on cpu considering a ps1 
game wont need that much water anyway and even if it does it still keeps the performance nice and smooth above 400fps on this case


- Texture Wave Distortion

waveSpeed, waveIntensity, patternIntensity, overallDistortion, textureDistortionSpeed, and textureDistortionAmount: These are public variables that allow you to control the parameters of the wave system in the Unity Editor. Adjusting these values will change the appearance and behavior of the wave effect.
meshRenderer: This variable holds a reference to the MeshRenderer component attached to the GameObject. The MeshRenderer is responsible for rendering the object and its material.
originalTiling: This variable stores the original tiling of the material's main texture. It is used to modify the texture scale while preserving the original tiling.
Start method: In the Start method, the script checks if there is a MeshRenderer component and a material attached to the GameObject. If they are present, it stores the original texture tiling.
Update method: The Update method is called every frame, and it, in turn, calls the DistortTexture method.
DistortTexture method: This method is responsible for applying the wave-like distortion to the material's texture. Here's how it works:
textureOffset: Retrieves the current texture offset.
waveOffset: Calculates a wave offset based on the waveSpeed and waveIntensity. The Mathf.Sin function creates a smooth oscillation over time.
overallDistortion: Multiplies the wave offset by the overallDistortion factor, controlling the overall intensity of the distortion.
meshRenderer.material.mainTextureOffset: Applies the wave offset to the material's main texture offset, creating a horizontal wave effect.
textureDistortionOffset: Calculates a texture distortion offset based on textureDistortionSpeed and textureDistortionAmount. This adds an additional layer of distortion.
newTiling: Modifies the original tiling by adding the texture distortion offset to it.
meshRenderer.material.mainTextureScale: Applies the modified tiling to the material's texture scale, creating a vertical texture distortion.
patternColor: Creates a color with alpha (transparency) set by patternIntensity. This color will be used to add a pattern or highlight.
meshRenderer.material.SetColor("_PatternColor", patternColor): Applies the pattern intensity to the material's color using a property named "_PatternColor." This can be used in a custom shader to add additional visual effects.
In summary, this script uses sine waves and additional parameters to create a dynamic and visually interesting texture distortion effect on a GameObject's material. Adjusting the public variables allows you to fine-tune the appearance of the wave distortion.

- Vertex Complex Wave Deformer

1. **`waveSpeed`, `waveHeight`, `waveOffset`, `smallWaveSpeed`, `smallWaveHeight`**: These are public variables that control the parameters of the wave deformation. You can adjust these values in the Unity Editor to control the speed, height, offset, and small wave characteristics.

2. **`originalVertices`**: This array stores the original vertices of the mesh, which is used as a reference to deform the vertices over time.

3. **`mesh`**: This variable holds a reference to the mesh of the GameObject.

4. **`Start` method**: In the `Start` method, the script ensures that the GameObject has a `MeshFilter` component and a valid mesh. It then stores the original vertices of the mesh.

5. **`Update` method**: The `Update` method is a Unity callback that gets called every frame. It, in turn, calls the `DeformMesh` method.

6. **`DeformMesh` method**: This method is responsible for deforming the vertices of the mesh based on various sine waves:

    - **`vertices`**: Retrieves the current vertices of the mesh.

    - **`leftWave`, `rightWave`, `topWave`, `bottomWave`**: These variables calculate the contributions from four sine waves that move along the X and Z axes, creating a wave pattern.

    - **`smallWaveX`, `smallWaveZ`**: These variables calculate the contributions from two additional small sine waves, creating finer details in the deformation.

    - **`vertices[i].y`**: Modifies the y-coordinate of each vertex based on the sum of all wave contributions, scaled by `waveHeight`. The sum is divided by 2 to average the effect, and the result is added to the original y-coordinate.

    - **`mesh.vertices = vertices`**: Updates the mesh with the deformed vertices.

    - **`mesh.RecalculateNormals()`**: Recalculates the normals of the mesh. This is important for lighting calculations and is necessary when modifying the vertex positions.

In summary, this script deforms the vertices of a mesh by combining multiple sine waves with different frequencies and amplitudes. The result is a dynamic and complex wave-like deformation that gives a sense of movement to the mesh. Adjusting the public variables allows you to control the characteristics of the deformation.


# There are also two more Versions which do the same thing but they have lot less detail vertextwavedeformer and the vertextdualwavedeformer
# There are Two scenes one uses the Advanced wave system and the other uses a normal wave system




# [Project 1: Supa Hot Fire Ball]

Project by Anthony Ge

[Live demo link  here!](https://geant04.github.io/hw01-fireball/)

![fireball](/fireball.gif)

Implementation details

## Fireball Shaders
### Vertex Shader
- The fireball shape is constructed by a combination of the flame tips, an overall warp to make the shape look like a cone, and high frequency waves for fine detail.
- To achieve the flame tips, I use FBM sine waves to vertically displace vertices, biasing the amplitude only if their y position is above a threshold
- To warp the sphere, I use another sine function to shape the ball
- I wanted to make the ball "wobble" in the end, which I achived by using FBM sine waves again with very high frequency and low amplitude, displacing instead in the x,z directions
- To wobble the ball even more, I used my x,y,z displacement values and treated them as a magnitude, to which I then multiplied by interpolated 3D value noise to offset vertices by their normals
- I do use gain a bit too in my xz wobble.

### Fragment Shader
- This is the bulk of the detail, but in summary, all it is an alpha-noise mask used to discard pixels, achieving a very nice flames look + general FBM noise sampled with a (0, time) offset to make it rise.
- To brighten up the tips, I use a smoothstep on the alpha-clipped values that are within a certain range, then using that as an input for my lerp between the flame and tip colors
- I applied rim lighting on the bottom to brighten up the edges of the ball, achieved using the view angle dotted with the normal, then using some techniques to calculate a fresnel value

## Bonus + Background Shaders
### Party Mode
- All this does is change the flame color, which is done using a simple cosine-gradient color ramp + using time as an input
### Kaboom
- Honestly, this only exists because I found out later on that it's required to use four toolbox functions. To solve that missing requirement and looking at a few functions, particularly impulse, I felt it made sense to make the ball explode over time.
- In essence, the kaboom is just amplifying the normal displacement in the vertex shader and the brightness of the fireball in the fragment shader
- To calculate intensity for the kaboom:
  - I use an impulse function to map the power of the blast over time (it should boom then quickly fade out)
  - To make the impulse function repeat over time, I use a sawtooth function with t as input so that input for impulse is always [0,1]
  - I then slightly bias the impulse result to my liking, using a low value arbitrarily
- Using my intensity value for what I described before achieves a nice explosion effect.
### Background
- For the background, I rendered a massive cube behind (modifying its scale in the vertex shader), and use a specialzied fragment shader to fake lighitng
- Fragment Shader
  - I split the fragment shading of the cube into two parts: the wall texture, the lighting
    - The wall texture is detailed using domain warped FBM noise. To darken the walls a bit, I calculate a value that's simply the inverse of the distance from vertex position to origin squared; this is mostly inspired by how we calculate light falloff for most rendering purposes. 
    - For the lighting of the scene, I use the same falloff calculation to light up the scene, except I use some FBM sine waves to jitter the range in the distance calculation. In addition, I re-use my intensity value so that light reaches farther in the explosion, illuminating the box!
  - Combining both, I now have a scene in the back with real-time lighting that behaves like real-life!

## References
- Used Morgan Mcguire's [3D value noise implementation](https://www.shadertoy.com/view/4dS3Wd) found on Shadertoy 

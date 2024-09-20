#version 300 es

//This is a vertex shader. While it is called a "shader" due to outdated conventions, this file
//is used to apply matrix transformations to the arrays of vertex data passed to it.
//Since this code is run on your GPU, each vertex is transformed simultaneously.
//If it were run on your CPU, each vertex would have to be processed in a FOR loop, one at a time.
//This simultaneous transformation allows your program to run much faster, especially when rendering
//geometry with millions of vertices.

uniform mat4 u_Model;       // The matrix that defines the transformation of the
                            // object we're rendering. In this assignment,
                            // this will be the result of traversing your scene graph.

uniform mat4 u_ModelInvTr;  // The inverse transpose of the model matrix.
                            // This allows us to transform the object's normals properly
                            // if the object has been non-uniformly scaled.

uniform mat4 u_ViewProj;    // The matrix that defines the camera's transformation.
                            // We've written a static matrix for you to use for HW2,
                            // but in HW3 you'll have to generate one yourself

uniform float u_Time;
uniform float u_KaboomSpeed;


in vec4 vs_Pos;             // The array of vertex positions passed to the shader

in vec4 vs_Nor;             // The array of vertex normals passed to the shader

in vec4 vs_Col;             // The array of vertex colors passed to the shader.

out vec4 fs_Nor;            // The array of normals that has been transformed by u_ModelInvTr. This is implicitly passed to the fragment shader.
out vec4 fs_LightVec;       // The direction in which our virtual light lies, relative to each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Col;            // The color of each vertex. This is implicitly passed to the fragment shader.
out vec4 fs_Pos;

const vec4 lightPos = vec4(5, 5, 3, 1); //The position of our virtual light, which is used to compute the shading of
                                        //the geometry in the fragment shader.

uniform float u_Amplitude;
uniform float u_Persistence;
uniform float u_Frequency;
uniform float u_Lacunarity;
uniform int u_Octaves;

#define PI 3.1415926535897932

float bias(float b, float t) 
{
    return pow(t, log(b) / log(0.5));
}

float gain(float g, float t)
{
    if (t < 0.5)
        return bias(1.0 - g, 2.0 * t) / 2.0;
    else
        return 1.0 - bias(1.0 - g, 2.0 - 2.0 * t) / 2.0;
}

float sawtooth_wave(float x, float freq, float amplitude)
{
    return (x * freq - floor(x * freq) * amplitude);
}

float impulse(float k, float x)
{
    float h = k*x;
    return h * exp(1.0 - h);
}

float hash(float p) { p = fract(p * 0.011); p *= p + 7.5; p *= p + p; return fract(p); }

float value3D(vec3 pos)
{
    // https://www.shadertoy.com/view/4dS3Wd Morgan Mcguire my goat
    const vec3 step = vec3(110, 241, 171);

    vec3 i = floor(pos);
    vec3 f = fract(pos);

    float n = dot(i, step);

    vec3 u = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix( hash(n + dot(step, vec3(0, 0, 0))), hash(n + dot(step, vec3(1, 0, 0))), u.x),
                   mix( hash(n + dot(step, vec3(0, 1, 0))), hash(n + dot(step, vec3(1, 1, 0))), u.x), u.y),
               mix(mix( hash(n + dot(step, vec3(0, 0, 1))), hash(n + dot(step, vec3(1, 0, 1))), u.x),
                   mix( hash(n + dot(step, vec3(0, 1, 1))), hash(n + dot(step, vec3(1, 1, 1))), u.x), u.y), u.z);
}

float fbm(vec3 pos)
{
    float total = 0.0;

    float persistence = u_Persistence;
    float amp = u_Amplitude;
    float freq = u_Frequency;
    float lacunarity = u_Lacunarity;

    int octaves = u_Octaves;

    for (int i = 0; i < octaves; i++)
    {
        total += amp * value3D(pos * freq);
        amp *= persistence;
        freq *= lacunarity;
    }

    return total;
}

float flamesDisplacement(vec3 pos, float time)
{
    float speed = 2.0;
    float yPos = pos.y;
    float exFactor = pos.x + pos.z;
    float finalLayer = sin(0.010 * exFactor + 9.0 * yPos + time * speed) * 0.50 + 0.50;

    if (yPos > 0.44)
    {
        return pow(yPos - 0.10, 8.0) * (0.40 * finalLayer) / 0.40;
    }

    return 0.0;
}

float displacement(vec3 pos, float time)
{
    float speed = 2.0;
    float totalDisplacement = 0.0;

    float noisePhase = speed * time;

    float lowFreqNoise = fbm(pos + vec3(noisePhase, noisePhase, noisePhase));
    totalDisplacement += lowFreqNoise;

    return totalDisplacement;
}

float sway(vec3 pos, float p, float time)
{
    float xPos = pos.x;
    float yPos = pos.y;

    float swaySpeed = 10.5;
    float totalDisplacement = 0.0;
    float amplify = impulse(0.3, 1.2 * yPos); // toolbox function!!

    float swayAmt = 0.02 * sin(30.0 * amplify + swaySpeed * time) + 0.50;

    swayAmt += 0.04 * gain(0.3, (0.5 * sin(60.0 * amplify + 4.0 * swaySpeed * time) + 0.50));

    totalDisplacement += 0.30 * swayAmt;

    float caveIn = (pos.y + 0.3);
    caveIn = sin(1.0 * caveIn + 5.5) + (2.0 * sin(2.0 * caveIn + -0.5));
    caveIn += 2.0;

    return p * -caveIn * totalDisplacement;
}


void main()
{
    fs_Col = vs_Col;                         // Pass the vertex colors to the fragment shader for interpolation

    float deltaY = 0.20 * displacement(vs_Pos.rgb, u_Time);
    float deltaX = 1.0 * sway(vs_Pos.rgb, vs_Pos.x, u_Time);
    float deltaZ = 1.0 * sway(vs_Pos.rgb, vs_Pos.z, u_Time);
    float flamesDisplacement = flamesDisplacement(vs_Pos.rgb, u_Time);

    vec3 localVertex = vs_Pos.rgb + vec3(
        deltaX, 
        deltaY + flamesDisplacement,
        deltaZ
    );

    localVertex.y *= 1.35;

    mat3 invTranspose = mat3(u_ModelInvTr);
    fs_Nor = vec4(invTranspose * vec3(vs_Nor), 0);          // Pass the vertex normals to the fragment shader for interpolation.
                                                            // Transform the geometry's normals by the inverse transpose of the
                                                            // model matrix. This is necessary to ensure the normals remain
                                                            // perpendicular to the surface after the surface is transformed by
                                                            // the model matrix.
    // kaboom
    float intensify;
    float t = sawtooth_wave(u_KaboomSpeed * u_Time, 0.9 + (u_KaboomSpeed - 0.10), 1.0); // toolbox func 0
    intensify = 1.0 - impulse(0.70, clamp(t, 0.01, 0.2)); // toolbox func 1

    localVertex += fs_Nor.rgb * (0.20 + 2.0 * bias(0.1, intensify * 1.08)) * deltaY; // toolbox func 2

    vec4 modelposition = u_Model * vec4(localVertex, 1.0);   // Temporarily store the transformed vertex positions for use below

    fs_Pos = modelposition;

    fs_LightVec = lightPos - modelposition;  // Compute the direction in which the light source lies

    gl_Position = u_ViewProj * modelposition;// gl_Position is a built-in variable of OpenGL which is
                                             // used to render the final positions of the geometry's vertices
}

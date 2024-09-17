#version 300 es

precision highp float;

uniform vec4 u_Color; // The color with which to render this instance of geometry.
// uniform int u_NoiseType; // use this later when we want to render a different type of noise...
// uniform int u_EnableFBM; // use this to enable FBM later when I get there lol
uniform float u_Amplitude;
uniform float u_Persistence;
uniform float u_Frequency;
uniform float u_Lacunarity;
uniform float u_Time;

in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Col;
in vec4 fs_Pos;

out vec4 out_Col; 

#define PI 3.1415926535897932

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

    int octaves = 8;

    for (int i = 0; i < octaves; i++)
    {
        total += amp * value3D(pos * freq);
        amp *= persistence;
        freq *= lacunarity;
    }

    return total;
}

float cosineGradient(float x, vec4 props)
{
    float dc = props.x;
    float amp = props.y;
    float freq = props.z;
    float phase = props.w;

    return clamp(amp * cos(freq * x * PI + phase * PI * 2.0) + dc, 0.0, 1.0);
}

void main()
{
    // Material base color (before shading)
        vec4 diffuseColor = u_Color;
        
        vec3 noiseInput = fs_Pos.xyz;
        noiseInput.x *= 2.0;
        noiseInput.y -= 2.0 * u_Time;
        
        float noise = fbm(noiseInput);
        vec3 pos = fs_Pos.rgb;
        vec3 normal = fs_Nor.rgb;
        
        vec3 testColor = vec3(1.0, 0., 0.);


        float flameClip = 2.0 * pow((pos.y + 1.00), 1.5) * noise;

        testColor = mix(testColor, vec3(1.0, 1.0, 0.0), clamp(flameClip / 2.3, 0.0, 1.0));

        if (flameClip > 1.4)
        {
            flameClip = smoothstep(flameClip, 0.2, 1.0);
            vec3 flameColor = mix(vec3(1, 1, 0), vec3(1), flameClip * 1.4);
            testColor = mix(testColor, flameColor, 1.9 * flameClip);
            testColor *= 1.2;

            if (flameClip > 0.6)
            {
                //testColor = vec3(0);
                discard;
            }
        }

        // Compute final shaded color
        out_Col = vec4(testColor, (1.5 - pos.y));
}

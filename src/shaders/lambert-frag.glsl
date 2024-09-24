#version 300 es

// This is a fragment shader. If you've opened this file first, please
// open and read lambert.vert.glsl before reading on.
// Unlike the vertex shader, the fragment shader actually does compute
// the shading of geometry. For every pixel in your program's output
// screen, the fragment shader is run for every bit of geometry that
// particular pixel overlaps. By implicitly interpolating the position
// data passed into the fragment shader by the vertex shader, the fragment shader
// can compute what color to apply to its pixel based on things like vertex
// position, light position, and vertex color.
precision highp float;

uniform vec4 u_Color; // The color with which to render this instance of geometry.
uniform vec4 u_SecondFlameColor;
uniform vec4 u_FlameTipColor;

// These are the interpolated values out of the rasterizer, so you can't know
// their specific values without knowing the vertices that contributed to them
in vec4 fs_Nor;
in vec4 fs_LightVec;
in vec4 fs_Col;
in vec4 fs_Pos;
uniform vec4 u_CameraPos;

uniform float u_Time;
uniform float u_KaboomSpeed;
uniform int u_IsPartyTime;

uniform float u_Amplitude;
uniform float u_Persistence;
uniform float u_Frequency;
uniform float u_Lacunarity;

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

float impulse(float k, float x)
{
    float h = k*x;
    return h * exp(1.0 - h);
}

float sawtooth_wave(float x, float freq, float amplitude)
{
    return (x * freq - floor(x * freq) * amplitude);
}

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

float cosineGradient(float x, vec4 props)
{
    float dc = props.x;
    float amp = props.y;
    float freq = props.z;
    float phase = props.w;

    return clamp(amp * cos(freq * x * PI + phase * PI * 2.0) + dc, 0.0, 1.0);
}

out vec4 out_Col; // This is the final output color that you will see on your
                  // screen for the pixel that is currently being processed.

void main()
{
    // Material base color (before shading)
        vec4 diffuseColor = u_Color;
        vec3 flameTipColor = u_FlameTipColor.rgb;

        if (u_IsPartyTime == 1)
        {
            float partySpeed = 4.0;
            float nR = cosineGradient(partySpeed * u_Time, vec4(0.5, 0.5, 1.0, 0.0));
            float nG = cosineGradient(partySpeed * u_Time, vec4(0.5, 0.5, 1.0, 0.3333));
            float nB = cosineGradient(partySpeed * u_Time, vec4(0.5, 0.5, 1.0, 0.6666));

            vec3 partyColors = vec3(nR, nG, nB);
            flameTipColor *= partyColors;
        }

        // Calculate the diffuse term for Lambert shading
        float diffuseTerm = dot(normalize(-fs_Nor), normalize(fs_LightVec));
        // Avoid negative lighting values
        diffuseTerm = clamp(diffuseTerm, 0.0, 1.0);

        float ambientTerm = 0.2;

        float lightIntensity = diffuseTerm + ambientTerm;   //Add a small float value to the color multiplier
                                                            //to simulate ambient lighting. This ensures that faces that are not
                                                            //lit by our point light are not completely black.

        vec3 camPos = normalize(vec3(u_CameraPos.rgb));

        float intensify;
        float t = sawtooth_wave(u_KaboomSpeed * u_Time, 0.9 + (u_KaboomSpeed - 0.10), 1.0);
        intensify = 1.0 - impulse(0.95, t);
        intensify = bias(0.1, intensify);
        
        float flicker = 0.30 * sin(u_Time * 10.0)  * 0.50 + 0.50;
        flicker += 0.30 * abs(0.20 + sin(u_Time * 4.0 + 30.0));
        flicker += 0.15 * abs(0.20 + sin(u_Time * 8.0 + 30.0));
        flicker += 0.075 * abs(0.20 + sin(u_Time * 16.0 + 70.0));

        vec3 lightColor = flameTipColor.rgb;
        lightColor *= u_Color.rgb;

        float dist = 1.0 - pow(length(fs_Pos) / 150.0, 2.0);
        float lightPow = max(0.0001, (length(fs_Pos) - 80.0 * (intensify) - 20.0 * flicker + 30.0) / 140.0);
        lightPow = 1.0 / pow(lightPow, 2.0);

        vec3 bgColor = mix(vec3(0.1, 0.1, 0.1) * 0.20, vec3(0.3, 0.3, 0.3) * 0.20, dist);
        float noiseV = fbm(fs_Pos.rgb * 0.05);
        noiseV = fbm(vec3(noiseV, noiseV, noiseV));
        bgColor = mix(bgColor, vec3(0), noiseV * 0.50 + 0.50);
        bgColor *= (lightPow);


        float light = (lightPow) * 0.10;
        light *= 1.2  + (0.60 * flicker + 0.40);
        light *= 0.50;

        // Compute final shaded color
        out_Col = vec4(2.0 * bgColor + lightColor * light, 1.0);
}

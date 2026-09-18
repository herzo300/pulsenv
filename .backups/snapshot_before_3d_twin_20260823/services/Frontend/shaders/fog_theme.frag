#include <flutter/runtime_effect.glsl>

uniform vec2  u_resolution;
uniform float u_time;
uniform vec3  u_color1;  // Dark background (e.g. #1A1A2E)
uniform vec3  u_color2;  // Fog color (e.g. #5C5C7A)
uniform float u_quality;

out vec4 fragColor;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f*f*(3.0-2.0*f);
    return mix(mix(hash(i), hash(i+vec2(1.,0.)), f.x),
               mix(hash(i+vec2(0.,1.)), hash(i+vec2(1.,1.)), f.x), f.y);
}

// 3D volumetric feel using layered noise
float fbm(vec2 p) {
    float f = 0.0;
    float amp = 0.5;
    int octaves = u_quality > 0.5 ? 4 : 2;
    for (int i = 0; i < 4; i++) {
        if (i >= octaves) break;
        f += amp * noise(p);
        p *= 2.0;
        amp *= 0.5;
    }
    return f;
}

void main() {
    vec2 uv = FlutterFragCoord().xy / u_resolution;
    uv.x *= u_resolution.x / u_resolution.y;

    // Background gradient
    vec3 col = mix(u_color1, vec3(0.05, 0.05, 0.08), uv.y);

    // Layer 1 - back fog, slow
    float fog1 = fbm(uv * 2.0 + vec2(u_time * 0.05, 0.0));
    
    // Layer 2 - front fog, fast, parallax
    float fog2 = fbm(uv * 4.0 - vec2(u_time * 0.15, u_time * 0.05));
    
    // Smooth transition
    float totalFog = smoothstep(0.2, 0.8, (fog1 + fog2) * 0.5);

    col = mix(col, u_color2, totalFog * 0.8);

    // Add soft vignette
    float dist = length(uv - vec2(0.5 * u_resolution.x/u_resolution.y, 0.5));
    col *= exp(-dist * 1.5);

    fragColor = vec4(col, 1.0);
}

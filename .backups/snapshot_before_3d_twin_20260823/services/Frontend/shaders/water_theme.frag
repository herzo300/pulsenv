#include <flutter/runtime_effect.glsl>

uniform vec2  u_resolution;
uniform float u_time;
uniform vec3  u_color1;
uniform vec3  u_color2;
uniform float u_quality;

out vec4 fragColor;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
               mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x), f.y);
}

// FBM with fewer octaves for water
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

    // Caustics-like distortion
    vec2 q = vec2(fbm(uv + u_time * 0.1), fbm(uv + vec2(5.2, 1.3) - u_time * 0.15));
    vec2 r = vec2(fbm(uv + 4.0 * q + vec2(1.7, 9.2) + u_time * 0.1),
                  fbm(uv + 4.0 * q + vec2(8.3, 2.8) - u_time * 0.12));
    
    float f = fbm(uv + 4.0 * r);

    // Color gradient
    vec3 col = mix(u_color1, u_color2, f);
    
    // Add bright caustics highlights
    col += vec3(0.5, 0.8, 1.0) * pow(f, 3.0) * 0.5;
    
    // Depth vignette
    float vig = length(uv - vec2(0.5 * u_resolution.x/u_resolution.y, 0.5));
    col *= 1.0 - vig * 0.5;

    fragColor = vec4(col, 1.0);
}

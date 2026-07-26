#include <flutter/runtime_effect.glsl>

uniform vec2  u_resolution;
uniform float u_time;
uniform float u_density;    // 0.3..1.0
uniform float u_quality;

out vec4 fragColor;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash(i);
    float b = hash(i + vec2(1.0, 0.0));
    float c = hash(i + vec2(0.0, 1.0));
    float d = hash(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void main() {
    vec2 fc = FlutterFragCoord().xy;
    vec2 uv = fc / u_resolution;
    
    // Dark blue-grey background
    vec3 bg = mix(
        vec3(0.06, 0.08, 0.12),
        vec3(0.10, 0.14, 0.20),
        uv.y * 0.5
    );

    // Rain streaks
    float rain = 0.0;
    float layers = u_quality > 0.5 ? 4.0 : 2.0;
    
    for (float i = 0.0; i < 4.0; i++) {
        if (i >= layers) break;
        float speed = 1.05 + i * 0.75;
        float scale = 9.0 + i * 4.5;
        
        vec2 rainUV = uv * vec2(scale, 1.0);
        rainUV.y += u_time * speed;
        
        float cell = hash(floor(rainUV));
        if (cell > (1.0 - u_density * 0.36)) {
            float streak = 1.0 - abs(fract(rainUV.x) - 0.5) * 8.0;
            streak *= fract(rainUV.y) * fract(rainUV.y);
            streak = max(streak, 0.0);
            rain += streak * 0.085 / (1.0 + i * 0.65);
        }
    }

    // Fog layer
    float fog = noise(uv * 3.0 + u_time * 0.05) * 0.08;

    // Compose
    vec3 col = bg;
    col += vec3(0.6, 0.7, 0.85) * rain;
    col += vec3(0.4, 0.45, 0.55) * fog;

    // Vignette
    float vig = 1.0 - smoothstep(0.3, 0.9, length(uv - 0.5) * 1.5);
    col *= 0.7 + 0.3 * vig;

    fragColor = vec4(col, 1.0);
}

#include <flutter/runtime_effect.glsl>

uniform vec2  u_resolution;
uniform float u_time;
uniform float u_rain_density;    // 0.0..1.0
uniform float u_fog_density;     // 0.0..1.0
uniform float u_holo_density;    // 0.0..1.0

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

float fbm(vec2 p) {
    float f = 0.0;
    float amp = 0.5;
    for (int i = 0; i < 3; i++) {
        f += amp * noise(p);
        p *= 2.0;
        amp *= 0.5;
    }
    return f;
}

// Fine holographic grid lines
float holoGrid(vec2 uv, float scale, float lineWidth) {
    vec2 grid = fract(uv * scale);
    vec2 lines = step(1.0 - lineWidth, grid);
    return max(lines.x, lines.y);
}

void main() {
    vec2 fc = FlutterFragCoord().xy;
    vec2 uv = fc / u_resolution;
    
    vec3 finalColor = vec3(0.0);
    float finalAlpha = 0.0;
    
    // --- 1. RAIN ---
    if (u_rain_density > 0.05) {
        float rain = 0.0;
        // Draw 3 layers of rain streaks with different parallax speeds
        for (float i = 0.0; i < 3.0; i++) {
            float speed = 1.45 + i * 0.85;
            float scale = 14.0 + i * 5.0;
            
            // Slanted UV for falling rain angle
            vec2 rainUV = uv * vec2(scale, 1.0);
            rainUV.x -= rainUV.y * 0.08; 
            rainUV.y += u_time * speed;
            
            float cell = hash(floor(rainUV));
            // Density check
            if (cell > (1.0 - u_rain_density * 0.45)) {
                float streak = 1.0 - abs(fract(rainUV.x) - 0.5) * 8.0;
                streak *= fract(rainUV.y) * fract(rainUV.y);
                streak = max(streak, 0.0);
                rain += streak * 0.14 / (1.0 + i * 0.7);
            }
        }
        
        vec3 rainColor = vec3(0.68, 0.82, 0.98);
        finalColor += rainColor * rain;
        finalAlpha += rain * 0.8;
    }
    
    // --- 2. FOG ---
    if (u_fog_density > 0.05) {
        // volumetric drifting noise
        float fogVal1 = fbm(uv * 3.0 + vec2(u_time * 0.06, 0.0));
        float fogVal2 = fbm(uv * 5.0 - vec2(u_time * 0.12, u_time * 0.04));
        float totalFog = smoothstep(0.3, 0.8, (fogVal1 + fogVal2) * 0.5) * u_fog_density;
        
        vec3 fogColor = vec3(0.52, 0.58, 0.68);
        finalColor = mix(finalColor, fogColor, totalFog * 0.5);
        finalAlpha = max(finalAlpha, totalFog * 0.32);
    }
    
    // --- 3. HOLOGRAM GRID ---
    if (u_holo_density > 0.05) {
        // grid Fine
        float grid = holoGrid(uv, 18.0, 0.02) * 0.28;
        
        // Scan line horizontals
        float scanline = sin(uv.y * 140.0 + u_time * 2.5) * 0.5 + 0.5;
        grid += scanline * 0.05;
        
        // Horizontal scanner sweep
        float sweepY = fract(u_time * 0.18);
        float sweep = smoothstep(0.02, 0.0, abs(uv.y - sweepY)) * 0.22;
        sweep += smoothstep(0.08, 0.0, abs(uv.y - sweepY)) * 0.06;
        grid += sweep;
        
        vec3 holoColor = vec3(0.0, 0.95, 0.85) * u_holo_density; // cyan neon
        finalColor += holoColor * grid;
        finalAlpha = max(finalAlpha, grid * 0.38 * u_holo_density);
    }
    
    // Output transparent overlay color
    fragColor = vec4(finalColor, clamp(finalAlpha, 0.0, 1.0));
}

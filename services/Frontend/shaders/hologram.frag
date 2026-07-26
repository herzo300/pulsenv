#version 460 core
#include <flutter/runtime_effect.glsl>

uniform float u_time;
uniform vec2 u_resolution;
uniform sampler2D u_texture;

out vec4 fragColor;

// --- Utility ---
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

// --- Holographic Grid ---
float holoGrid(vec2 uv, float scale, float lineWidth) {
    vec2 grid = fract(uv * scale);
    vec2 lines = step(1.0 - lineWidth, grid);
    return max(lines.x, lines.y);
}

// --- Scanline effect ---
float scanlines(vec2 uv, float density, float speed) {
    float line = sin(uv.y * density + u_time * speed);
    return line * 0.5 + 0.5;
}

// --- Wave distortion ---
vec2 waveDistort(vec2 uv, float amplitude, float frequency) {
    float wave = sin(uv.y * frequency + u_time * 2.5) * amplitude;
    return vec2(uv.x + wave, uv.y);
}

// --- Chromatic Aberration ---
vec4 chromaticAberration(sampler2D tex, vec2 uv, float strength) {
    vec2 dir = (uv - 0.5) * strength;
    float r = texture(tex, uv + dir).r;
    float g = texture(tex, uv).g;
    float b = texture(tex, uv - dir).b;
    return vec4(r, g, b, 1.0);
}

// --- Refraction Distortion (glassmorphic) ---
vec2 glassDistort(vec2 uv) {
    float noise = hash(floor(uv * 20.0) + floor(u_time));
    float waveX = sin(uv.y * 8.0 + u_time * 1.5) * 0.003;
    float waveY = cos(uv.x * 6.0 + u_time * 1.2) * 0.002;
    return uv + vec2(waveX, waveY);
}

void main() {
    vec2 fragCoord = FlutterFragCoord().xy;
    vec2 uv = fragCoord / u_resolution;

    // 1. Glass distortion (subtle UV warp for refractive look)
    vec2 distortedUv = glassDistort(uv);
    
    // 2. Wave-distorted UV for holographic shifting
    vec2 warpedUv = waveDistort(distortedUv, 0.003, 12.0);

    // 3. Sample base texture with chromatic aberration
    vec4 baseColor = chromaticAberration(u_texture, warpedUv, 0.008);
    
    // 4. Holographic grid overlay — two scales for depth
    float gridFine = holoGrid(uv, 25.0, 0.04);
    float gridCoarse = holoGrid(uv, 8.0, 0.03);
    
    // Animate grid brightness
    float gridPulse = 0.5 + 0.5 * sin(u_time * 1.2);
    float gridMask = mix(gridFine * 0.6, gridCoarse * 0.3, 0.4) * gridPulse;
    
    // 5. Neon scanner beam (horizontal sweep)
    float scannerY = fract(u_time * 0.25);  // scanner sweeps top to bottom
    float scannerBeam = smoothstep(0.04, 0.0, abs(uv.y - scannerY)) * 0.7;
    float scannerGlow = smoothstep(0.15, 0.0, abs(uv.y - scannerY)) * 0.2;
    
    // 6. Scanlines
    float scan = scanlines(uv, 180.0, 3.0) * 0.04;
    
    // 7. Iridescent color shift (rainbow tint based on position + time)
    float hueShift = fract(uv.x * 0.5 + u_time * 0.08);
    vec3 iridescent = vec3(
        0.5 + 0.5 * sin(hueShift * 6.28318 + 0.0),
        0.5 + 0.5 * sin(hueShift * 6.28318 + 2.094),
        0.5 + 0.5 * sin(hueShift * 6.28318 + 4.189)
    ) * 0.12;
    
    // 8. Holographic edge glow (stronger near edges)
    float edgeDist = length(vec2(0.5) - uv) * 2.0;
    float edgeGlow = smoothstep(0.6, 1.0, edgeDist) * 0.25;
    
    // --- Compose ---
    vec3 color = baseColor.rgb;
    
    // Add grid (cyan/teal neon)
    color += vec3(0.0, 0.9, 0.8) * gridMask * 0.4;
    
    // Add scanner beam (bright cyan sweep)
    color += vec3(0.1, 1.0, 0.9) * (scannerBeam + scannerGlow);
    
    // Add scanlines
    color -= vec3(scan);
    
    // Add iridescent overlay
    color += iridescent;
    
    // Add edge glow (deep blue/purple)
    color += vec3(0.2, 0.1, 0.8) * edgeGlow;
    
    // Slight brightness boost for VIP hologram feel
    color = pow(color, vec3(0.9));  // gamma lift
    
    fragColor = vec4(color, baseColor.a);
}

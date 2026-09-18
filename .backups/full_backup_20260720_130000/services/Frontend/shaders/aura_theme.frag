#include <flutter/runtime_effect.glsl>

uniform vec2  u_resolution;
uniform float u_time;
uniform vec3  u_color1;   // Primary Aura Color
uniform vec3  u_color2;   // Secondary Aura Color
uniform float u_quality;
// NEW uniforms
uniform vec2  u_touch;    // normalized touch position (0..1)
uniform float u_energy;   // touch energy 0..1

out vec4 fragColor;

// ── Helpers ──────────────────────────────────────────────────────────────────
float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i),          hash(i + vec2(1., 0.)), f.x),
               mix(hash(i + vec2(0., 1.)), hash(i + vec2(1., 1.)), f.x), f.y);
}

// FBM — 4 октавы для богатого органичного поля
float fbm(vec2 p) {
    float f = 0.0, amp = 0.5;
    for (int i = 0; i < 4; i++) {
        f   += amp * noise(p);
        p    = p * 2.02 + vec2(1.31, 7.19);
        amp *= 0.5;
    }
    return f;
}

// Domain-warped FBM — для ауры второго порядка
float warpFbm(vec2 p) {
    vec2 q = vec2(fbm(p + vec2(0.0, 0.0)),
                  fbm(p + vec2(5.2, 1.3)));
    return fbm(p + 3.5 * q);
}

void main() {
    vec2 uv     = FlutterFragCoord().xy / u_resolution;
    vec2 cUV    = uv - 0.5;
    cUV.x      *= u_resolution.x / u_resolution.y;

    float dist  = length(cUV);

    // ── Органичный дрейф ауры (3-слойный) ──────────────────────────────────
    vec2 drift1 = vec2(noise(vec2(u_time * 0.18, 0.0)),
                       noise(vec2(0.0, u_time * 0.18))) * 0.18;
    vec2 drift2 = vec2(noise(vec2(u_time * 0.09, 3.14)),
                       noise(vec2(3.14, u_time * 0.09))) * 0.10;

    float n1 = fbm((cUV + drift1) * 2.5 + u_time * 0.35);
    float n2 = fbm((cUV - drift1) * 4.0 - u_time * 0.22);
    float n3 = noise(cUV * 8.5 + u_time * 0.6) * 0.28; // мелкая детализация

    // Domain-warp поле второго порядка
    float warp = warpFbm(cUV * 1.2 + u_time * 0.06);

    // ── Реакция на касание ──────────────────────────────────────────────────
    vec2 touchPt  = u_touch - 0.5;
    touchPt.x    *= u_resolution.x / u_resolution.y;
    vec2 toTouch  = cUV - touchPt;
    float tDist   = length(toTouch);
    // Волна-ряби от касания
    float touchWave = sin(tDist * 20.0 - u_time * 7.0)
                      * exp(-tDist * 5.5)
                      * u_energy;
    // Локальное свечение под пальцем
    float touchGlow = exp(-tDist * 4.5) * u_energy;

    // ── Итоговое поле ────────────────────────────────────────────────────────
    float field = n1 * 0.48 + n2 * 0.32 + n3 + warp * 0.18
                  + touchWave * 0.35;
    field = field * 0.5 + 0.5;

    // ── Blend ────────────────────────────────────────────────────────────────
    float blend = smoothstep(0.0, 1.0, field);

    // Расширенный хвост ауры (power 2.0 → плавнее, чем exp(-dist*2.5))
    float glow  = pow(max(0.0, 1.0 - dist * 1.75), 2.2);

    vec3 baseColor  = mix(u_color1, u_color2, blend);
    vec3 finalColor = baseColor * glow * (1.6 + touchGlow * 0.8);

    // ── Фоновый градиент (тёмно-фиолетовый) ─────────────────────────────────
    finalColor += mix(vec3(0.04, 0.02, 0.09), vec3(0.0), dist * 1.2);

    // ── Кинцуги золотые прожилки поверх ауры ─────────────────────────────────
    // Тонкие золотые линии по полю n2
    float veins = smoothstep(0.04, 0.0, abs(n2 - 0.5)) * glow;
    finalColor += vec3(0.98, 0.80, 0.25) * veins * 0.20;

    // ── Перламутровые переливы (soap-bubble иридесценция) ────────────────────
    float iridescence = sin(dist * 30.0 - u_time * 1.8) * 0.5 + 0.5;
    vec3  soap = mix(vec3(0.7, 0.35, 1.0), vec3(0.2, 0.85, 1.0), iridescence);
    finalColor += soap * glow * 0.07 * (0.5 + warp * 0.5);

    // ── Реакция пальца — яркая вспышка ─────────────────────────────────────
    finalColor += mix(u_color1, vec3(1.0, 0.95, 0.85), 0.6)
                  * touchGlow * 0.55;

    // ── Виньетка ─────────────────────────────────────────────────────────────
    finalColor *= smoothstep(0.82, 0.24, dist);

    fragColor = vec4(finalColor, 1.0);
}

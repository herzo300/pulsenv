#include <flutter/runtime_effect.glsl>

uniform vec2  u_resolution;
uniform float u_time;
uniform vec3  u_color1;   // background (dark purple/blue)
uniform vec3  u_color2;   // nebula (pinkish/cyan)
uniform float u_quality;
uniform vec2  u_touch;
uniform float u_energy;

out vec4 fragColor;

float hash(vec2 p) {
    return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2(1., 0.)), f.x),
               mix(hash(i + vec2(0., 1.)), hash(i + vec2(1., 1.)), f.x), f.y);
}

float fbm(vec2 p) {
    float f = 0.0, amp = 0.5;
    int octaves = u_quality > 0.5 ? 5 : 3;
    for (int i = 0; i < 5; i++) {
        if (i >= octaves) break;
        f   += amp * noise(p);
        p   *= 2.0;
        amp *= 0.5;
    }
    return f;
}

// Медленно вращающийся FBM — туманность
float nebulaFbm(vec2 p) {
    vec2 q = vec2(fbm(p + vec2(0.0, 0.0)),
                  fbm(p + vec2(5.2, 1.3)));
    vec2 r = vec2(fbm(p + 4.0 * q + vec2(1.7, 9.2)),
                  fbm(p + 4.0 * q + vec2(8.3, 2.8)));
    return fbm(p + 4.0 * r);
}

void main() {
    vec2 uv  = FlutterFragCoord().xy / u_resolution;
    uv.x    *= u_resolution.x / u_resolution.y;

    // Center
    vec2 cuv  = uv - vec2(0.5 * u_resolution.x / u_resolution.y, 0.5);
    float dist = length(cuv);
    float ang  = atan(cuv.y, cuv.x);
    vec2 touch = u_touch - 0.5;
    touch.x *= u_resolution.x / u_resolution.y;
    float touchDist = length(cuv - touch);

    // ── Медленная галактическая ротация ─────────────────────────────────────
    float rot_s = sin(u_time * 0.04), rot_c = cos(u_time * 0.04);
    vec2 rot_uv = vec2(cuv.x * rot_c - cuv.y * rot_s,
                       cuv.x * rot_s + cuv.y * rot_c);

    // ── Туманность (domain-warped FBM) ─────────────────────────────────────
    float dust  = nebulaFbm(rot_uv * 2.8 + u_time * 0.06);
    float dust2 = fbm(rot_uv * 5.5 - u_time * 0.14);

    // Трёхцветная туманность
    vec3 nebula1 = mix(u_color1, u_color2,           dust  * dust2 * 2.2);
    vec3 nebula2 = mix(u_color2, u_color1 * 0.5 + u_color2 * 0.5,
                       fbm(rot_uv * 4.0 + vec2(3.1, 1.7) + u_time * 0.08));
    vec3 col = mix(nebula1, nebula2, dist * 0.6);

    // ── Млечный Путь — диагональная светлая полоса ─────────────────────────
    float mwAngle = 0.62;  // угол наклона
    float mwDist  = dot(cuv, vec2(cos(mwAngle), sin(mwAngle)));
    float milkyWay = exp(-pow(mwDist * 3.5, 2.0))
                     * (0.5 + 0.5 * fbm(cuv * 3.0 + u_time * 0.02));
    col += mix(u_color2 * 0.4, vec3(0.9, 0.85, 1.0), milkyWay * 0.4)
           * milkyWay * 0.18;

    // ── Звёзды (3 слоя: далёкие, средние, ближние) ─────────────────────────
    // Далёкие — мелкие, много, не мерцают
    float r_far = hash(floor(uv * 280.0) + vec2(11.0, 77.0));
    if (r_far > 0.994) {
        col += vec3(0.8, 0.85, 1.0) *
               smoothstep(0.006, 0.0, length(fract(uv * 280.0) - 0.5)) * 0.5;
    }

    // Средние — мерцают
    if (u_quality > 0.25) {
        float r_mid = hash(floor(uv * 120.0) + vec2(3.0, 5.0));
        if (r_mid > 0.978) {
            float twinkle = 0.55 + 0.45 * sin(u_time * (2.5 + r_mid * 4.0) + r_mid * 100.0);
            float sz = smoothstep(0.01, 0.0, length(fract(uv * 120.0) - 0.5));
            col += vec3(1.0, 0.95, 0.88) * sz * twinkle * 0.85;
        }
    }

    // Ближние — крупные, яркие, с гало
    if (u_quality > 0.45) {
        float r_near = hash(floor(uv * 60.0) + vec2(9.0, 2.3));
        if (r_near > 0.972) {
            float twinkle = 0.7 + 0.3 * sin(u_time * (1.8 + r_near * 3.0));
            float sz = smoothstep(0.016, 0.0, length(fract(uv * 60.0) - 0.5));
            // Крест-гало (диффракция)
            vec2 fLocal = fract(uv * 60.0) - 0.5;
            float cross_ = exp(-abs(fLocal.x) * 25.0) * exp(-abs(fLocal.y) * 8.0)
                          + exp(-abs(fLocal.y) * 25.0) * exp(-abs(fLocal.x) * 8.0);
            col += (vec3(1.0, 0.92, 0.75) * (sz + cross_ * 0.1)) * twinkle * 0.9;
        }
    }

    // ── Двойная спираль галактики ────────────────────────────────────────────
    float spiral1 = exp(-dist * 3.2)
                    * sin(ang * 2.0 - dist * 9.0 + u_time * 0.6) * 0.55;
    float spiral2 = exp(-dist * 2.8)
                    * sin(ang * 3.0 + dist * 13.0 - u_time * 0.45) * 0.32;
    float spiral3 = exp(-dist * 4.5)  // тонкая внутренняя спираль
                    * sin(ang * 5.0 - dist * 6.0 + u_time * 0.9) * 0.18;
    col += u_color2 * (spiral1 + spiral2 + spiral3);

    // ── Мягкое свечение центра (без точки) ─────────────────────────────────
    float agn = exp(-dist * 3.0) * (0.20 + 0.10 * sin(u_time * 0.72));
    col += mix(vec3(1.0, 0.9, 0.7), u_color2, 0.65) * agn * 0.08;

    // Touch gravity haze: wide, soft, never a hard ripple.
    float touchGlow = exp(-touchDist * 4.2) * u_energy;
    float touchWave = sin(touchDist * 18.0 - u_time * 4.0)
                      * exp(-touchDist * 5.8) * u_energy;
    col += mix(u_color2, vec3(1.0, 0.92, 0.72), 0.45)
           * (touchGlow * 0.18 + touchWave * 0.045);

    fragColor = vec4(col, 1.0);
}

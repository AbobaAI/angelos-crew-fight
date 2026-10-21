#version 440
// crowd (3 rows of jumping silhouettes, phones, camera flashes) + sweeping spotlights,
// the same maths as the old crowd Canvas, evaluated on the GPU per pixel
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float fr;
    float hype;
    float cam;
    vec4 a2;
    vec4 c0; vec4 c1; vec4 c2; vec4 c3; vec4 c4; vec4 c5; vec4 c6; vec4 c7;
};
vec4 acc;
int imod(int a, int b) { return a - b * (a / b); }
void over(vec3 c, float a) { acc = vec4(c * a, a) + acc * (1.0 - a); }
bool inR(vec2 p, float x, float y, float w, float h) { return p.x >= x && p.x < x + w && p.y >= y && p.y < y + h; }
vec3 coat(int k) {
    vec4 c = k == 0 ? c0 : k == 1 ? c1 : k == 2 ? c2 : k == 3 ? c3 : k == 4 ? c4 : k == 5 ? c5 : k == 6 ? c6 : c7;
    return c.rgb;
}
void main() {
    vec2 p = qt_TexCoord0 * vec2(900.0, 560.0);
    acc = vec4(0.0);
    for (int r = 2; r >= 0; r--) {
        float Ry = r == 0 ? 262.0 : r == 1 ? 228.0 : 198.0;
        float Rn = r == 0 ? 34.0 : r == 1 ? 38.0 : 44.0;
        float s = r == 0 ? 1.0 : r == 1 ? 0.82 : 0.66;
        float Ra = r == 0 ? 0.55 : r == 1 ? 0.42 : 0.3;
        if (p.y < Ry - 80.0 || p.y > Ry + 20.0) continue;
        float stp = 860.0 / Rn, sh = sin(fr / 20.0 + float(r)) * float(3 - r);
        float hw = 12.0 * s, al = min(1.0, Ra + hype * 0.25);
        int i0 = int(floor((p.x - 20.0 - sh) / stp));
        for (int di = -2; di <= 1; di++) {
            int i = i0 + di;
            if (i < 0 || float(i) >= Rn) continue;
            int seed = imod(i * 7919 + r * 104729, 97);
            vec3 c = coat(imod(seed, 8)) / (1.6 + float(r) * 0.3);
            float cx = 20.0 + float(i) * stp + sh;
            float jump = floor(abs(sin(fr / 4.0 + float(seed))) * (1.0 + hype * 10.0) * s + 0.5);
            float by2 = Ry - jump, rx = floor(cx + 0.5);
            if (inR(p, rx, by2 - hw, hw, hw)) over(c, al);
            if (inR(p, floor(cx - 2.0 * s + 0.5), by2, hw + 4.0 * s, 16.0 * s)) over(c, al);
            if (hype > 0.35 && imod(seed, 3) != 0) {
                float wv = sin(fr / 2.0 + float(seed)) * 3.0;
                if (inR(p, floor(cx - 5.0 * s + wv + 0.5), by2 - hw - 8.0 * s, 3.0 * s, 12.0 * s)) over(c, al);
                if (inR(p, floor(cx + hw + 2.0 * s - wv + 0.5), by2 - hw - 8.0 * s, 3.0 * s, 12.0 * s)) over(c, al);
            }
            if (imod(seed, 9) == 0) {
                if (inR(p, floor(cx + hw + 2.0 + 0.5), by2 - hw - 10.0 * s, 5.0 * s, 8.0 * s)) over(vec3(0.812, 0.89, 1.0), 0.9);
                if (cam > 0.0 && imod(seed + int(floor(fr)), 5) == 0) {
                    if (inR(p, floor(cx + hw - 6.0 + 0.5), by2 - hw - 18.0 * s, 22.0 * s, 22.0 * s)) over(vec3(1.0), 0.85);
                    if (inR(p, floor(cx + hw - 16.0 + 0.5), by2 - hw - 28.0 * s, 42.0 * s, 42.0 * s)) over(vec3(1.0), 0.25);
                }
            }
        }
    }
    // spotlights
    float fy = 470.0, top = 88.0;
    for (int k = 0; k < 2; k++) {
        float sx = k == 0 ? 120.0 : 780.0, tx = 450.0 + sin(fr / 30.0 + float(k) * 2.4) * 260.0;
        vec3 col = k == 0 ? a2.rgb : vec3(1.0);
        if (p.y >= top && p.y <= fy) {
            float t = (p.y - top) / (fy - top);
            if (p.x >= mix(sx - 8.0, tx - 70.0, t) && p.x <= mix(sx + 8.0, tx + 70.0, t)) over(col, 0.07 + hype * 0.05);
        }
        vec2 e = (p - vec2(tx, fy)) / vec2(70.0, 8.0);
        if (dot(e, e) <= 1.0) over(col, 0.18);
    }
    float t2 = (p.y - 156.0) / (fy - 156.0);
    if (t2 >= 0.0 && t2 <= 1.0 && p.x >= mix(410.0, 120.0, t2) && p.x <= mix(490.0, 780.0, t2)) over(vec3(1.0), 0.05);
    fragColor = acc * qt_Opacity;
}

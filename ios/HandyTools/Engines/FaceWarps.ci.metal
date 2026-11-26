// Face fun warps (26 Nov): Core Image warp kernels for the Video Studio's face and body effects. Each returns, for a
// pixel of the finished frame, where in the original frame to take it from. Coordinates are Core Image's (origin at
// the bottom left, y up). Built with -fcikernel (project.yml) into the app's default.metallib.
#include <CoreImage/CoreImage.h>
using namespace metal;

extern "C" {
namespace coreimage {

// Turns `p` (relative to a centre) into a frame turned by `angle`, and back.
static inline float2 into(float2 p, float c, float s) { return float2(c * p.x + s * p.y, -s * p.x + c * p.y); }
static inline float2 outof(float2 q, float c, float s) { return float2(c * q.x - s * q.y, s * q.x + c * q.y); }

// An oval that swells (strength > 0) or shrinks (< 0) around `centre`, its half-axes `radii` turned by `angle`, each
// axis with its own strength: a round balloon, a tall egg, a squashed face, a big mouth. Smoothly back to the
// untouched picture at the rim, so nothing tears (a shrink past -1.25 would fold the picture over itself, so the
// strength is held inside what stays one-to-one).
float2 tenzyBulge(float2 centre, float2 radii, float angle, float2 strength, destination dest) {
    float2 d = dest.coord();
    float c = cos(angle), s = sin(angle);
    float2 q = into(d - centre, c, s);
    float2 n = q / max(radii, float2(1.0));
    float r2 = dot(n, n);
    if (r2 >= 1.0) { return d; }
    float w = (1.0 - r2); w = w * w;
    float2 k = 1.0 - clamp(strength, float2(-1.2), float2(0.92)) * w;
    return centre + outof(q * k, c, s);
}

// The top of the head drawn up taller (an egg) and narrowed to a point (a cone) above the brows. `base` is the brow
// line's middle, `up` the head's up direction, `height` from the brows to just above the hair, `width` the head's
// half-width. The higher a pixel, the lower and nearer the middle it samples from, so the head grows and tapers.
float2 tenzyCone(float2 base, float2 up, float height, float width, float stretch, float point, destination dest) {
    float2 d = dest.coord();
    float2 p = d - base;
    float2 side = float2(up.y, -up.x);
    float v = dot(p, up);
    float u = dot(p, side);
    float top = height * (1.0 + stretch);
    if (v <= 0.0 || v >= top * 1.02 || fabs(u) >= width * 1.35) { return d; }
    float t = clamp(v / top, 0.0, 1.0);
    float sv = v / (1.0 + stretch * smoothstep(0.0, 1.0, t));
    float su = u * (1.0 + point * t * t * 2.2);
    float keep = 1.0 - smoothstep(width * 0.95, width * 1.35, fabs(u));
    float fadeTop = 1.0 - smoothstep(top * 0.97, top * 1.02, v);
    float k = keep * fadeTop;
    return base + up * mix(v, sv, k) + side * mix(u, su, k);
}

// A band that starts at `line` and runs `length` along `dir` is drawn `k` times as long (legs made longer, k > 1);
// what lies beyond the band moves along by the difference, what lies before the line stays where it is.
float2 tenzyBand(float2 line, float2 dir, float length, float k, destination dest) {
    float2 d = dest.coord();
    float v = dot(d - line, dir);
    if (v <= 0.0) { return d; }
    float kk = max(k, 0.05);
    float sv = v < length * kk ? v / kk : v - length * (kk - 1.0);
    return d + dir * (sv - v);
}

}
}

package com.handytools.app.tools.studio

import android.content.Context
import android.opengl.GLES20
import androidx.media3.common.VideoFrameProcessingException
import androidx.media3.common.util.GlProgram
import androidx.media3.common.util.GlUtil
import androidx.media3.common.util.Size
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BaseGlShaderProgram
import androidx.media3.effect.GlEffect
import androidx.media3.effect.GlShaderProgram
import java.nio.ByteBuffer

/**
 * Face fun on the GPU (the iPhone's FaceFun warps and skin, as one shader): the faces [People] found are followed frame
 * by frame; [FaceFun] turns the chosen effect into bends (bulge, cone, twirl, stretch, the bald crown), a skin tone
 * inside each face and a mood for the whole picture. Stickers go on top separately (an overlay Tenzy draws).
 */
@androidx.annotation.OptIn(UnstableApi::class)
class FaceFunEffect(private val people: People, private val id: String, private val amount: Float = 0.6f) : GlEffect {
    override fun toGlShaderProgram(context: Context, useHdr: Boolean): GlShaderProgram = Program(people, id, amount, useHdr)

    companion object {
        const val MAX_BENDS = 10

        /**
         * The uniforms for one moment: bends in GL pixels (y up) and the skin of up to two faces. Pure, so its numbers
         * are tested on the build machine. Returns (bendsA, bendsB, faceC, faceT, eyes, mouth) as flat arrays.
         */
        fun frameUniforms(id: String, faces: List<FaceSpot>, w: Int, h: Int, t: Float, a: Float, parts: Boolean = false): Uniforms {
            val fs = faces.take(2).map { FaceFun.face(it, w, h) }
            val bends = ArrayList<FaceFun.Bend>()
            // With the face engine's parts, Bald is drawn from the hair and skull (baldNew in the shader), not bent.
            if (!(parts && id == "bald")) fs.forEach { bends += FaceFun.bends(id, it, t, a, w, h) }
            if (id == "longlegs") fs.firstOrNull()?.let { FaceFun.legs(it, h, a) }?.let { bends += it }
            val bA = FloatArray(MAX_BENDS * 4); val bB = FloatArray(MAX_BENDS * 4)
            bends.take(MAX_BENDS).forEachIndexed { i, b ->
                // Into GL: y up, and a tilt is the other way round.
                when (b.kind) {
                    1 -> { bA[i * 4] = b.a[0]; bA[i * 4 + 1] = h - b.a[1]; bA[i * 4 + 2] = b.a[2]; bA[i * 4 + 3] = b.a[3]
                        bB[i * 4] = -b.b[0]; bB[i * 4 + 1] = b.b[1]; bB[i * 4 + 2] = b.b[2] }
                    2, 5 -> { bA[i * 4] = b.a[0]; bA[i * 4 + 1] = h - b.a[1]; bA[i * 4 + 2] = b.a[2]; bA[i * 4 + 3] = b.a[3]
                        bB[i * 4] = b.b[0]; bB[i * 4 + 1] = b.b[1]; bB[i * 4 + 2] = b.b[2] }
                    3 -> { bA[i * 4] = b.a[0]; bA[i * 4 + 1] = h - b.a[1]; bA[i * 4 + 2] = b.a[2]; bB[i * 4] = b.b[0] }
                    4 -> { bA[i * 4] = h - b.a[0]; bA[i * 4 + 1] = b.a[1]; bB[i * 4 + 1] = b.b[1] }
                }
                bB[i * 4 + 3] = b.kind.toFloat()
            }
            val skin = FaceFun.skin(id).toFloat()
            fun strength(lo: Float, hi: Float) = lo + (hi - lo) * a
            val k = when (id) { "alien" -> strength(0.6f, 0.95f); "zombie" -> strength(0.65f, 0.97f); "robot" -> strength(0.7f, 1f)
                "glow" -> strength(0.3f, 0.55f); "beautiful" -> strength(0.25f, 0.5f); "wholesome" -> strength(0.2f, 0.4f); else -> 0f }
            val faceC = FloatArray(8); val faceT = FloatArray(8); val eyes = FloatArray(8); val mouth = FloatArray(8)
            fs.forEachIndexed { i, f ->
                val c = f.point(f.center, up = f.height * 0.12f)
                faceC[i * 4] = c.x; faceC[i * 4 + 1] = h - c.y; faceC[i * 4 + 2] = f.width * 0.5f; faceC[i * 4 + 3] = f.height * 0.68f
                faceT[i * 4] = f.roll; faceT[i * 4 + 1] = skin; faceT[i * 4 + 2] = k; faceT[i * 4 + 3] = f.eyeDistance
                eyes[i * 4] = f.eyeA.x; eyes[i * 4 + 1] = h - f.eyeA.y; eyes[i * 4 + 2] = f.eyeB.x; eyes[i * 4 + 3] = h - f.eyeB.y
                mouth[i * 4] = f.mouth.x; mouth[i * 4 + 1] = h - f.mouth.y; mouth[i * 4 + 2] = f.mouthWidth
            }
            return Uniforms(bA, bB, faceC, faceT, eyes, mouth, FaceFun.mood(id).toFloat(), bends.size.coerceAtMost(MAX_BENDS))
        }

        /** Up to two skulls as the shader takes them (GL pixels, y up): centre + half-axes, brow + up, tone + on. */
        fun skullUniforms(skulls: List<FaceEngine.Skull>, lookW: Int, lookH: Int, w: Int, h: Int): FloatArray {
            val out = FloatArray(24)
            val kx = w / lookW.toFloat(); val ky = h / lookH.toFloat()
            skulls.take(2).forEachIndexed { i, s ->
                val o = i * 12
                // Directions scale with the frame too (the look may be smaller), then are made unit again.
                var ux = s.ux * kx; var uy = s.uy * ky; val l = kotlin.math.hypot(ux, uy).coerceAtLeast(1e-6f); ux /= l; uy /= l
                out[o] = s.cx * kx; out[o + 1] = h - s.cy * ky; out[o + 2] = s.ax * kx; out[o + 3] = s.ay * ky
                out[o + 4] = s.bx * kx; out[o + 5] = h - s.by * ky; out[o + 6] = ux; out[o + 7] = -uy
                out[o + 8] = s.tone[0]; out[o + 9] = s.tone[1]; out[o + 10] = s.tone[2]; out[o + 11] = 1f
            }
            return out
        }

        class Uniforms(val bendA: FloatArray, val bendB: FloatArray, val faceC: FloatArray, val faceT: FloatArray, val eyes: FloatArray,
                       val mouth: FloatArray, val mood: Float, val count: Int)

        private const val VERTEX = """
attribute vec4 aFramePosition;
varying vec2 vTexSamplingCoord;
void main() {
  gl_Position = aFramePosition;
  vTexSamplingCoord = vec2(aFramePosition.x * 0.5 + 0.5, aFramePosition.y * 0.5 + 0.5);
}
"""

        // Pixel space, y up (GL). Bends are applied last-first: each one says where the picture before it is read from.
        private val FRAGMENT = buildString {
            append("""
precision highp float;
uniform sampler2D uTexSampler;
uniform sampler2D uMask;
uniform float uHasMask;
uniform vec2 uSize;
uniform float uTime;
uniform float uAmount;
uniform float uMood;
uniform vec4 uFaceC0; uniform vec4 uFaceC1;
uniform vec4 uFaceT0; uniform vec4 uFaceT1;
uniform vec4 uEyes0; uniform vec4 uEyes1;
uniform vec4 uMouth0; uniform vec4 uMouth1;
uniform float uHasParts;
uniform float uBald;
uniform sampler2D uHair;
uniform sampler2D uSkinTex;
uniform sampler2D uFill;
uniform vec4 uSkA0; uniform vec4 uSkB0; uniform vec4 uSkT0;
uniform vec4 uSkA1; uniform vec4 uSkB1; uniform vec4 uSkT1;
""")
            for (i in 0 until MAX_BENDS) append("uniform vec4 uA$i; uniform vec4 uB$i;\n")
            append("""
varying vec2 vTexSamplingCoord;
float baldShade = 1.0;

vec4 pick(vec2 px) { return texture2D(uTexSampler, clamp(px / uSize, 0.0, 1.0)); }
vec2 down(vec2 px) { return vec2(px.x / uSize.x, 1.0 - px.y / uSize.y); }
float personAt(vec2 px) { return uHasMask > 0.5 ? texture2D(uMask, vec2(px.x / uSize.x, 1.0 - px.y / uSize.y)).r : 1.0; }

vec2 into(vec2 p, float c, float s) { return vec2(c * p.x + s * p.y, -s * p.x + c * p.y); }
vec2 outof(vec2 q, float c, float s) { return vec2(c * q.x - s * q.y, s * q.x + c * q.y); }

vec2 bend(vec2 d, vec4 A, vec4 B) {
  float kind = B.w;
  if (kind < 0.5) return d;
  if (kind < 1.5) {
    vec2 centre = A.xy; float c = cos(B.x); float s = sin(B.x);
    vec2 q = into(d - centre, c, s);
    vec2 n = q / max(A.zw, vec2(1.0));
    float r2 = dot(n, n);
    if (r2 >= 1.0) return d;
    float w = (1.0 - r2); w = w * w;
    vec2 k = 1.0 - clamp(B.yz, vec2(-1.2), vec2(0.92)) * w;
    return centre + outof(q * k, c, s);
  }
  if (kind < 2.5) {
    vec2 up = vec2(sin(B.x), cos(B.x)); vec2 side = vec2(up.y, -up.x);
    vec2 p = d - A.xy; float v = dot(p, up); float u = dot(p, side);
    float stretch = B.y; float point = B.z; float height = A.z; float width = A.w;
    float top = height * (1.0 + stretch);
    if (v <= 0.0 || v >= top * 1.02 || abs(u) >= width * 1.35) return d;
    float t = clamp(v / top, 0.0, 1.0);
    float sv = v / (1.0 + stretch * smoothstep(0.0, 1.0, t));
    float su = u * (1.0 + point * t * t * 2.2);
    float keep = (1.0 - smoothstep(width * 0.95, width * 1.35, abs(u))) * (1.0 - smoothstep(top * 0.97, top * 1.02, v));
    return A.xy + up * mix(v, sv, keep) + side * mix(u, su, keep);
  }
  if (kind < 3.5) {
    vec2 e = d - A.xy; float t = length(e) / max(A.z, 1.0);
    if (t >= 1.0) return d;
    float ang = B.x * (1.0 - t) * (1.0 - t) * 1.6; float cs = cos(ang); float sn = sin(ang);
    return A.xy + vec2(e.x * cs - e.y * sn, e.x * sn + e.y * cs);
  }
  if (kind < 4.5) {
    float v = d.y - A.x; if (v <= 0.0) return d;
    float k = max(B.y, 0.05); float len = A.y;
    float sv = v < len * k ? v / k : v - len * (k - 1.0);
    return vec2(d.x, A.x + sv);
  }
  // The bald crown: the forehead just above the brows drawn up over the top of the head, rounded off with shade, and
  // the hair that stands out beyond it replaced by what's beside it.
  vec2 up = vec2(sin(B.x), cos(B.x)); vec2 side = vec2(up.y, -up.x);
  vec2 p = d - A.xy; float v = dot(p, up); float u = dot(p, side);
  float strip = A.z; float top = A.w; float rx = B.y; float ry = max(B.z, 1.0);
  float vc = top - ry;
  float e = length(vec2(u / max(rx, 1.0), (v - vc) / ry));
  float cap = (1.0 - smoothstep(0.94, 1.0, e)) * smoothstep(strip * 0.35, strip * 0.65, v);
  if (cap > 0.001) {
    baldShade = mix(1.0, mix(1.0, 0.8, smoothstep(0.45, 1.0, e)), cap);
    float sv = clamp(v, 0.0, top) * strip / max(top, 1.0);
    return mix(d, A.xy + up * sv + side * u, cap);
  }
  if (v > strip * 0.5 && e < 1.5 && personAt(d) > 0.5) {
    // Hair beyond the crown: what's just past it, along the same line across.
    float far = rx * 1.6;
    return A.xy + up * v + side * (u > 0.0 ? far : -far);
  }
  return d;
}

float faceMask(vec2 q, vec4 C, vec4 T, vec4 E, vec4 M) {
  if (T.y < 0.5) return 0.0;
  float c = cos(-T.x); float s = sin(-T.x);
  vec2 n = into(q - C.xy, c, s) / max(C.zw, vec2(1.0));
  float m = uHasParts > 0.5 ? (1.0 - smoothstep(1.25, 1.5, length(n))) * texture2D(uSkinTex, down(q)).r : 1.0 - smoothstep(0.8, 1.0, length(n));
  float hole = max(max(1.0 - smoothstep(0.6, 1.0, length(q - E.xy) / max(T.w * 0.26, 1.0)), 1.0 - smoothstep(0.6, 1.0, length(q - E.zw) / max(T.w * 0.26, 1.0))),
                   1.0 - smoothstep(0.6, 1.0, length((q - M.xy) / vec2(max(M.z * 0.62, 1.0), max(M.z * 0.32, 1.0)))));
  return m * (1.0 - hole);
}

vec3 soft(vec2 q, float r) {
  vec3 acc = vec3(0.0);
  for (int i = 0; i < 12; i++) {
    float fi = float(i); float rr = r * sqrt((fi + 0.5) / 12.0); float th = fi * 2.39996;
    acc += pick(q + vec2(cos(th), sin(th)) * rr).rgb;
  }
  return acc / 12.0;
}

float luma(vec3 c) { return dot(c, vec3(0.2126, 0.7152, 0.0722)); }
vec3 sat(vec3 c, float k) { float l = luma(c); return mix(vec3(l), c, k); }
vec3 screen(vec3 a, vec3 b) { return 1.0 - (1.0 - a) * (1.0 - b); }
float spot(vec2 q, vec2 c, float r) { return 1.0 - smoothstep(r * 0.4, r, length(q - c)); }

vec3 skin(vec3 col, vec2 q, vec4 C, vec4 T, vec4 E, vec4 M) {
  float m = faceMask(q, C, T, E, M) * T.z;
  if (m <= 0.001 && T.y < 0.5) return col;
  float kind = T.y; float ed = T.w;
  if (kind < 1.5) {
    vec3 g = sat(col, 0.45) * vec3(0.6, 1.0, 0.66);
    col = mix(col, g, m);
    float eye = max(spot(q, E.xy, ed * 0.34), spot(q, E.zw, ed * 0.34)) * 0.8;
    return mix(col, col * 0.62, eye);
  }
  if (kind < 2.5) {
    vec3 d = (sat(col, 0.3) - 0.5) * 1.18 + 0.5;
    col = mix(col, d * vec3(0.74, 0.95, 0.72), m);
    float ring = max(spot(q, E.xy, ed * 0.46) - spot(q, E.xy, ed * 0.16), spot(q, E.zw, ed * 0.46) - spot(q, E.zw, ed * 0.16));
    return mix(col, col * vec3(0.42, 0.3, 0.46), clamp(ring, 0.0, 1.0) * 0.7 * T.z);
  }
  if (kind < 3.5) {
    float l = clamp((luma(col) - 0.5) * 1.35 + 0.5, 0.0, 1.0);
    l = floor(l * 7.0) / 6.0;
    col = mix(col, vec3(l) * vec3(0.74, 0.86, 1.04), m);
    float pulse = 0.75 + 0.25 * sin(uTime * 4.0);
    float g = max(spot(q, E.xy, ed * 0.36), spot(q, E.zw, ed * 0.36)) * pulse * T.z;
    return screen(col, vec3(0.2, 0.95, 1.0) * g);
  }
  vec3 sm = soft(q, ed * 0.12);
  col = mix(col, sm, m);
  if (kind < 4.5) return screen(col, col * 0.35 * m);
  if (kind < 5.5) {
    float eye = max(spot(q, E.xy, ed * 0.22), spot(q, E.zw, ed * 0.22));
    return mix(col, min(col * 1.25, vec3(1.0)), eye * 0.6);
  }
  // Rosy cheeks either side of the nose.
  vec2 mid = (E.xy + E.zw) * 0.5; vec2 dn = (M.xy - mid);
  vec2 sideV = normalize(E.zw - E.xy);
  float rosy = max(spot(q, mid + dn * 0.75 - sideV * ed * 0.62, ed * 0.42), spot(q, mid + dn * 0.75 + sideV * ed * 0.62, ed * 0.42)) * T.z * 1.2;
  return mix(col, mix(col, vec3(1.0, 0.42, 0.5), 0.45), clamp(rosy, 0.0, 1.0));
}

vec3 mood(vec3 col, vec2 q) {
  float a = uAmount;
  if (uMood < 0.5) return col;
  if (uMood < 1.5) {
    vec2 px = vec2(1.0);
    float gx = luma(pick(q + vec2(px.x, 0.0)).rgb) - luma(pick(q - vec2(px.x, 0.0)).rgb);
    float gy = luma(pick(q + vec2(0.0, px.y)).rgb) - luma(pick(q - vec2(0.0, px.y)).rgb);
    float edge = smoothstep(0.08, 0.22, length(vec2(gx, gy)) * (1.0 + 0.6 * a));
    float lv = 9.0 - 3.0 * a;
    vec3 flat_ = floor(sat(soft(q, min(uSize.x, uSize.y) * 0.004), 1.25 + 0.4 * a) * lv) / (lv - 1.0);
    return mix(clamp(flat_, 0.0, 1.0), vec3(0.0), edge);
  }
  if (uMood < 2.5) {
    vec3 w = col * vec3(1.0 + 0.07 * (0.9 + 0.7 * a), 1.0 + 0.02 * (0.9 + 0.7 * a), 1.0 - 0.1 * (0.9 + 0.7 * a));
    w = sat(w, 1.12 + 0.18 * a);
    vec2 corner = vec2(uSize.x * 0.88, uSize.y - uSize.x * 0.12);
    float g = spot(q, corner, max(uSize.x, uSize.y) * 0.75) * (0.5 + 0.3 * a);
    return screen(w, vec3(1.0, 0.78, 0.35) * g);
  }
  if (uMood < 3.5) {
    vec3 w = sat(col, 1.4 + 0.5 * a);
    w = (w - 0.5) * (1.08 + 0.12 * a) + 0.5;
    float L = max(uSize.x, uSize.y) * 0.7;
    w = screen(w, vec3(1.0, 0.25, 0.7) * spot(q, vec2(0.0, uSize.y), L) * (0.3 + 0.25 * a));
    return screen(w, vec3(1.0, 0.8, 0.2) * spot(q, vec2(uSize.x, 0.0), L) * (0.3 + 0.25 * a));
  }
  return col * vec3(1.0 + 0.03 * a, 1.0 + 0.01 * a, 1.0 - 0.05 * a);
}

// Bald on the face engine (27 Nov rebuild): the hair beyond the skull replaced by the filled picture, then the scalp
// drawn over the skull in the head's own skin colour, lit as a round head. Only above the brow line.
vec3 baldNew(vec3 col, vec2 p, vec4 A, vec4 B, vec4 T) {
  if (T.w < 0.5) return col;
  vec2 c = A.xy; vec2 ax = max(A.zw, vec2(1.0)); vec2 up = B.zw; vec2 side = vec2(up.y, -up.x);
  float scale = max(ax.x, ax.y);
  float u = dot(p - c, side) / ax.x; float v = dot(p - c, up) / ax.y;
  float e = length(vec2(u, v));
  float gate = clamp((dot(p - B.xy, up) + 0.02 * scale) / (0.12 * scale), 0.0, 1.0);
  float hair = texture2D(uHair, down(p)).r; float face = texture2D(uSkinTex, down(p)).r;
  float beyond = clamp(hair * (1.0 - smoothstep(1.8, 1.95, e)) * gate - (1.0 - smoothstep(0.94, 1.0, e)), 0.0, 1.0);
  col = mix(col, texture2D(uFill, down(p)).rgb, smoothstep(0.06, 0.18, beyond));
  float z = sqrt(clamp(1.0 - u * u - v * v, 0.0, 1.0));
  vec3 n = vec3(u, v, z);
  vec3 L = normalize(vec3(-0.35, 0.55, 0.76));
  float lam = clamp(dot(n, L), 0.0, 1.0);
  float spec = pow(clamp(dot(n, normalize(L + vec3(0.0, 0.0, 1.0))), 0.0, 1.0), 30.0);
  vec3 scalp = clamp(T.rgb * (0.78 + 0.26 * lam - 0.1 * (1.0 - z)) + 0.07 * spec * T.rgb, 0.0, 1.0);
  float a = (1.0 - smoothstep(0.96, 1.0, e)) * gate * clamp(1.0 - face * 1.2, 0.0, 1.0) * clamp(max(hair * 1.5, gate), 0.0, 1.0);
  return mix(col, scalp, clamp(a * (0.6 + 0.6 * uAmount), 0.0, 1.0));
}

void main() {
  vec2 p = vTexSamplingCoord * uSize;
  vec2 q = p;
""")
            for (i in MAX_BENDS - 1 downTo 0) append("  q = bend(q, uA$i, uB$i);\n")
            append("""
  vec4 px = pick(q);
  vec3 col = px.rgb * baldShade;
  col = skin(col, q, uFaceC0, uFaceT0, uEyes0, uMouth0);
  col = skin(col, q, uFaceC1, uFaceT1, uEyes1, uMouth1);
  col = mood(col, q);
  if (uBald > 0.5 && uHasParts > 0.5) { col = baldNew(col, p, uSkA0, uSkB0, uSkT0); col = baldNew(col, p, uSkA1, uSkB1, uSkT1); }
  gl_FragColor = vec4(clamp(col, 0.0, 1.0), px.a);
}
""")
        }
    }

    private class Program(private val people: People, private val id: String, private val amount: Float, useHdr: Boolean) : BaseGlShaderProgram(useHdr, 1) {
        private val program: GlProgram = try {
            GlProgram(VERTEX, FRAGMENT).apply { setBufferAttribute("aFramePosition", GlUtil.getNormalizedCoordinateBounds(), GlUtil.HOMOGENEOUS_COORDINATE_VECTOR_SIZE) }
        } catch (e: GlUtil.GlException) { throw VideoFrameProcessingException(e) }
        private var width = 1; private var height = 1
        private var mask = 0; private var loaded = -1
        /** The face engine's hair, face-skin and filled-picture textures, and which look they hold. */
        private var hairTex = 0; private var skinTex = 0; private var fillTex = 0; private var partsLoaded = -1

        override fun configure(inputWidth: Int, inputHeight: Int): Size { width = inputWidth; height = inputHeight; return Size(inputWidth, inputHeight) }

        override fun drawFrame(inputTexId: Int, presentationTimeUs: Long) {
            try {
                val t = presentationTimeUs / 1e6
                if (mask == 0) {
                    val ids = IntArray(1); GLES20.glGenTextures(1, ids, 0); mask = ids[0]
                    upload(byteArrayOf(-1), 1, 1)
                }
                if (people.masks.isNotEmpty()) {
                    val (a, b, f) = people.around(t)
                    val i = (if (f < 0.5f) a else b).coerceAtMost(people.masks.size - 1)
                    if (loaded != i) { upload(people.masks[i], people.maskW, people.maskH); loaded = i }
                }
                if (hairTex == 0) {
                    val ids = IntArray(3); GLES20.glGenTextures(3, ids, 0); hairTex = ids[0]; skinTex = ids[1]; fillTex = ids[2]
                    upload(byteArrayOf(0), 1, 1, hairTex); upload(byteArrayOf(0), 1, 1, skinTex); uploadRgb(intArrayOf(0), 1, 1)
                }
                var skulls = FloatArray(24)
                val hasParts = people.parts.isNotEmpty()
                if (hasParts) {
                    val (a, b, f) = people.around(t)
                    val i = (if (f < 0.5f) a else b).coerceAtMost(people.parts.size - 1)
                    val pt = people.parts[i]
                    if (partsLoaded != i) {
                        upload(pt.hair, FaceEngine.SIDE, FaceEngine.SIDE, hairTex); upload(pt.skin, FaceEngine.SIDE, FaceEngine.SIDE, skinTex)
                        pt.fill?.let { uploadRgb(it, FaceEngine.SIDE, FaceEngine.SIDE) }
                        partsLoaded = i
                    }
                    skulls = skullUniforms(pt.skulls, pt.w, pt.h, width, height)
                }
                val u = frameUniforms(id, people.facesAt(t), width, height, t.toFloat(), amount, hasParts)
                program.use()
                program.setSamplerTexIdUniform("uHair", hairTex, 2)
                program.setSamplerTexIdUniform("uSkinTex", skinTex, 3)
                program.setSamplerTexIdUniform("uFill", fillTex, 4)
                program.setFloatUniform("uHasParts", if (hasParts) 1f else 0f)
                program.setFloatUniform("uBald", if (id == "bald") 1f else 0f)
                for (j in 0 until 2) {
                    program.setFloatsUniform("uSkA$j", skulls.copyOfRange(j * 12, j * 12 + 4))
                    program.setFloatsUniform("uSkB$j", skulls.copyOfRange(j * 12 + 4, j * 12 + 8))
                    program.setFloatsUniform("uSkT$j", skulls.copyOfRange(j * 12 + 8, j * 12 + 12))
                }
                program.setSamplerTexIdUniform("uTexSampler", inputTexId, 0)
                program.setSamplerTexIdUniform("uMask", mask, 1)
                program.setFloatUniform("uHasMask", if (people.masks.isEmpty()) 0f else 1f)
                program.setFloatsUniform("uSize", floatArrayOf(width.toFloat(), height.toFloat()))
                program.setFloatUniform("uTime", t.toFloat())
                program.setFloatUniform("uAmount", amount)
                program.setFloatUniform("uMood", u.mood)
                for (j in 0 until 2) {
                    program.setFloatsUniform("uFaceC$j", u.faceC.copyOfRange(j * 4, j * 4 + 4))
                    program.setFloatsUniform("uFaceT$j", u.faceT.copyOfRange(j * 4, j * 4 + 4))
                    program.setFloatsUniform("uEyes$j", u.eyes.copyOfRange(j * 4, j * 4 + 4))
                    program.setFloatsUniform("uMouth$j", u.mouth.copyOfRange(j * 4, j * 4 + 4))
                }
                for (j in 0 until MAX_BENDS) {
                    program.setFloatsUniform("uA$j", u.bendA.copyOfRange(j * 4, j * 4 + 4))
                    program.setFloatsUniform("uB$j", u.bendB.copyOfRange(j * 4, j * 4 + 4))
                }
                program.bindAttributesAndUniforms()
                GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
                GlUtil.checkGlError()
            } catch (e: GlUtil.GlException) {
                throw VideoFrameProcessingException(e, presentationTimeUs)
            }
        }

        private fun uploadRgb(argb: IntArray, w: Int, h: Int) {
            val bytes = ByteArray(w * h * 4)
            for (i in argb.indices) {
                val c = argb[i]
                bytes[i * 4] = ((c shr 16) and 255).toByte(); bytes[i * 4 + 1] = ((c shr 8) and 255).toByte(); bytes[i * 4 + 2] = (c and 255).toByte(); bytes[i * 4 + 3] = -1
            }
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, fillTex)
            GLES20.glPixelStorei(GLES20.GL_UNPACK_ALIGNMENT, 1)
            GLES20.glTexImage2D(GLES20.GL_TEXTURE_2D, 0, GLES20.GL_RGBA, w, h, 0, GLES20.GL_RGBA, GLES20.GL_UNSIGNED_BYTE, ByteBuffer.wrap(bytes))
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        }

        private fun upload(bytes: ByteArray, w: Int, h: Int, tex: Int = mask) {
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, tex)
            GLES20.glPixelStorei(GLES20.GL_UNPACK_ALIGNMENT, 1)
            GLES20.glTexImage2D(GLES20.GL_TEXTURE_2D, 0, GLES20.GL_LUMINANCE, w, h, 0, GLES20.GL_LUMINANCE, GLES20.GL_UNSIGNED_BYTE, ByteBuffer.wrap(bytes))
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        }

        override fun release() {
            super.release()
            try { program.delete(); if (mask != 0) GLES20.glDeleteTextures(1, intArrayOf(mask), 0); if (hairTex != 0) GLES20.glDeleteTextures(3, intArrayOf(hairTex, skinTex, fillTex), 0) } catch (e: GlUtil.GlException) { throw VideoFrameProcessingException(e) }
        }
    }
}

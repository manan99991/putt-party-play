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
 * Behind the person and funny faces, on the GPU (the iPhone's Core Image recipe as one shader): the person mask from
 * [People] keeps the person and swaps what's behind them (portrait blur, colour pop, studio, sunset, night city,
 * pastel), and each face found bulges, shrinks, grows its eyes, stretches or wobbles. Goes right after the picture is
 * sized, on the clean frame, before the look and motion — the iPhone's order.
 */
@androidx.annotation.OptIn(UnstableApi::class)
class PeopleEffect(private val people: People, private val background: String, private val funny: String, private val amount: Float = 0.6f) : GlEffect {
    override fun toGlShaderProgram(context: Context, useHdr: Boolean): GlShaderProgram = Program(people, background, funny, amount, useHdr)

    companion object {
        val backgroundCodes = mapOf("none" to 0f, "blur" to 1f, "colorpop" to 2f, "studio" to 3f, "sunset" to 4f, "night" to 5f, "pastel" to 6f)
        val funnyCodes = mapOf("none" to 0f, "bighead" to 1f, "tinyhead" to 2f, "bigeyes" to 3f, "stretchy" to 4f, "wobbly" to 5f)

        /**
         * One face as the shader wants it: centre (0…1, y up, nudged up a little toward the forehead like the iPhone),
         * size as a fraction of the width, and on; with its two eyes (0…1, y up — far off the frame when not found).
         */
        fun uniforms(f: FaceSpot?, width: Int, height: Int): Pair<FloatArray, FloatArray> {
            if (f == null) return floatArrayOf(0f, 0f, 0f, 0f) to floatArrayOf(-9f, -9f, -9f, -9f)
            val up = 0.08f * f.size * width / height
            val face = floatArrayOf(f.x, 1f - (f.y - up), f.size, 1f)
            val e = f.eyes
            val eyes = if (e.size >= 2) floatArrayOf(e[0].x, 1f - e[0].y, e[1].x, 1f - e[1].y)
                       else if (e.size == 1) floatArrayOf(e[0].x, 1f - e[0].y, -9f, -9f) else floatArrayOf(-9f, -9f, -9f, -9f)
            return face to eyes
        }

        private const val VERTEX = """
attribute vec4 aFramePosition;
varying vec2 vTexSamplingCoord;
void main() {
  gl_Position = aFramePosition;
  vTexSamplingCoord = vec2(aFramePosition.x * 0.5 + 0.5, aFramePosition.y * 0.5 + 0.5);
}
"""

        // Pixel space, y up (GL). Mask rows start at the top of the picture, so it's read at 1 - y.
        private const val FRAGMENT = """
precision highp float;
uniform sampler2D uTexSampler;
uniform sampler2D uMaskA;
uniform sampler2D uMaskB;
uniform float uMaskMix;
uniform float uBackground;
uniform float uFunny;
uniform vec2 uSize;
uniform float uTime;
uniform float uAmount;
uniform vec4 uFace0;
uniform vec4 uFace1;
uniform vec4 uEyes0;
uniform vec4 uEyes1;
varying vec2 vTexSamplingCoord;

vec4 pick(vec2 px) { return texture2D(uTexSampler, clamp(px / uSize, 0.0, 1.0)); }

vec2 bump(vec2 p, vec2 c, float r, float s) {
  vec2 d = p - c;
  float t = length(d) / max(r, 1.0);
  if (t >= 1.0) return p;
  float w = (1.0 - t * t) * (1.0 - t * t);
  return c + d * (1.0 - s * w);
}

vec2 warp(vec2 p, vec4 f, vec4 e) {
  if (f.w < 0.5) return p;
  vec2 c = f.xy * uSize;
  float big = f.z * uSize.x;
  float a = uAmount;
  if (uFunny < 1.5) return bump(p, c, big * 1.05, (0.45 + 0.45 * a) * 0.7);
  if (uFunny < 2.5) return bump(p, c, big, -(0.35 + 0.4 * a));
  if (uFunny < 3.5) {
    vec2 q = bump(p, e.xy * uSize, big * 0.24, (0.55 + 0.4 * a) * 0.75);
    return bump(q, e.zw * uSize, big * 0.24, (0.55 + 0.4 * a) * 0.75);
  }
  vec2 d = p - c;
  if (uFunny < 4.5) {
    float t = length(d) / max(big * 0.95, 1.0);
    if (t >= 1.0) return p;
    float s = (0.5 + 0.4 * a + 0.1 * sin(uTime * 3.0)) * 0.7;
    float w = (1.0 - t * t) * (1.0 - t * t);
    return vec2(p.x, c.y + d.y * (1.0 - s * w));
  }
  float t = length(d) / max(big * 0.9, 1.0);
  if (t >= 1.0) return p;
  float ang = (0.35 + 0.7 * a) * sin(uTime * 5.0) * (1.0 - t) * (1.0 - t) * 1.6;
  float cs = cos(ang);
  float sn = sin(ang);
  return c + vec2(d.x * cs - d.y * sn, d.x * sn + d.y * cs);
}

vec3 grad(vec2 px, vec3 top, vec3 bottom) {
  vec2 p0 = vec2(0.3, 1.0) * uSize;
  vec2 p1 = vec2(0.7, 0.0) * uSize;
  vec2 d = p1 - p0;
  float k = clamp(dot(px - p0, d) / dot(d, d), 0.0, 1.0);
  return mix(top, bottom, k);
}

vec3 glowColor(float i) {
  float m = mod(i, 4.0);
  if (m < 0.5) return vec3(1.0, 0.75, 0.3);
  if (m < 1.5) return vec3(0.4, 0.7, 1.0);
  if (m < 2.5) return vec3(1.0, 0.4, 0.7);
  return vec3(0.6, 1.0, 0.8);
}

vec3 backdrop(vec2 px) {
  float side = min(uSize.x, uSize.y);
  if (uBackground < 1.5) {
    float r = side * (0.012 + 0.03 * uAmount);
    vec3 acc = vec3(0.0);
    for (int i = 0; i < 24; i++) {
      float fi = float(i);
      float rr = r * sqrt((fi + 0.5) / 24.0);
      float th = fi * 2.39996;
      acc += pick(px + vec2(cos(th), sin(th)) * rr).rgb;
    }
    return acc / 24.0;
  }
  if (uBackground < 2.5) {
    vec3 c = pick(px).rgb;
    return vec3(dot(c, vec3(0.2126, 0.7152, 0.0722)));
  }
  if (uBackground < 3.5) return grad(px, vec3(0.97, 0.97, 0.98), vec3(0.80, 0.81, 0.84));
  if (uBackground < 4.5) return grad(px, vec3(0.99, 0.55, 0.35), vec3(0.45, 0.20, 0.55));
  if (uBackground < 5.5) {
    vec3 bg = grad(px, vec3(0.05, 0.06, 0.20), vec3(0.22, 0.08, 0.32));
    for (int i = 0; i < 7; i++) {
      float fi = float(i);
      vec2 c = vec2(uSize.x * fract(fi * 0.153 + 0.04 * sin(uTime * 0.3 + fi)), uSize.y * (0.12 + 0.55 * mod(fi * 37.0, 10.0) / 10.0));
      float g = 0.55 * (1.0 - smoothstep(0.0, side * 0.16, length(px - c)));
      bg = 1.0 - (1.0 - bg) * (1.0 - glowColor(fi) * g);
    }
    return bg;
  }
  return grad(px, vec3(1.0, 0.80, 0.88), vec3(0.70, 0.86, 1.0));
}

void main() {
  vec2 p = vTexSamplingCoord * uSize;
  vec2 q = p;
  if (uFunny > 0.5) {
    q = warp(q, uFace0, uEyes0);
    q = warp(q, uFace1, uEyes1);
  }
  vec4 person = pick(q);
  vec3 col = person.rgb;
  if (uBackground > 0.5) {
    vec2 mv = vec2(q.x / uSize.x, 1.0 - q.y / uSize.y);
    float m = mix(texture2D(uMaskA, mv).r, texture2D(uMaskB, mv).r, uMaskMix);
    m = smoothstep(0.3, 0.7, m);
    col = mix(backdrop(q), person.rgb, m);
  }
  gl_FragColor = vec4(col, person.a);
}
"""
    }

    private class Program(private val people: People, background: String, funny: String, private val amount: Float, useHdr: Boolean) :
        BaseGlShaderProgram(useHdr, 1) {
        private val bg = backgroundCodes[background] ?: 0f
        private val fun0 = funnyCodes[funny] ?: 0f
        private val program: GlProgram = try {
            GlProgram(VERTEX, FRAGMENT).apply {
                setBufferAttribute("aFramePosition", GlUtil.getNormalizedCoordinateBounds(), GlUtil.HOMOGENEOUS_COORDINATE_VECTOR_SIZE)
            }
        } catch (e: GlUtil.GlException) { throw VideoFrameProcessingException(e) }
        private var width = 1; private var height = 1
        private var texA = 0; private var texB = 0
        private var loadedA = -1; private var loadedB = -1

        override fun configure(inputWidth: Int, inputHeight: Int): Size { width = inputWidth; height = inputHeight; return Size(inputWidth, inputHeight) }

        private fun upload(tex: Int, bytes: ByteArray, w: Int, h: Int) {
            GLES20.glBindTexture(GLES20.GL_TEXTURE_2D, tex)
            GLES20.glPixelStorei(GLES20.GL_UNPACK_ALIGNMENT, 1)
            GLES20.glTexImage2D(GLES20.GL_TEXTURE_2D, 0, GLES20.GL_LUMINANCE, w, h, 0, GLES20.GL_LUMINANCE, GLES20.GL_UNSIGNED_BYTE, ByteBuffer.wrap(bytes))
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MIN_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_MAG_FILTER, GLES20.GL_LINEAR)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_S, GLES20.GL_CLAMP_TO_EDGE)
            GLES20.glTexParameteri(GLES20.GL_TEXTURE_2D, GLES20.GL_TEXTURE_WRAP_T, GLES20.GL_CLAMP_TO_EDGE)
        }

        override fun drawFrame(inputTexId: Int, presentationTimeUs: Long) {
            try {
                val t = presentationTimeUs / 1e6
                if (texA == 0) {
                    val ids = IntArray(2); GLES20.glGenTextures(2, ids, 0); texA = ids[0]; texB = ids[1]
                    // Until a mask is loaded (or when there are none) the whole frame counts as person.
                    val full = byteArrayOf(-1)
                    upload(texA, full, 1, 1); upload(texB, full, 1, 1)
                }
                val (a, b, f) = people.around(t)
                if (people.masks.isNotEmpty()) {
                    val ia = a.coerceAtMost(people.masks.size - 1); val ib = b.coerceAtMost(people.masks.size - 1)
                    if (loadedA != ia) { upload(texA, people.masks[ia], people.maskW, people.maskH); loadedA = ia }
                    if (loadedB != ib) { upload(texB, people.masks[ib], people.maskW, people.maskH); loadedB = ib }
                }
                val faces = people.facesAt(t)
                val (f0, e0) = uniforms(faces.getOrNull(0), width, height)
                val (f1, e1) = uniforms(faces.getOrNull(1), width, height)
                program.use()
                program.setSamplerTexIdUniform("uTexSampler", inputTexId, 0)
                program.setSamplerTexIdUniform("uMaskA", texA, 1)
                program.setSamplerTexIdUniform("uMaskB", texB, 2)
                program.setFloatUniform("uMaskMix", if (people.masks.isEmpty()) 0f else f)
                program.setFloatUniform("uBackground", bg)
                program.setFloatUniform("uFunny", fun0)
                program.setFloatsUniform("uSize", floatArrayOf(width.toFloat(), height.toFloat()))
                program.setFloatUniform("uTime", t.toFloat())
                program.setFloatUniform("uAmount", amount)
                program.setFloatsUniform("uFace0", f0); program.setFloatsUniform("uEyes0", e0)
                program.setFloatsUniform("uFace1", f1); program.setFloatsUniform("uEyes1", e1)
                program.bindAttributesAndUniforms()
                GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
                GlUtil.checkGlError()
            } catch (e: GlUtil.GlException) {
                throw VideoFrameProcessingException(e, presentationTimeUs)
            }
        }

        override fun release() {
            super.release()
            try {
                program.delete()
                if (texA != 0) GLES20.glDeleteTextures(2, intArrayOf(texA, texB), 0)
            } catch (e: GlUtil.GlException) { throw VideoFrameProcessingException(e) }
        }
    }
}

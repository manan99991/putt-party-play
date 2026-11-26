package com.handytools.app.tools.autoruns

import android.content.ContentUris
import android.content.ContentValues
import android.content.Context
import android.net.Uri
import android.opengl.GLES20
import android.os.Build
import android.os.Environment
import android.provider.MediaStore
import androidx.media3.common.Effect
import androidx.media3.common.MediaItem
import androidx.media3.common.VideoFrameProcessingException
import androidx.media3.common.util.GlProgram
import androidx.media3.common.util.GlUtil
import androidx.media3.common.util.Size
import androidx.media3.common.util.UnstableApi
import androidx.media3.effect.BaseGlShaderProgram
import androidx.media3.effect.GlEffect
import androidx.media3.effect.GlShaderProgram
import androidx.media3.transformer.Composition
import androidx.media3.transformer.EditedMediaItem
import androidx.media3.transformer.EditedMediaItemSequence
import androidx.media3.transformer.Effects
import com.handytools.app.tools.studio.Reels
import com.handytools.app.tools.studio.VideoEffects
import java.io.File

/**
 * Get today's best videos ready to post (the iPhone's autorun): today's real clips (4 s to 3 min), newest first, each
 * given the person's look and the tall size Reels, TikTok and Shorts want — the whole picture kept, with a soft,
 * blurred fill of itself above and below instead of black bars — ready to watch, then save or post.
 */
@androidx.annotation.OptIn(UnstableApi::class)
object ReadyToPost {
    const val W = 1080
    const val H = 1920
    /** The look each clip gets (the iPhone's default for this autorun). */
    const val LOOK = "vivid"

    data class Clip(val uri: Uri, val name: String, val seconds: Double, val created: Long)

    /** Today's clips worth making ready, newest first (at most three). */
    fun find(ctx: Context, window: LongRange, limit: Int = 3): List<Clip> = runCatching {
        val cols = arrayOf(MediaStore.Video.Media._ID, MediaStore.Video.Media.DISPLAY_NAME, MediaStore.Video.Media.DURATION,
            MediaStore.Video.Media.WIDTH, MediaStore.Video.Media.HEIGHT, MediaStore.Video.Media.DATE_ADDED, MediaStore.Video.Media.SIZE)
        val all = ArrayList<Pair<Clip, SmartRuns.Found>>()
        ctx.contentResolver.query(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, cols,
            "${MediaStore.Video.Media.DATE_ADDED} >= ? AND ${MediaStore.Video.Media.DATE_ADDED} <= ?",
            arrayOf((window.first / 1000).toString(), (window.last / 1000 + 1).toString()), null)?.use { c ->
            while (c.moveToNext()) {
                val uri = ContentUris.withAppendedId(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, c.getLong(0))
                val clip = Clip(uri, c.getString(1) ?: "Video", c.getLong(2) / 1000.0, c.getLong(5) * 1000)
                all += clip to SmartRuns.Found(uri.toString(), clip.created, isVideo = true, bytes = c.getLong(6), seconds = clip.seconds, width = c.getInt(3), height = c.getInt(4))
            }
        }
        SmartRuns.postPicks(all.map { it.second }, limit).mapNotNull { f -> all.firstOrNull { it.second.id == f.id }?.first }
    }.getOrDefault(emptyList())

    /** One clip made ready: tall, the whole picture with a blurred fill of itself, the look on top, the sound kept. */
    suspend fun make(ctx: Context, uri: Uri, look: String = LOOK, progress: (Double) -> Unit = {}): File? {
        val video = mutableListOf<Effect>(TallFrame()) + VideoEffects.look(look)
        val edited = EditedMediaItem.Builder(MediaItem.fromUri(uri)).setEffects(Effects(emptyList(), video)).build()
        val out = File(File(ctx.cacheDir, "autoruns").also { it.mkdirs() }, "ready-${System.nanoTime()}.mp4")
        val ok = Reels.export(ctx, Composition.Builder(listOf(EditedMediaItemSequence(listOf(edited)))).build(), out, progress)
        return if (ok && out.length() > 0) out else { out.delete(); null }
    }

    /** Saves a made video into the phone's videos (Movies/Tenzy) with [taken] as its date. Its uri. */
    fun saveVideo(ctx: Context, file: File, name: String, taken: Long): Uri? = runCatching {
        val v = ContentValues().apply {
            put(MediaStore.Video.Media.DISPLAY_NAME, name)
            put(MediaStore.Video.Media.MIME_TYPE, "video/mp4")
            put(MediaStore.Video.Media.DATE_TAKEN, taken)
            if (Build.VERSION.SDK_INT >= 29) { put(MediaStore.Video.Media.RELATIVE_PATH, Environment.DIRECTORY_MOVIES + "/Tenzy"); put(MediaStore.Video.Media.IS_PENDING, 1) }
        }
        val r = ctx.contentResolver
        val uri = r.insert(MediaStore.Video.Media.EXTERNAL_CONTENT_URI, v) ?: return null
        r.openOutputStream(uri)?.use { o -> file.inputStream().use { it.copyTo(o) } } ?: return null
        if (Build.VERSION.SDK_INT >= 29) r.update(uri, ContentValues().apply { put(MediaStore.Video.Media.IS_PENDING, 0) }, null, null)
        uri
    }.getOrNull()

    /** The tall frame: the clip fitted whole in 1080×1920, the space around it filled with a blurred, darker copy of itself. */
    class TallFrame : GlEffect {
        override fun toGlShaderProgram(context: Context, useHdr: Boolean): GlShaderProgram = Program(useHdr)

        private class Program(useHdr: Boolean) : BaseGlShaderProgram(useHdr, 1) {
            private val program: GlProgram = try {
                GlProgram(VERTEX, FRAGMENT).apply {
                    setBufferAttribute("aFramePosition", GlUtil.getNormalizedCoordinateBounds(), GlUtil.HOMOGENEOUS_COORDINATE_VECTOR_SIZE)
                }
            } catch (e: GlUtil.GlException) { throw VideoFrameProcessingException(e) }
            private var inW = 1; private var inH = 1

            override fun configure(inputWidth: Int, inputHeight: Int): Size { inW = inputWidth; inH = inputHeight; return Size(W, H) }

            override fun drawFrame(inputTexId: Int, presentationTimeUs: Long) {
                try {
                    program.use()
                    program.setSamplerTexIdUniform("uTexSampler", inputTexId, 0)
                    program.setFloatsUniform("uIn", floatArrayOf(inW.toFloat(), inH.toFloat()))
                    program.setFloatsUniform("uOut", floatArrayOf(W.toFloat(), H.toFloat()))
                    program.bindAttributesAndUniforms()
                    GLES20.glDrawArrays(GLES20.GL_TRIANGLE_STRIP, 0, 4)
                    GlUtil.checkGlError()
                } catch (e: GlUtil.GlException) { throw VideoFrameProcessingException(e, presentationTimeUs) }
            }

            override fun release() {
                super.release()
                try { program.delete() } catch (e: GlUtil.GlException) { throw VideoFrameProcessingException(e) }
            }
        }

        private companion object {
            const val VERTEX = """
attribute vec4 aFramePosition;
varying vec2 vTexSamplingCoord;
void main() {
  gl_Position = aFramePosition;
  vTexSamplingCoord = vec2(aFramePosition.x * 0.5 + 0.5, aFramePosition.y * 0.5 + 0.5);
}
"""
            const val FRAGMENT = """
precision highp float;
uniform sampler2D uTexSampler;
uniform vec2 uIn;
uniform vec2 uOut;
varying vec2 vTexSamplingCoord;
vec4 pick(vec2 uv) { return texture2D(uTexSampler, clamp(uv, 0.0, 1.0)); }
void main() {
  vec2 p = vTexSamplingCoord * uOut;
  float fit = min(uOut.x / uIn.x, uOut.y / uIn.y);
  vec2 size = uIn * fit;
  vec2 org = (uOut - size) * 0.5;
  vec2 q = (p - org) / size;
  if (q.x >= 0.0 && q.x <= 1.0 && q.y >= 0.0 && q.y <= 1.0) { gl_FragColor = pick(q); return; }
  float fill = max(uOut.x / uIn.x, uOut.y / uIn.y);
  vec2 fsize = uIn * fill;
  vec2 forg = (uOut - fsize) * 0.5;
  vec2 f = (p - forg) / fsize;
  vec3 acc = vec3(0.0);
  for (int i = 0; i < 24; i++) {
    float fi = float(i);
    float rr = 0.045 * sqrt((fi + 0.5) / 24.0);
    float th = fi * 2.39996;
    acc += pick(f + vec2(cos(th), sin(th) * uIn.x / uIn.y) * rr).rgb;
  }
  gl_FragColor = vec4(acc / 24.0 * 0.8, 1.0);
}
"""
        }
    }
}

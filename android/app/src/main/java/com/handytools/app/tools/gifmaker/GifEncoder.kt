package com.handytools.app.tools.gifmaker

import android.graphics.Bitmap
import java.io.ByteArrayOutputStream

/**
 * Minimal, dependency-free animated GIF89a encoder: fixed 216-colour web-safe palette plus standard
 * variable-width LZW. The byte layout and LZW bit-width logic were validated against a reference
 * decoder (exact pixel round-trip) before porting here. Runs entirely on-device.
 */
object GifEncoder {
    private val LEVELS = intArrayOf(0, 51, 102, 153, 204, 255)
    private fun qLevel(v: Int): Int {
        var bi = 0; var bd = 1000
        for (i in 0..5) { val d = kotlin.math.abs(LEVELS[i] - v); if (d < bd) { bd = d; bi = i } }
        return bi
    }
    private fun paletteIndex(r: Int, g: Int, b: Int) = qLevel(r) * 36 + qLevel(g) * 6 + qLevel(b)

    private fun writeShort(o: ByteArrayOutputStream, v: Int) { o.write(v and 0xff); o.write((v ushr 8) and 0xff) }

    /** @param delayCs frame delay in centiseconds (1/100 s). */
    fun encode(frames: List<Bitmap>, delayCs: Int): ByteArray {
        val o = ByteArrayOutputStream()
        val w = frames[0].width; val h = frames[0].height
        o.write("GIF89a".toByteArray(Charsets.US_ASCII))
        writeShort(o, w); writeShort(o, h)
        o.write(0b11110111); o.write(0); o.write(0) // global table, 256 entries
        for (r in LEVELS) for (g in LEVELS) for (b in LEVELS) { o.write(r); o.write(g); o.write(b) }
        repeat(256 - 216) { o.write(0); o.write(0); o.write(0) }
        // Netscape looping extension (loop forever)
        o.write(byteArrayOf(0x21, 0xFF.toByte(), 0x0B))
        o.write("NETSCAPE2.0".toByteArray(Charsets.US_ASCII))
        o.write(byteArrayOf(0x03, 0x01, 0x00, 0x00, 0x00))

        for (f in frames) {
            o.write(byteArrayOf(0x21, 0xF9.toByte(), 0x04, 0x00)); writeShort(o, delayCs); o.write(0x00); o.write(0x00) // GCE
            o.write(0x2C); writeShort(o, 0); writeShort(o, 0); writeShort(o, w); writeShort(o, h); o.write(0x00) // image descriptor
            val px = IntArray(w * h)
            f.getPixels(px, 0, w, 0, 0, w, h)
            val indices = ByteArray(w * h)
            for (i in px.indices) {
                val c = px[i]
                indices[i] = paletteIndex((c ushr 16) and 0xff, (c ushr 8) and 0xff, c and 0xff).toByte()
            }
            o.write(8) // LZW minimum code size for a 256-colour table
            val data = lzw(indices, 8)
            var i = 0
            while (i < data.size) { val n = minOf(255, data.size - i); o.write(n); o.write(data, i, n); i += n }
            o.write(0x00) // block terminator
        }
        o.write(0x3B) // trailer
        return o.toByteArray()
    }

    private fun lzw(data: ByteArray, minCodeSize: Int): ByteArray {
        val clear = 1 shl minCodeSize
        val end = clear + 1
        val o = ByteArrayOutputStream()
        var buf = 0L; var nbits = 0
        var codeSize = minCodeSize + 1
        val dict = HashMap<String, Int>()
        var next = 0
        fun reset() {
            dict.clear()
            for (i in 0 until clear) dict[i.toChar().toString()] = i
            codeSize = minCodeSize + 1
            next = end + 1
        }
        fun emit(code: Int) {
            buf = buf or (code.toLong() shl nbits); nbits += codeSize
            while (nbits >= 8) { o.write((buf and 0xff).toInt()); buf = buf shr 8; nbits -= 8 }
        }
        reset()
        emit(clear)
        var cur = ""
        for (bb in data) {
            val ch = (bb.toInt() and 0xff).toChar()
            val nk = cur + ch
            if (dict.containsKey(nk)) cur = nk
            else {
                emit(dict[cur]!!)
                dict[nk] = next; next++
                if (next > (1 shl codeSize) && codeSize < 12) codeSize++
                else if (next > 4095) { emit(clear); reset() }
                cur = ch.toString()
            }
        }
        emit(dict[cur]!!); emit(end)
        if (nbits > 0) o.write((buf and 0xff).toInt())
        return o.toByteArray()
    }
}

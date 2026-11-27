package com.handytools.app.tools.studio

import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.LinearGradient
import android.graphics.Matrix
import android.graphics.Paint
import android.graphics.Path
import android.graphics.PorterDuff
import android.graphics.RadialGradient
import android.graphics.RectF
import android.graphics.Shader
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.pow
import kotlin.math.sin

/**
 * The things Face fun puts on a face (the iPhone's FaceStickers, drawn the same way): shades, a crown, a moustache,
 * puppy ears… Every one is drawn here by Tenzy from plain shapes — no emoji, no artwork from anywhere else — once, then
 * placed on each face every frame, sized to the face and turned with it. The shapes are written y-up like the
 * iPhone's, so the two stay the same; the canvas is flipped to match.
 */
object FaceStickers {
    class Sprite(val bitmap: Bitmap, val anchorX: Float, val anchorY: Float)

    private val cache = HashMap<String, Sprite?>()

    @Synchronized fun sprite(id: String): Sprite? = cache.getOrPut(id) { make(id) }

    /** Draws the placed stickers onto [c] (the frame's pixels, y down). */
    fun draw(c: Canvas, placed: List<FaceFun.Placed>) {
        val p = Paint(Paint.FILTER_BITMAP_FLAG or Paint.ANTI_ALIAS_FLAG)
        for (s in placed) {
            val sp = sprite(s.sprite) ?: continue
            if (s.width < 1f || s.alpha <= 0.01f) continue
            val k = s.width / sp.bitmap.width
            val m = Matrix().apply {
                postTranslate(-sp.anchorX, -sp.anchorY); postScale(k, k)
                postRotate((s.angle * 180 / PI).toFloat()); postTranslate(s.at.x, s.at.y)
            }
            p.alpha = (s.alpha.coerceIn(0f, 1f) * 255).toInt()
            c.drawBitmap(sp.bitmap, m, p)
        }
    }

    // ---- drawing (y up, like the iPhone's) ----

    private fun rgb(hex: Long, a: Float = 1f): Int = Color.argb((a * 255).toInt(), ((hex shr 16) and 0xFF).toInt(), ((hex shr 8) and 0xFF).toInt(), (hex and 0xFF).toInt())

    private fun canvas(w: Int, h: Int, ax: Float, ay: Float, body: (Canvas) -> Unit): Sprite {
        val b = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(b)
        c.translate(0f, h.toFloat()); c.scale(1f, -1f)
        body(c)
        return Sprite(b, ax, h - ay)
    }

    private fun fill(c: Canvas, path: Path, top: Long, bottom: Long) {
        val r = RectF(); path.computeBounds(r, true)
        val p = Paint(Paint.ANTI_ALIAS_FLAG)
        p.shader = LinearGradient(r.centerX(), r.bottom, r.centerX(), r.top, rgb(top), rgb(bottom), Shader.TileMode.CLAMP)
        c.drawPath(path, p)
    }

    private fun stroke(c: Canvas, path: Path, hex: Long, w: Float, alpha: Float = 1f) {
        val p = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = w; color = rgb(hex, alpha); strokeJoin = Paint.Join.ROUND; strokeCap = Paint.Cap.ROUND }
        c.drawPath(path, p)
    }

    private fun solid(c: Canvas, path: Path, hex: Long, alpha: Float = 1f) {
        c.drawPath(path, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = rgb(hex, alpha) })
    }

    private fun oval(cx: Float, cy: Float, rx: Float, ry: Float, turn: Float = 0f): Path {
        val p = Path(); p.addOval(RectF(cx - rx, cy - ry, cx + rx, cy + ry), Path.Direction.CW)
        if (turn != 0f) p.transform(Matrix().apply { postRotate((turn * 180 / PI).toFloat(), cx, cy) })
        return p
    }

    private fun ball(c: Canvas, cx: Float, cy: Float, r: Float, light: Long, dark: Long) {
        val p = Paint(Paint.ANTI_ALIAS_FLAG)
        p.shader = RadialGradient(cx - r * 0.3f, cy + r * 0.3f, r * 1.25f, rgb(light), rgb(dark), Shader.TileMode.CLAMP)
        c.drawCircle(cx, cy, r, p)
        solid(c, oval(cx - r * 0.31f, cy + r * 0.41f, r * 0.21f, r * 0.13f), 0xFFFFFF, 0.75f)
    }

    fun heart(cx: Float, cy: Float, size: Float): Path {
        val w = size / 2
        val p = Path()
        p.moveTo(cx, cy - w * 0.92f)
        p.cubicTo(cx - w * 0.55f, cy - w * 0.45f, cx - w, cy - w * 0.15f, cx - w, cy + w * 0.3f)
        p.arcTo(RectF(cx - w, cy + w * 0.3f - w * 0.5f, cx, cy + w * 0.3f + w * 0.5f), 180f, -180f)
        p.arcTo(RectF(cx, cy + w * 0.3f - w * 0.5f, cx + w, cy + w * 0.3f + w * 0.5f), 180f, -180f)
        p.cubicTo(cx + w, cy - w * 0.15f, cx + w * 0.55f, cy - w * 0.45f, cx, cy - w * 0.92f)
        p.close()
        return p
    }

    fun star(cx: Float, cy: Float, outer: Float, inner: Float, points: Int): Path {
        val p = Path()
        for (i in 0 until points * 2) {
            val r = if (i % 2 == 0) outer else inner
            val a = i * PI / points + PI / 2
            val x = cx + (cos(a) * r).toFloat(); val y = cy + (sin(a) * r).toFloat()
            if (i == 0) p.moveTo(x, y) else p.lineTo(x, y)
        }
        p.close(); return p
    }

    private fun line(vararg pts: Float): Path = Path().apply { moveTo(pts[0], pts[1]); var i = 2; while (i < pts.size) { lineTo(pts[i], pts[i + 1]); i += 2 } }

    private fun glasses(c: Canvas, lens: (Float) -> Path, top: Long, bottom: Long, rim: Long, rimW: Float) {
        stroke(c, Path().apply { moveTo(262f, 138f); quadTo(300f, 172f, 338f, 138f) }, rim, rimW + 2)
        stroke(c, line(34f, 150f, 2f, 162f), rim, rimW); stroke(c, line(566f, 150f, 598f, 162f), rim, rimW)
        for (cx in listOf(145f, 455f)) {
            val p = lens(cx)
            fill(c, p, top, bottom)
            c.save(); c.clipPath(p)
            solid(c, line(cx - 80, 40f, cx - 30, 40f, cx + 60, 200f, cx + 10, 200f).apply { close() }, 0xFFFFFF, 0.22f)
            c.restore()
            stroke(c, p, rim, rimW)
        }
    }

    private fun make(id: String): Sprite? = when (id) {
        "shades", "bling" -> { val gold = id == "bling"
            canvas(600, 230, 300f, 115f) { c ->
                glasses(c, { cx -> Path().apply { addRoundRect(RectF(cx - 122, 28f, cx + 122, 200f), 62f, 62f, Path.Direction.CW) } },
                    if (gold) 0x7A4B00 else 0x3B3B46, if (gold) 0x2A1800 else 0x09090D, if (gold) 0xFFC93C else 0x0A0A0A, if (gold) 18f else 13f)
                if (gold) for (x in listOf(40f, 560f)) solid(c, star(x, 196f, 30f, 9f, 4), 0xFFFFFF)
            } }
        "heartglasses" -> canvas(600, 250, 300f, 118f) { c -> glasses(c, { cx -> heart(cx, 122f, 236f) }, 0xFF86B4, 0xE8104F, 0xFFFFFF, 12f) }
        "crown" -> canvas(600, 420, 300f, 34f) { c ->
            val pts = listOf(34f to 60f, 34f to 280f, 100f to 172f, 166f to 330f, 233f to 172f, 300f to 376f, 367f to 172f, 434f to 330f, 500f to 172f, 566f to 280f, 566f to 60f)
            val p = Path().apply { moveTo(pts[0].first, pts[0].second); pts.drop(1).forEach { lineTo(it.first, it.second) }; close() }
            fill(c, p, 0xFFE873, 0xF0A400); stroke(c, p, 0x9A5B00, 8f)
            val band = Path().apply { addRoundRect(RectF(22f, 18f, 578f, 102f), 22f, 22f, Path.Direction.CW) }
            fill(c, band, 0xFFD84D, 0xD98A00); stroke(c, band, 0x9A5B00, 8f)
            for ((x, y) in listOf(34f to 280f, 166f to 330f, 300f to 376f, 434f to 330f, 566f to 280f)) ball(c, x, y + 8, 24f, 0xFFF3A6, 0xE89B00)
            for ((x, l, d) in listOf(Triple(120f, 0xFF8A8AL, 0xC2101CL), Triple(300f, 0x9FD4FFL, 0x1565C0L), Triple(480f, 0x9BEFB0L, 0x12894AL))) ball(c, x, 60f, 25f, l, d)
            for (x in listOf(210f, 390f)) solid(c, star(x, 60f, 17f, 6f, 4), 0xFFFFFF, 0.9f)
        }
        "moustache" -> canvas(600, 220, 300f, 128f) { c ->
            for (side in listOf(1f, -1f)) {
                fun X(x: Float) = 300 + side * x
                val p = Path().apply {
                    moveTo(X(0f), 150f)
                    cubicTo(X(50f), 186f, X(120f), 182f, X(170f), 148f)
                    cubicTo(X(215f), 118f, X(262f), 150f, X(282f), 196f)
                    cubicTo(X(292f), 96f, X(210f), 52f, X(150f), 66f)
                    cubicTo(X(95f), 80f, X(45f), 70f, X(0f), 96f)
                    close()
                }
                fill(c, p, 0x4A3324, 0x1E130C)
                stroke(c, Path().apply { moveTo(X(40f), 150f); quadTo(X(100f), 166f, X(160f), 132f) }, 0xFFFFFF, 7f, 0.18f)
            }
        }
        "dogears" -> canvas(700, 330, 350f, 250f) { c ->
            for (side in listOf(1f, -1f)) {
                val cx = 350 + side * 255
                fill(c, oval(cx, 165f, 82f, 150f, side * -0.3f), 0x9A6535, 0x6B4020)
                stroke(c, oval(cx, 165f, 82f, 150f, side * -0.3f), 0x4A2B14, 7f)
                fill(c, oval(cx + side * 6, 151f, 44f, 104f, side * -0.3f), 0xD9A273, 0xB57A4C)
            }
        }
        "dognose" -> canvas(300, 230, 150f, 130f) { c ->
            val p = Path().apply {
                moveTo(150f, 44f); cubicTo(80f, 44f, 22f, 96f, 28f, 150f); cubicTo(36f, 222f, 264f, 222f, 272f, 150f); cubicTo(278f, 96f, 220f, 44f, 150f, 44f); close()
            }
            fill(c, p, 0x3A3A3A, 0x050505)
            solid(c, oval(112f, 176f, 46f, 17f, 0.2f), 0xFFFFFF, 0.55f)
            stroke(c, line(150f, 46f, 150f, 8f), 0x050505, 9f)
        }
        "tongue" -> canvas(200, 260, 100f, 246f) { c ->
            val p = Path().apply { moveTo(26f, 250f); lineTo(174f, 250f); cubicTo(190f, 120f, 170f, 12f, 100f, 12f); cubicTo(30f, 12f, 10f, 120f, 26f, 250f); close() }
            fill(c, p, 0xFF6F91, 0xFF9DB5); stroke(c, p, 0xD94B6E, 6f)
            stroke(c, line(100f, 236f, 100f, 78f), 0xD94B6E, 6f, 0.7f)
        }
        "bunnyears" -> canvas(600, 560, 300f, 40f) { c ->
            for (side in listOf(1f, -1f)) {
                val cx = 300 + side * 128
                fill(c, oval(cx, 290f, 78f, 252f, side * -0.13f), 0xFFFFFF, 0xECECF2)
                stroke(c, oval(cx, 290f, 78f, 252f, side * -0.13f), 0xC9C9D4, 7f)
                fill(c, oval(cx, 284f, 38f, 196f, side * -0.13f), 0xFFC2D4, 0xFF93B2)
            }
        }
        "bunnynose" -> canvas(700, 220, 350f, 124f) { c ->
            for (side in listOf(1f, -1f)) for (dy in listOf(46f, 0f, -46f)) {
                val w = line(350 + side * 74, 110 + dy * 0.25f, 350 + side * 330, 110 + dy * 1.6f)
                stroke(c, w, 0x2B2B2B, 9f, 0.35f); stroke(c, w, 0xFFFFFF, 5f, 0.95f)
            }
            val n = Path().apply { moveTo(350f, 84f); cubicTo(318f, 96f, 284f, 124f, 296f, 152f); cubicTo(312f, 178f, 388f, 178f, 404f, 152f); cubicTo(416f, 124f, 382f, 96f, 350f, 84f); close() }
            fill(c, n, 0xFF9DB8, 0xF2577F)
            solid(c, oval(332f, 150f, 16f, 7f, 0.2f), 0xFFFFFF, 0.6f)
        }
        "bunnyteeth" -> canvas(220, 170, 110f, 162f) { c ->
            for (x in listOf(14f, 114f)) {
                val t = Path().apply { addRoundRect(RectF(x, 10f, x + 92, 160f), 20f, 20f, Path.Direction.CW) }
                fill(c, t, 0xFFFFFF, 0xEEF0F5); stroke(c, t, 0xB9BECB, 6f)
            }
        }
        "clownnose" -> canvas(300, 300, 150f, 150f) { c ->
            solid(c, oval(156f, 134f, 132f, 128f), 0x000000, 0.16f)
            ball(c, 150f, 152f, 128f, 0xFF7A6B, 0xB80012)
        }
        "halo" -> canvas(600, 220, 300f, 110f) { c ->
            val ring = oval(300f, 110f, 240f, 60f)
            stroke(c, ring, 0xFFE27A, 74f, 0.16f); stroke(c, ring, 0xFFE27A, 50f, 0.22f)
            stroke(c, ring, 0xF5B301, 28f); stroke(c, ring, 0xFFF2A8, 12f)
            stroke(c, Path().apply { arcTo(RectF(64f, 51f, 536f, 169f), 126f, 31f) }, 0xFFFFFF, 7f, 0.9f)
        }
        "horns" -> canvas(600, 330, 300f, 24f) { c ->
            for (side in listOf(1f, -1f)) {
                fun X(x: Float) = 300 + side * x
                val p = Path().apply { moveTo(X(96f), 12f); cubicTo(X(110f), 150f, X(190f), 250f, X(266f), 312f); cubicTo(X(292f), 190f, X(280f), 70f, X(232f), 12f); close() }
                fill(c, p, 0xFF4D3D, 0x8E0A0A); stroke(c, p, 0x5E0505, 7f)
                stroke(c, Path().apply { moveTo(X(136f), 50f); quadTo(X(150f), 170f, X(232f), 250f) }, 0xFFFFFF, 8f, 0.3f)
            }
        }
        "partyhat" -> canvas(420, 560, 210f, 46f) { c ->
            val cone = line(40f, 50f, 380f, 50f, 210f, 480f).apply { close() }
            c.save(); c.clipPath(cone)
            val colours = listOf(0xFF4FA3L, 0x33C9FFL, 0xFFD84DL, 0x7BE495L)
            for (i in 0 until 12) { val y = i * 62f - 120; solid(c, line(0f, y, 420f, y + 190, 420f, y + 252, 0f, y + 62).apply { close() }, colours[i % 4]) }
            solid(c, line(250f, 50f, 380f, 50f, 210f, 480f).apply { close() }, 0x000000, 0.12f)
            c.restore()
            stroke(c, cone, 0xFFFFFF, 6f, 0.9f)
            for (i in 0 until 9) ball(c, 40 + i * 42.5f, 48f, 26f, 0xFFFFFF, 0xFFC83D)
            for ((dx, dy) in listOf(0f to 0f, -26f to -10f, 26f to -10f, -12f to 24f, 14f to 22f)) ball(c, 210 + dx, 498 + dy, 30f, 0xFFFFFF, 0xFF7AB8)
        }
        "flowers" -> canvas(760, 300, 380f, 70f) { c ->
            fun y(x: Float) = 70 + 130 * (1 - ((x - 380) / 340).toDouble().pow(2).toFloat())
            val band = Path().apply { moveTo(40f, y(40f)); var x = 60f; while (x <= 720f) { lineTo(x, y(x)); x += 20f } }
            stroke(c, band, 0x2E8B4B, 16f)
            var i = 0; var lx = 70f
            while (lx <= 690f) { fill(c, oval(lx, y(lx) + (if (i % 2 == 0) 30 else -24), 36f, 15f, if (i % 2 == 0) 0.7f else -0.6f), 0x6FD38A, 0x2E8B4B); lx += 62f; i++ }
            val petals = listOf(0xFF9CC4L to 0xF2578FL, 0xFFFFFFL to 0xE9E3F5L, 0xFFE08AL to 0xF5A623L, 0xC9B6FFL to 0x8E6CF0L)
            val xs = listOf(62f, 168f, 274f, 380f, 486f, 592f, 698f); val sizes = listOf(44f, 52f, 58f, 66f, 58f, 52f, 44f)
            for ((k, x) in xs.withIndex()) {
                val cy = y(x); val r = sizes[k]; val col = petals[k % 4]
                for (j in 0 until 5) {
                    val a = j * 2 * PI / 5 + k * 0.5
                    val px = x + (cos(a) * r * 0.62).toFloat(); val py = cy + (sin(a) * r * 0.62).toFloat()
                    fill(c, oval(px, py, r * 0.52f, r * 0.52f), col.first, col.second)
                    stroke(c, oval(px, py, r * 0.52f, r * 0.52f), 0x000000, 2f, 0.08f)
                }
                ball(c, x, cy, r * 0.36f, 0xFFF3A6, 0xF59E0B)
            }
        }
        "scar" -> canvas(320, 120, 160f, 60f) { c ->
            val cut = Path().apply { moveTo(20f, 50f); quadTo(160f, 82f, 300f, 70f) }
            stroke(c, cut, 0x5A0E12, 12f); stroke(c, cut, 0x9E2A2F, 5f)
            var x = 50f; while (x <= 270f) { stroke(c, line(x - 6, 28f, x + 6, 98f), 0x1E1E1E, 7f); x += 44f }
        }
        "antenna" -> canvas(200, 340, 100f, 16f) { c ->
            val base = Path().apply { addRoundRect(RectF(44f, 8f, 156f, 52f), 14f, 14f, Path.Direction.CW) }
            fill(c, base, 0xD5DAE2, 0x7F8894); stroke(c, base, 0x4B525C, 6f)
            val rod = Path().apply { addRoundRect(RectF(90f, 50f, 110f, 250f), 8f, 8f, Path.Direction.CW) }
            fill(c, rod, 0xC2C8D2, 0x7F8894); stroke(c, rod, 0x4B525C, 5f)
            solid(c, oval(100f, 278f, 58f, 58f), 0xFF3B30, 0.25f)
            ball(c, 100f, 278f, 40f, 0xFF9C94, 0xD60A0A)
        }
        "bolt" -> canvas(160, 160, 80f, 80f) { c ->
            val hex = star(80f, 80f, 70f, 61f, 6)
            fill(c, hex, 0xE1E5EB, 0x7F8894); stroke(c, hex, 0x4B525C, 7f)
            stroke(c, line(46f, 80f, 114f, 80f), 0x4B525C, 12f)
        }
        "sparkle" -> canvas(240, 240, 120f, 120f) { c ->
            solid(c, oval(120f, 120f, 78f, 78f), 0xFFF2A8, 0.25f)
            solid(c, star(120f, 120f, 116f, 22f, 4), 0xFFE27A); solid(c, star(120f, 120f, 84f, 14f, 4), 0xFFFFFF)
        }
        "heart" -> canvas(240, 240, 120f, 120f) { c ->
            val h = heart(120f, 124f, 200f)
            fill(c, h, 0xFF8FB3, 0xF2386E); stroke(c, h, 0xFFFFFF, 8f, 0.9f)
            solid(c, oval(78f, 162f, 22f, 13f, 0.5f), 0xFFFFFF, 0.7f)
        }
        "sun" -> canvas(600, 600, 300f, 300f) { c ->
            for (i in 0 until 12) {
                val a = i * PI / 6; val far = if (i % 2 == 0) 292f else 246f
                fun pt(ang: Double, r: Float) = floatArrayOf(300 + (cos(ang) * r).toFloat(), 300 + (sin(ang) * r).toFloat())
                val p0 = pt(a - 0.11, 170f); val p1 = pt(a, far); val p2 = pt(a + 0.11, 170f)
                solid(c, line(p0[0], p0[1], p1[0], p1[1], p2[0], p2[1]).apply { close() }, 0xFFC531)
            }
            solid(c, oval(300f, 300f, 176f, 176f), 0xFFE27A, 0.5f)
            ball(c, 300f, 300f, 150f, 0xFFF6B8, 0xFFB300)
        }
        else -> null
    }

    /** A transparent frame-sized picture with every placed sticker on it (reused between frames). */
    class Layer(private val w: Int, private val h: Int) {
        private val pics = arrayOf(Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888), Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888))
        private var next = 0
        fun draw(placed: List<FaceFun.Placed>): Bitmap {
            val b = pics[next]; next = 1 - next
            val c = Canvas(b)
            c.drawColor(Color.TRANSPARENT, PorterDuff.Mode.CLEAR)
            draw(c, placed)
            return b
        }
    }
}

/** The face stickers as a frame-sized overlay, redrawn for each frame where the faces are at that moment. */
@androidx.annotation.OptIn(androidx.media3.common.util.UnstableApi::class)
class StickerOverlay(private val people: People, private val id: String, private val w: Int, private val h: Int) : androidx.media3.effect.BitmapOverlay() {
    private val layer = FaceStickers.Layer(w, h)
    private var lastUs = Long.MIN_VALUE
    private var last: Bitmap? = null

    /** What goes on the frame at [t] seconds (pure apart from the drawing). */
    fun placed(t: Double): List<FaceFun.Placed> {
        val faces = people.facesAt(t).take(2).map { FaceFun.face(it, w, h) }
        val out = faces.flatMapIndexed { i, f -> FaceFun.stickers(id, f, t.toFloat(), i, w, h) }.toMutableList()
        if (id == "sunny") out.add(0, FaceFun.sun(w, h, t.toFloat()))
        return out
    }

    override fun getBitmap(presentationTimeUs: Long): Bitmap {
        if (presentationTimeUs == lastUs) last?.let { return it }
        val b = layer.draw(placed(presentationTimeUs / 1e6))
        lastUs = presentationTimeUs; last = b
        return b
    }
}

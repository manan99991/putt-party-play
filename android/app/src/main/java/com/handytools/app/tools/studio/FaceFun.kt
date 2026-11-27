package com.handytools.app.tools.studio

import kotlin.math.PI
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.hypot
import kotlin.math.max
import kotlin.math.min
import kotlin.math.sin

/**
 * Face fun for the Video Studio (the iPhone's FaceFun, on Android): the same 37 face and body effects. Each face ML Kit
 * finds is laid out (eyes, nose, mouth, chin, cheeks, its tilt) and every effect is turned into plain numbers — bends
 * for the GPU (bulge, cone, twirl, stretch), a skin tone inside the face, a mood for the whole picture, and stickers
 * Tenzy draws itself — so this part is pure and tested on the build machine. Playful effects only: never described as
 * "AI", a deepfake or a face swap. Nothing leaves the phone.
 */
object FaceFun {
    enum class Group(val title: String) { HEADS("Heads"), WARPS("Warps"), STICKERS("Stickers"), SKIN("Skin & colour"), MOODS("Moods"), BODY("Body") }
    data class Effect(val id: String, val name: String, val emoji: String, val group: Group)

    val effects = listOf(
        Effect("cone", "Cone head", "🍦", Group.HEADS), Effect("egg", "Egg head", "🥚", Group.HEADS),
        Effect("balloon", "Balloon face", "🎈", Group.HEADS), Effect("bighead", "Big head", "🎃", Group.HEADS),
        Effect("tinyhead", "Tiny head", "🐜", Group.HEADS),
        Effect("bigmouth", "Big mouth", "👄", Group.WARPS), Effect("bigeyes", "Big eyes", "👀", Group.WARPS), Effect("tinyface", "Tiny face", "🤏", Group.WARPS),
        Effect("squish", "Squished", "🫓", Group.WARPS), Effect("pinch", "Pinched", "🍐", Group.WARPS), Effect("longchin", "Long chin", "🌙", Group.WARPS),
        Effect("chipmunk", "Chipmunk cheeks", "🐿️", Group.WARPS), Effect("stretchy", "Stretchy face", "🫠", Group.WARPS), Effect("wobbly", "Wobbly face", "🌀", Group.WARPS),
        Effect("sunglasses", "Cool shades", "🕶️", Group.STICKERS), Effect("heartglasses", "Heart glasses", "😍", Group.STICKERS), Effect("crown", "Crown", "👑", Group.STICKERS),
        Effect("moustache", "Moustache", "🥸", Group.STICKERS), Effect("dog", "Puppy", "🐶", Group.STICKERS), Effect("bunny", "Bunny", "🐰", Group.STICKERS),
        Effect("clown", "Clown nose", "🤡", Group.STICKERS), Effect("halo", "Halo", "😇", Group.STICKERS), Effect("devil", "Devil horns", "😈", Group.STICKERS),
        Effect("partyhat", "Party hat", "🥳", Group.STICKERS), Effect("flowers", "Flower crown", "🌸", Group.STICKERS),
        // Alien, Zombie, Robot, Glow, Beautiful and Wholesome (the face repaints) were taken out on 27 Nov with Bald, as on
        // the iPhone: hand-built, they looked cheap on real home video. Their code stays, unlisted.
        Effect("cartoon", "Cartoon", "🎨", Group.MOODS), Effect("sunny", "Seriously sunny", "☀️", Group.MOODS), Effect("tacky", "Tacky", "💎", Group.MOODS),
        Effect("longlegs", "Long legs", "🦵", Group.BODY), Effect("tinybody", "Big head, tiny body", "🧸", Group.BODY),
    )

    fun effect(id: String): Effect? = effects.firstOrNull { it.id == id }

    // ---- a face, in the frame's pixels (y down) ----

    data class Pt(val x: Float, val y: Float) {
        operator fun plus(o: Pt) = Pt(x + o.x, y + o.y)
        operator fun minus(o: Pt) = Pt(x - o.x, y - o.y)
        operator fun times(k: Float) = Pt(x * k, y * k)
    }

    class Face(val eyeA: Pt, val eyeB: Pt, val nose: Pt, val mouth: Pt, val mouthWidth: Float, val brow: Pt, val chin: Pt,
               val cheekA: Pt, val cheekB: Pt, val roll: Float, val width: Float, val height: Float) {
        val eyeDistance: Float get() = hypot(eyeB.x - eyeA.x, eyeB.y - eyeA.y)
        /** Toward the top of the head (y down, so upright is (0, -1)). */
        val up: Pt get() = Pt(sin(roll), -cos(roll))
        /** Across the face, toward the picture's right when upright. */
        val side: Pt get() = Pt(cos(roll), sin(roll))
        val center: Pt get() = Pt((eyeA.x + eyeB.x) / 4 + mouth.x / 2, (eyeA.y + eyeB.y) / 4 + mouth.y / 2)
        fun point(p: Pt, up: Float = 0f, across: Float = 0f): Pt = p + this.up * up + side * across
    }

    /**
     * A face from what the finder gave (fractions of the frame, y down): its box centre and size, and when found its
     * eyes and mouth. Laid out with ordinary face proportions; real eyes and mouth replace them. `roll` follows the
     * eyes when both are found.
     */
    fun face(spot: FaceSpot, w: Int, h: Int): Face {
        val c = Pt(spot.x * w, spot.y * h)
        val s = spot.size * w
        // ML Kit sometimes puts both eyes almost on one spot (a small or half-turned face): 27 Nov phone run, photo 1,
        // eyes 4 px apart on an 80 px face, one above the other, which read as a face turned on its side. Eyes that
        // close together, or not side by side, are not believed; the face box and its own tilt place them instead.
        val seen = spot.eyes.map { Pt(it.x * w, it.y * h) }.sortedBy { it.x }
        val believable = seen.size >= 2 && run {
            val d = hypot(seen[1].x - seen[0].x, seen[1].y - seen[0].y)
            val tilt = abs(atan2(seen[1].y - seen[0].y, seen[1].x - seen[0].x) - spot.roll)
            d >= s * 0.25f && tilt < 0.6f
        }
        val eyes = if (believable) seen else emptyList()
        val roll = if (eyes.size >= 2) atan2(eyes[1].y - eyes[0].y, eyes[1].x - eyes[0].x) else spot.roll
        val up = Pt(sin(roll), -cos(roll)); val side = Pt(cos(roll), sin(roll))
        fun at(u: Float, v: Float) = c + side * (u * s) + up * (v * s)
        val eyeA = if (eyes.size >= 2) eyes[0] else at(-0.19f, 0.1f)
        val eyeB = if (eyes.size >= 2) eyes[1] else at(0.19f, 0.1f)
        val ed = hypot(eyeB.x - eyeA.x, eyeB.y - eyeA.y).coerceAtLeast(s * 0.2f)
        val mid = (eyeA + eyeB) * 0.5f
        val mouth = spot.mouth?.let { Pt(it.x * w, it.y * h) } ?: (mid + up * (-ed * 0.95f))
        val nose = spot.nose?.let { Pt(it.x * w, it.y * h) } ?: (mid + up * (-ed * 0.55f))
        val brow = mid + up * (ed * 0.35f)
        val chin = mid + up * (-ed * 1.6f)
        return Face(eyeA, eyeB, nose, mouth, ed * 0.85f, brow, chin, mid + side * (-ed * 0.95f) + up * (-ed * 0.55f),
            mid + side * (ed * 0.95f) + up * (-ed * 0.55f), roll, ed * 2.3f, ed * 1.95f)
    }

    // ---- bends for the GPU ----

    /**
     * One bend, as the shader takes it. Kinds: 1 an oval that swells or shrinks (a = centre x, y, half-axes; b = angle,
     * across strength, up strength); 2 the top of the head drawn up and narrowed (a = brow x, y, height, half-width;
     * b = roll, stretch, point); 3 a twirl (a = centre, radius; b = angle); 4 everything below a line stretched down
     * (a = line y, length; b = -, factor); 5 the forehead drawn up over the crown (a = from x, y, strip, top; b = roll,
     * half-width).
     */
    data class Bend(val kind: Int, val a: FloatArray, val b: FloatArray)

    private fun bulge(c: Pt, rx: Float, ry: Float, angle: Float, sx: Float, sy: Float) = Bend(1, floatArrayOf(c.x, c.y, rx, ry), floatArrayOf(angle, sx, sy))

    /** The bends `id` puts on one face. `a` 0…1 is "How much"; `t` seconds makes a few of them move. */
    fun bends(id: String, f: Face, t: Float, a: Float, frameW: Int = 0, frameH: Int = 0): List<Bend> {
        fun s(lo: Float, hi: Float) = lo + (hi - lo) * a
        val c = f.center; val r = f.roll
        return when (id) {
            "bighead" -> { val k = s(0.55f, 0.82f) * (1 + 0.05f * sin(t * 3)); listOf(bulge(f.point(c, up = f.height * 0.12f), f.width * 1.6f, f.height * 1.85f, r, k, k)) }
            "tinyhead" -> listOf(bulge(f.point(c, up = f.height * 0.12f), f.width * 1.2f, f.height * 1.4f, r, -s(0.85f, 1.2f), -s(0.85f, 1.2f)))
            "balloon" -> { val p = s(0.62f, 0.86f) * (1 + 0.06f * sin(t * 2.4f)); listOf(bulge(f.point(c, up = f.height * 0.05f), f.width * 1.08f, f.height * 1.22f, r, p, p)) }
            "cone" -> listOf(Bend(2, floatArrayOf(f.brow.x, f.brow.y, f.height * 0.98f, f.width * 0.56f), floatArrayOf(r, s(0.5f, 1f), s(0.6f, 1f))))
            "egg" -> listOf(Bend(2, floatArrayOf(f.brow.x, f.brow.y, f.height * 0.98f, f.width * 0.56f), floatArrayOf(r, s(0.35f, 0.7f), 0.22f)))
            "alien" -> listOf(
                bulge(f.point(f.brow, up = f.height * 0.35f), f.width * 0.95f, f.height * 0.95f, r, s(0.3f, 0.5f), s(0.3f, 0.5f)),
                bulge(f.point(f.mouth, up = -f.height * 0.1f), f.width * 0.6f, f.height * 0.55f, r, -s(0.5f, 0.9f), 0f),
                bulge(f.eyeA, f.eyeDistance * 0.46f, f.eyeDistance * 0.38f, r, s(0.4f, 0.6f), s(0.4f, 0.6f)),
                bulge(f.eyeB, f.eyeDistance * 0.46f, f.eyeDistance * 0.38f, r, s(0.4f, 0.6f), s(0.4f, 0.6f)))
            "bigmouth" -> listOf(bulge(f.mouth, f.mouthWidth * 1.5f, f.mouthWidth * 1.15f, r, s(0.62f, 0.86f), s(0.62f, 0.86f)))
            "bigeyes" -> listOf(f.eyeA, f.eyeB).map { bulge(it, f.eyeDistance * 0.5f, f.eyeDistance * 0.5f, r, s(0.62f, 0.86f), s(0.62f, 0.86f)) }
            "tinyface" -> listOf(bulge(c, f.width * 0.7f, f.height * 0.8f, r, -s(0.9f, 1.2f), -s(0.9f, 1.2f)))
            "squish" -> listOf(bulge(c, f.width * 1.1f, f.height * 1.2f, r, s(0.45f, 0.7f), -s(0.8f, 1.15f)))
            "pinch" -> listOf(
                bulge(f.point(f.brow, up = f.height * 0.1f), f.width * 0.85f, f.height * 0.7f, r, -s(0.5f, 1f), 0f),
                bulge(f.point(f.mouth, up = -f.height * 0.05f), f.width * 0.8f, f.height * 0.6f, r, s(0.3f, 0.5f), 0f))
            "longchin" -> listOf(bulge(f.point(f.mouth, up = -f.height * 0.2f), f.width * 0.5f, f.height * 0.7f, r, -0.15f, s(0.65f, 0.88f)))
            "chipmunk" -> listOf(f.cheekA, f.cheekB).map { ch ->
                val p = f.point(Pt(f.mouth.x + (ch.x - f.mouth.x) * 0.62f, f.mouth.y + (ch.y - f.mouth.y) * 0.62f), up = f.height * 0.05f)
                bulge(p, f.width * 0.4f, f.width * 0.4f, r, s(0.62f, 0.86f), s(0.62f, 0.86f))
            }
            "stretchy" -> listOf(bulge(c, f.width, f.height * 1.35f, r, -0.35f, s(0.62f, 0.82f) + 0.06f * sin(t * 3)))
            "wobbly" -> listOf(Bend(3, floatArrayOf(c.x, c.y, f.width * 0.95f, 0f), floatArrayOf((0.35f + 0.7f * a) * sin(t * 5), 0f, 0f)))
            "tinybody" -> listOf(
                bulge(f.point(f.chin, up = -f.height * 1.75f), f.width * 1.7f, f.height * 1.75f, r, -s(0.55f, 1.1f), -s(0.2f, 0.45f)),
                bulge(f.point(c, up = f.height * 0.15f), f.width * 1.2f, f.height * 1.4f, r, s(0.4f, 0.64f), s(0.4f, 0.64f)))
            "bald" -> {
                val from = f.height * 0.05f; val strip = f.height * 0.2f
                val start = f.point(f.brow, up = from)
                listOf(Bend(5, floatArrayOf(start.x, start.y, strip, f.height * 0.84f - from), floatArrayOf(r, f.width * 0.6f, f.height * 0.74f)))
            }
            "beautiful" -> listOf(f.eyeA, f.eyeB).map { bulge(it, f.eyeDistance * 0.44f, f.eyeDistance * 0.44f, r, s(0.08f, 0.2f), s(0.08f, 0.2f)) }
            "wholesome" -> listOf(f.eyeA, f.eyeB).map { bulge(it, f.eyeDistance * 0.44f, f.eyeDistance * 0.44f, r, s(0.1f, 0.24f), s(0.1f, 0.24f)) }
            else -> emptyList()
        }
    }

    /** Long legs: below the hips (about three face-heights under the chin) drawn longer — never past the room above the head. */
    fun legs(f: Face, frameH: Int, a: Float): Bend? {
        val hips = f.chin.y + f.height * 2.8f
        val floor = frameH.toFloat()
        val legs = floor - hips
        if (legs < frameH * 0.08f) return null
        val headTop = f.point(f.brow, up = f.height * 0.8f).y
        val room = max(0f, headTop - frameH * 0.01f)
        val k = min(1.2f + 0.3f * a, 1f + room / legs)
        if (k < 1.02f) return null
        return Bend(4, floatArrayOf(floor, legs, 0f, 0f), floatArrayOf(0f, k, 0f))
    }

    // ---- skin and mood ----

    /** The skin effect on a face: 0 none, 1 alien, 2 zombie, 3 robot, 4 glow, 5 beautiful, 6 wholesome (rosy). */
    fun skin(id: String): Int = when (id) { "alien" -> 1; "zombie" -> 2; "robot" -> 3; "glow" -> 4; "beautiful" -> 5; "wholesome" -> 6; else -> 0 }

    /** The whole picture's mood: 0 none, 1 cartoon, 2 seriously sunny, 3 tacky, 4 soft and warm. */
    fun mood(id: String): Int = when (id) { "cartoon" -> 1; "sunny" -> 2; "tacky" -> 3; "beautiful", "wholesome" -> 4; else -> 0 }

    /** The effects that change the whole picture (or well beyond the face). */
    val wholePicture = setOf("cartoon", "glow", "beautiful", "sunny", "tacky", "wholesome", "longlegs", "tinybody")
    fun needsMask(id: String) = id == "bald"
    /** The effects that use the face engine's parts (hair, face skin): Bald and the skin effects (the iPhone's usesParts). */
    fun usesParts(id: String) = id in setOf("bald", "alien", "zombie", "robot", "glow", "beautiful", "wholesome")

    // ---- stickers ----

    /** One drawn sticker on the frame: which, where its anchor sits, how wide, turned how far, how see-through. */
    data class Placed(val sprite: String, val at: Pt, val width: Float, val angle: Float, val alpha: Float = 1f)

    /** The stickers `id` puts on one face, bottom layer first. */
    fun stickers(id: String, f: Face, t: Float, index: Int = 0, frameW: Int = 0, frameH: Int = 0): List<Placed> {
        val r = f.roll
        fun put(sp: String, p: Pt, w: Float, turn: Float = 0f, alpha: Float = 1f) = Placed(sp, p, w, r + turn, alpha)
        val eyes = (f.eyeA + f.eyeB) * 0.5f
        val glasses = f.eyeDistance * 600f / 310f
        val underNose = Pt(f.nose.x * 0.55f + f.mouth.x * 0.45f, f.nose.y * 0.55f + f.mouth.y * 0.45f)
        val noseTip = f.point(f.nose, up = f.height * 0.05f)
        val out = mutableListOf<Placed>()
        when (id) {
            "sunglasses", "sunny" -> out += put("shades", eyes, glasses)
            "heartglasses" -> out += put("heartglasses", eyes, glasses * 1.04f)
            "crown" -> out += put("crown", f.point(f.brow, up = f.height * 0.6f), f.width * 0.95f)
            "moustache" -> out += put("moustache", underNose, max(f.mouthWidth * 1.9f, f.width * 0.5f))
            "dog" -> { out += put("dogears", f.point(f.brow, up = f.height * 0.5f), f.width * 1.55f)
                out += put("tongue", f.point(f.mouth, up = -f.mouthWidth * 0.08f), f.mouthWidth * 0.55f, 0.1f * sin(t * 6))
                out += put("dognose", noseTip, f.eyeDistance * 0.68f) }
            "bunny" -> { out += put("bunnyears", f.point(f.brow, up = f.height * 0.58f), f.width * 1.05f, 0.03f * sin(t * 3))
                out += put("bunnyteeth", f.point(f.mouth, up = f.mouthWidth * 0.06f), f.mouthWidth * 0.36f)
                out += put("bunnynose", noseTip, f.width * 1.0f) }
            "clown" -> out += put("clownnose", noseTip, f.eyeDistance * 0.66f)
            "halo" -> out += put("halo", f.point(f.brow, up = f.height * (1.02f + 0.03f * sin(t * 2.2f))), f.width * 0.95f)
            "devil" -> out += put("horns", f.point(f.brow, up = f.height * 0.42f), f.width)
            "partyhat" -> out += put("partyhat", f.point(f.brow, up = f.height * 0.6f, across = f.width * 0.08f), f.width * 0.78f, -0.14f)
            "flowers" -> out += put("flowers", f.point(f.brow, up = f.height * 0.3f), f.width * 1.3f)
            "zombie" -> out += put("scar", f.point(f.brow, up = f.height * 0.26f, across = f.width * 0.14f), f.width * 0.3f, 0.2f)
            "robot" -> { out += put("antenna", f.point(f.brow, up = f.height * 0.72f), f.width * 0.2f)
                out += put("bolt", f.point(f.cheekA, up = f.height * 0.12f), f.width * 0.15f); out += put("bolt", f.point(f.cheekB, up = f.height * 0.12f), f.width * 0.15f) }
            "tacky" -> {
                out += put("crown", f.point(f.brow, up = f.height * 0.6f, across = -f.width * 0.06f), f.width * 0.9f, 0.16f)
                out += put("bling", eyes, glasses * 1.06f)
                for (k in 0 until 7) {
                    val ang = k * 2 * PI.toFloat() / 7 + index; val tw = 0.5f + 0.5f * sin(t * 5 + k * 1.9f)
                    val p = f.point(f.point(f.center, up = f.height * 0.2f), up = sin(ang) * f.height * 1.05f, across = cos(ang) * f.width * 0.95f)
                    out += put("sparkle", p, f.width * (0.1f + 0.14f * tw), t * 0.6f, 0.35f + 0.65f * tw)
                }
            }
            "wholesome" -> {
                out += put("flowers", f.point(f.brow, up = f.height * 0.3f), f.width * 1.3f)
                for (k in 0 until 6) {
                    val phase = ((t * 0.32f + k / 6f) % 1f + 1f) % 1f
                    val sideways = (if (k % 2 == 0) 1f else -1f) * (0.72f + 0.12f * (k % 3)) + 0.05f * sin(t * 2 + k)
                    val p = f.point(f.center, up = f.height * (-0.3f + 1.7f * phase), across = f.width * sideways)
                    out += put("heart", p, f.width * (0.12f + 0.06f * (k % 3)), 0.2f * sin(t * 1.5f + k), min(1f, 4 * phase) * (1 - phase))
                }
            }
        }
        return out
    }

    /** The sun in the corner for Seriously sunny (once per picture, not per face). */
    fun sun(frameW: Int, frameH: Int, t: Float): Placed =
        Placed("sun", Pt(frameW - frameW * 0.12f, frameW * 0.12f), frameW * 0.42f, t * 0.35f)
}

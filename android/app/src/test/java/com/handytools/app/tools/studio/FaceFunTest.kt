package com.handytools.app.tools.studio

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.PI
import kotlin.math.abs

/** Face fun on Android: the iPhone's 36 effects, each laid out from a face and turned into bends, skin and stickers. */
class FaceFunTest {
    private val w = 720; private val h = 960
    private val upright = FaceSpot(0.5f, 400f / 960, 320f / 720, listOf(Spot(300f / 720, 360f / 960), Spot(420f / 720, 360f / 960)), 0f, Spot(0.5f, 480f / 960), Spot(0.49f, 418f / 960))

    @Test fun theSameEffectsAsTheIphone() {
        val ids = FaceFun.effects.map { it.id }
        assertEquals(36, ids.size); assertEquals(ids.size, ids.toSet().size)
        for (must in listOf("cone", "balloon", "sunglasses", "crown", "moustache", "dog", "bunny", "zombie", "robot", "cartoon", "beautiful", "sunny", "tacky", "wholesome", "longlegs"))
            assertTrue(must, must in ids)
        for (g in FaceFun.Group.values()) assertTrue(g.name, FaceFun.effects.count { it.group == g } >= 2)
        for (e in FaceFun.effects) assertTrue(e.id, e.name.length <= 22)
    }

    @Test fun aFaceIsLaidOutTheRightWayUp() {
        val f = FaceFun.face(upright, w, h)
        assertEquals(120f, f.eyeDistance, 0.5f)
        assertEquals(0f, f.roll, 0.001f)
        assertTrue("eyes above the mouth", f.eyeA.y < f.mouth.y && f.mouth.y < f.chin.y && f.brow.y < f.eyeA.y)
        assertEquals(-1f, f.up.y, 0.001f)
        assertEquals(480f, f.mouth.y, 0.5f)
        // Tilted a sixth of a turn (right eye lower): up leans the same way.
        val t = FaceFun.face(upright.copy(eyes = listOf(Spot(300f / 720, 330f / 960), Spot(420f / 720, (330f + 69.3f) / 960))), w, h)
        assertEquals(PI.toFloat() / 6, t.roll, 0.02f)
        assertTrue(t.up.x > 0.4f)
        // No eyes found: laid out from the box with the finder's tilt.
        val boxOnly = FaceFun.face(FaceSpot(0.5f, 0.5f, 0.4f, roll = 0.3f), w, h)
        assertEquals(0.3f, boxOnly.roll, 0.001f)
        assertTrue(boxOnly.eyeDistance > 80f)
    }

    @Test fun everyEffectDoesSomethingToAFace() {
        val f = FaceFun.face(upright, w, h)
        for (e in FaceFun.effects) {
            val bends = FaceFun.bends(e.id, f, 1f, 0.7f, w, h)
            val legs = if (e.id == "longlegs") FaceFun.legs(f, 2400, 0.7f) else null
            val stickers = FaceFun.stickers(e.id, f, 1f, 0, w, h)
            val doesSomething = bends.isNotEmpty() || legs != null || stickers.isNotEmpty() || FaceFun.skin(e.id) > 0 || FaceFun.mood(e.id) > 0
            assertTrue("${e.id} does nothing", doesSomething)
            for (s in stickers) assertTrue("${e.id}: no drawing called ${s.sprite}", s.sprite in sprites)
        }
    }

    private val sprites = setOf("shades", "bling", "heartglasses", "crown", "moustache", "dogears", "dognose", "tongue", "bunnyears", "bunnynose",
        "bunnyteeth", "clownnose", "halo", "horns", "partyhat", "flowers", "scar", "antenna", "bolt", "sparkle", "heart", "sun")

    @Test fun stickersSitWhereTheyBelong() {
        val f = FaceFun.face(upright, w, h)
        val shades = FaceFun.stickers("sunglasses", f, 0f).single()
        assertEquals(360f, shades.at.x, 1f); assertEquals(360f, shades.at.y, 1f)
        assertEquals(f.eyeDistance * 600 / 310, shades.width, 0.5f)
        val crown = FaceFun.stickers("crown", f, 0f).single()
        assertTrue("the crown sits above the brows", crown.at.y < f.brow.y - f.height * 0.4f)
        val tache = FaceFun.stickers("moustache", f, 0f).single()
        assertTrue("the moustache sits between nose and mouth", tache.at.y > f.nose.y && tache.at.y < f.mouth.y)
        // On a tilted face, stickers turn with it.
        val t = FaceFun.face(upright.copy(eyes = listOf(Spot(300f / 720, 330f / 960), Spot(420f / 720, (330f + 69.3f) / 960))), w, h)
        assertEquals(t.roll, FaceFun.stickers("sunglasses", t, 0f).single().angle, 0.001f)
    }

    @Test fun theShaderGetsGlNumbers() {
        val u = FaceFunEffect.frameUniforms("bighead", listOf(upright), w, h, 1f, 0.7f)
        assertEquals(1, u.count)
        assertEquals(1f, u.bendB[3])                                   // a bulge
        val f = FaceFun.face(upright, w, h)
        assertEquals(h - f.point(f.center, up = f.height * 0.12f).y, u.bendA[1], 0.5f)   // y up
        assertEquals(0f, u.bendB[7])                                   // nothing after it
        assertEquals(1f, FaceFunEffect.frameUniforms("alien", listOf(upright), w, h, 1f, 0.7f).faceT[1])
        assertEquals(1f, FaceFunEffect.frameUniforms("cartoon", listOf(upright), w, h, 1f, 0.7f).mood)
        // Two faces, never more than the shader holds.
        val many = FaceFunEffect.frameUniforms("alien", List(5) { upright }, w, h, 1f, 0.7f)
        assertTrue(many.count <= FaceFunEffect.MAX_BENDS)
        assertEquals(0, FaceFunEffect.frameUniforms("crown", emptyList(), w, h, 1f, 0.7f).count)
    }

    @Test fun theSoundMixes() {
        assertEquals(1f to 0f, VideoSound.volumes(0.0)); assertEquals(0f to 1f, VideoSound.volumes(1.0)); assertEquals(1f to 1f, VideoSound.volumes(0.5))
        val song = FloatArray(4) { (it + 1).toFloat() / 10 }
        val fit = VideoSound.fit(song, 10, 2)
        assertEquals(0.1f, fit[4], 1e-6f); assertEquals(0.4f, fit[7], 1e-6f)     // repeated
        assertEquals(0f, fit[9], 1e-6f)                                       // faded to nothing
        assertEquals(20, VideoSound.resample(FloatArray(10) { it.toFloat() }, 10, 20).size)
        val m = VideoSound.mix(floatArrayOf(0.9f, 0.9f), floatArrayOf(0.9f, 0f), 1f to 1f)
        assertTrue("kept off the ceiling", m.all { abs(it) <= 0.981f })
        assertEquals(VideoSound.choices.first().id, "original")
        assertEquals(Synth.styles.size, VideoSound.choices.count { it.id.startsWith("synth:") })
    }
}

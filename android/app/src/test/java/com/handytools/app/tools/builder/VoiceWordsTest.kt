package com.handytools.app.tools.builder

import com.handytools.app.tools.studio.Voices
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Describe it picks the voice the sentence names, as on the iPhone, and every voice offered can be rendered. */
class VoiceWordsTest {
    private fun voiceFor(s: String) = ChainPlanner.plan(s)?.steps?.last()?.settings?.get("voice")

    @Test fun theNamedVoiceIsTheOneUsed() {
        assertEquals("robot", voiceFor("make my voice sound like a robot"))
        assertEquals("autotune", voiceFor("auto-tune my singing"))
        assertEquals("announcer", voiceFor("say it like a stadium announcer"))
        assertEquals("radio", voiceFor("make it sound like an old radio"))
        assertEquals("whisper", voiceFor("turn my recording into a whisper"))
        assertEquals("ghost", voiceFor("a spooky ghost voice"))
        assertEquals("deep", voiceFor("give me a deep voice"))
        assertEquals("chipmunk", voiceFor("a funny voice for this recording"))
    }

    @Test fun everyVoiceOfferedHasACharacter() {
        assertEquals(19, TextTidy.VOICES.size)
        for ((id, _, _) in TextTidy.VOICES) assertTrue(id, Voices.characters.containsKey(id))
        assertEquals(TextTidy.VOICES.map { it.first }, Voices.all.map { it.id })
    }
}

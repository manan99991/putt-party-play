package com.handytools.app.tools.shield

import com.handytools.app.tools.power.CodesEngine
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotEquals
import org.junit.Test

/**
 * Android mirror of the iOS ReviewRegressionTests — the scam-checker bugs Manan found in the 15 Nov
 * full-app review, pinned so a future change can't quietly bring them back. Pure JVM logic (no device),
 * so these run in the free `testDebugUnitTest` gate.
 */
class ReviewRegressionTest {

    // The Amazon "hiring team / $200-500 a day / text a keyword to a 10-digit number" message read
    // "low-risk", then only "Suspicious". It is a textbook job scam and must read "Likely a scam".
    @Test fun amazonJobScamIsLikelyScam() {
        val msg = """
            Hi! The Amazon hiring team is currently offering a part-time online position. Candidates in this
            role will assist Amazon sellers with straightforward product optimization activities while working
            remotely.
            • 60–90 minutes per day
            • 4 days per week
            • ${'$'}200–${'$'}500 daily pay
            • ${'$'}8,000 base monthly income
            • Training provided
            • 20 positions currently available
            For applicants aged 20+, text "Job Details" to 5415132474.
        """.trimIndent()
        assertEquals(
            "a blatant job scam must be flagged, not read as low-risk",
            ScamAnalyzer.Verdict.LIKELY_SCAM, ScamAnalyzer.analyze(msg).verdict,
        )
    }

    // A genuine travel itinerary has prices and "per day" but no hiring phrase — it must NOT trip the
    // job-scam heuristic (the itinerary false positive that forced the matcher to be tightened).
    @Test fun travelItineraryIsNotAScam() {
        val msg = """
            Day 1 — New York: ferry to the Statue of Liberty, then the museum. Hotel is ${'$'}180 a night and
            dinner runs about ${'$'}120 per day for two. Check in at the hotel by 3 PM; 20 positions by the window.
        """.trimIndent()
        assertNotEquals(
            "an itinerary with prices + 'per day' must not be called a scam",
            ScamAnalyzer.Verdict.LIKELY_SCAM, ScamAnalyzer.analyze(msg).verdict,
        )
    }

    // fonts.googleapis.com is a real Google domain. It must never be flagged as a "google look-alike".
    @Test fun legitGoogleSubdomainIsNotALookAlike() {
        val r = ScamAnalyzer.analyze("Fonts load from https://fonts.googleapis.com/css2?family=Inter here.")
        val issues = r.links.flatMap { it.issues }.joinToString(" ").lowercase()
        assertFalse("a legitimate Google subdomain must not be a look-alike", issues.contains("look-alike"))
    }

    // A bare code-like token (a JS access "d.id") can read like a domain; we must not call it an
    // unencrypted link — the writer never typed "http://".
    @Test fun inferredSchemeIsNotReportedAsUnencrypted() {
        val r = ScamAnalyzer.analyze("In the code, sec.id and d.id and b.id are element accessors.")
        val issues = r.links.flatMap { it.issues }.joinToString(" ").lowercase()
        assertFalse("a bare token with an inferred scheme is not an unencrypted link", issues.contains("not encrypted"))
    }

    // A real apple look-alike sender domain must STILL be caught (we didn't dull the check).
    @Test fun realLookAlikeStillCaught() {
        val r = ScamAnalyzer.analyze("Sign in at https://apple-support.account-verify.com/login to keep your account.")
        val issues = r.links.flatMap { it.issues }.joinToString(" ").lowercase()
        assertTrueMsg("a genuine brand look-alike must still be flagged", issues.contains("look-alike"))
    }

    // Guard the other direction: a real gift-card/urgency scam must still be caught.
    @Test fun realGiftCardScamStillCaught() {
        val r = ScamAnalyzer.analyze("URGENT: your account is suspended. Pay a ${'$'}500 fee with Apple gift cards immediately or face legal action.")
        assertEquals(
            "a gift-card + urgency + threat scam must still be flagged",
            ScamAnalyzer.Verdict.LIKELY_SCAM, r.verdict,
        )
    }

    // QR content classification parity with the iOS QRPreviewContent cases.
    @Test fun qrWifiClassified() =
        assertEquals(CodesEngine.Kind.WIFI, CodesEngine.classify("WIFI:T:WPA;S:HomeNet;P:secret123;;", true).kind)

    @Test fun qrContactClassified() =
        assertEquals(CodesEngine.Kind.CONTACT, CodesEngine.classify("BEGIN:VCARD\nVERSION:3.0\nFN:Jane Doe\nTEL:+15551234567\nEND:VCARD", true).kind)

    @Test fun qrPhoneClassified() =
        assertEquals(CodesEngine.Kind.PHONE, CodesEngine.classify("tel:+15551234567", true).kind)

    @Test fun qrLinkClassified() =
        assertEquals(CodesEngine.Kind.URL, CodesEngine.classify("https://example.com/path", true).kind)

    @Test fun qrPlainTextIsNotALink() =
        assertEquals(CodesEngine.Kind.TEXT, CodesEngine.classify("just some notes to myself", true).kind)

    // A ZIP (or other archive) gets a specific, honest next step — not a vague "no tool for that file".
    @Test fun zipArchiveGetsASpecificMessage() {
        val note = com.handytools.app.tools.builder.unsupportedNote("application/zip", "photos.zip")
        assertTrueMsg("a zip must be named as an archive", note.contains("ZIP"))
        assertTrueMsg("the message must point at the files inside", note.lowercase().contains("inside"))
    }

    @Test fun unknownFileStillGetsTheGenericMessage() {
        val note = com.handytools.app.tools.builder.unsupportedNote("application/acad", "drawing.dwg")
        assertFalse("a non-archive must not be mislabelled an archive", note.contains("archive"))
    }

    private fun assertTrueMsg(msg: String, cond: Boolean) = org.junit.Assert.assertTrue(msg, cond)
}

package com.handytools.app.ui

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

/** Android Home (same design as the iPhone, 23 Nov): every tool has its own tile in one tab, no tab needs scrolling,
 *  every tile says a different job, Business shows only when switched on, and the For you car card behaves. */
class HomeShelvesTest {
    private val groupTiles = setOf("scansort", "more")   // old launcher tiles, not tools

    @Test fun everyToolHasATileInATab() {
        val tiled = HomeShelves.all.flatMap { it.tools }.toSet() + HomeShelves.businessTools
        val missing = SEARCHABLE.map { it.route }.filter { it !in groupTiles && it !in tiled }
        assertEquals("No tile on Home: $missing", emptyList<String>(), missing)
    }

    @Test fun noToolOnTwoTabsAndEveryTabFits() {
        val ids = HomeShelves.all.flatMap { it.tools }
        assertEquals("On two tabs: ${ids.groupBy { it }.filter { it.value.size > 1 }.keys}", ids.size, ids.toSet().size)
        HomeShelves.all.forEach { assertTrue("${it.title} has ${it.tools.size}", it.tools.size in 1..HomeShelves.MAX_PER_TAB) }
        assertTrue("tabs + Business must fit two rows of four", HomeShelves.tabs(true).size <= 8)
        assertTrue("Business jobs + the ask tile fit", HomeShelves.businessJobs.size + 1 <= HomeShelves.MAX_PER_TAB)
    }

    @Test fun everyTileSaysADifferentJob() {
        val tiled = HomeShelves.all.flatMap { it.tools }
        tiled.forEach { assertNotNull("$it has no job name", HomeShelves.jobName(it)) }
        val names = tiled.mapNotNull { HomeShelves.jobName(it) } + HomeShelves.businessJobs.map { it.title }
        assertEquals("Two tiles say the same: ${names.groupBy { it }.filter { it.value.size > 1 }.keys}", names.size, names.toSet().size)
        names.forEach { assertTrue("\"$it\" is too long for a tile", it.length <= 24) }
    }

    @Test fun businessOnlyWhenOn() {
        assertFalse(HomeShelves.tabs(false).any { it.id == "business" })
        assertTrue(HomeShelves.tabs(true).last().id == "business")
        val routes = ALL_TOOLS.map { it.route }.toSet() + setOf("wallet", "alarm", "timer")
        HomeShelves.businessJobs.forEach { assertTrue("${it.id} opens ${it.route}, which isn't a tool", it.route in routes) }
        HomeShelves.all.flatMap { it.tools }.forEach { assertTrue("$it isn't a screen", it in routes) }
    }

    @Test fun theCarCardShowsForTwoDaysAndNotNowHidesIt() {
        val now = 1_795_460_400_000L
        assertEquals(emptyList<ForYouAndroid.Card>(), ForYouAndroid.cards(null, now, emptyMap()))
        val c = ForYouAndroid.cards(now - 90 * 60_000L, now, emptyMap())
        assertEquals("Parked 1 h ago", c.single().why)
        assertEquals("parked", c.single().route)
        assertEquals(emptyList<ForYouAndroid.Card>(), ForYouAndroid.cards(now - 49 * 3600_000L, now, emptyMap()))
        assertEquals(emptyList<ForYouAndroid.Card>(), ForYouAndroid.cards(now - 60_000L, now, mapOf("car-${now - 60_000L}" to now + 1)))
    }
}

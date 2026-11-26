package com.handytools.app.tools.autoruns

import android.content.Context
import android.net.Uri
import com.handytools.app.tools.studio.Reels
import java.io.File

/**
 * My week, as one short film (the iPhone's weekly autorun): the week's sharp photos of people (one per moment, little
 * ones first, spread across the days) and its liveliest clips, in the order they happened, cut to the beat of Tenzy's
 * own music as one tall Beat Reel.
 */
object WeekFilm {
    const val MOST_PHOTOS = 12
    const val MOST_CLIPS = 3
    const val STYLE = "upbeat"

    /** The film from [window], or null when there aren't enough photos of people. [stage] says what it's doing. */
    suspend fun make(ctx: Context, window: LongRange, stage: (String) -> Unit, progress: (Double) -> Unit): File? {
        stage("Looking at this week's photos…")
        val photos = PhotoDays.find(ctx, window)
        val picks = SmartRuns.collagePicks(PhotoDays.read(ctx, photos) { p -> progress(p * 0.35) }, MOST_PHOTOS)
        val clips = ReadyToPost.find(ctx, window, MOST_CLIPS)
        if (picks.size + clips.size < 4) return null
        stage("Making the film…")
        // Photos become short clips; everything in the order it happened.
        val moments = ArrayList<Pair<Long, Uri>>()
        picks.forEachIndexed { i, f ->
            Reels.photoClip(ctx, Uri.parse(f.id))?.let { moments += f.created to Uri.fromFile(it) }
            progress(0.35 + 0.35 * (i + 1) / picks.size)
        }
        clips.forEach { moments += it.created to it.uri }
        val ordered = moments.sortedBy { it.first }.map { it.second }
        if (ordered.size < 4) return null
        return Reels.make(ctx, ordered, STYLE) { p -> progress(0.7 + 0.3 * p) }
    }
}

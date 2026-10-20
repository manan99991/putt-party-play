package com.handytools.app.tools.lens

/** The gist: a frequency-based extractive summary that keeps the most informative sentences in their
 *  original order. No model needed, so it runs on every phone. */
object LensEngine {
    fun gist(text: String, maxSentences: Int = 4): String {
        val sentences = text.split(Regex("(?<=[.!?])\\s+")).map { it.trim() }.filter { it.length > 15 }
        if (sentences.size <= maxSentences) return sentences.joinToString("\n") { "• $it" }
        val freq = text.lowercase().split(Regex("[^a-z0-9]+")).filter { it.length > 3 }
            .groupingBy { it }.eachCount()
        val top = sentences
            .map { s -> s to s.lowercase().split(Regex("[^a-z0-9]+")).sumOf { freq[it] ?: 0 } }
            .sortedByDescending { it.second }
            .take(maxSentences)
            .map { it.first }
            .toSet()
        return sentences.filter { it in top }.joinToString("\n") { "• $it" }
    }
}

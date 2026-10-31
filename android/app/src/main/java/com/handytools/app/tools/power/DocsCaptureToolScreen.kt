package com.handytools.app.tools.power

import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import com.handytools.app.ui.PowerToolPage

/**
 * Capture + Documents, combined into one tool with five tabs. Capture is tab 0; the four Documents
 * panels (Scan / Sign & fill / Merge & split / Word Finder) are tabs 1-4. State is hoisted here so
 * switching tabs never loses a capture, the scanned pages, a placed signature, or the picked files.
 * Every panel is the existing composable, unchanged — only the host screen is new.
 */
@Composable
fun DocsCaptureToolScreen() {
    var tab by remember { mutableIntStateOf(0) }
    val scan = remember { DocScanState() }
    val sign = remember { DocSignState() }
    val merge = remember { DocMergeState() }
    val finder = remember { DocFinderState() }
    PowerToolPage("docs", listOf("Capture", "Scan", "Sign & fill", "Merge & split", "Word Finder"), tab, { tab = it }) {
        when (tab) {
            0 -> CapturePanel()
            1 -> DocScanPanel(scan)
            2 -> DocSignPanel(sign)
            3 -> DocMergePanel(merge)
            else -> DocFinderPanel(finder)
        }
    }
}

package com.handytools.app.ui

import androidx.activity.compose.LocalOnBackPressedDispatcherOwner
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.handytools.app.ads.BannerAd

/**
 * The approved power-tool page (HTML prototype v5): a hero band with the tool's card art, the
 * claymorphic icon + name + blurb over it, an optional scrolling tab strip, then a scrolling body.
 * Every tool page uses this so they all look identical.
 */
@OptIn(ExperimentalLayoutApi::class)
@Composable
fun PowerToolPage(
    route: String,
    tabs: List<String> = emptyList(),
    selected: Int = 0,
    onTab: (Int) -> Unit = {},
    tabIcons: List<androidx.compose.ui.graphics.vector.ImageVector>? = null,
    // When a tool passes a per-mode colour, the page backdrop eases to it — so the background visibly
    // "syncs" with whatever sub-tool is open. Null keeps the tool's single signature tint.
    accent: Color? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    // Resolve this screen's own metadata. Fall back to a route-named header (no icon/art) rather than
    // the first grid tool, so a folded-in route never borrows another tool's title/icon/about.
    val tool = ALL_TOOLS.firstOrNull { it.route == route }
        ?: HTool(route, route.replaceFirstChar { it.uppercase() }, "", 0, 0)
    val back = LocalOnBackPressedDispatcherOwner.current
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        // Top bar: a clear, always-tappable back arrow, then the tool's icon and name on one line.
        // Kept on its own row so the back control and the title can never overlap or merge.
        Row(
            Modifier.fillMaxWidth().statusBarsPadding()
                .padding(start = 4.dp, end = HandyTokens.Gutter, top = 4.dp, bottom = 2.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            IconButton(
                onClick = { back?.onBackPressedDispatcher?.onBackPressed() },
                modifier = Modifier.size(44.dp).semantics { contentDescription = "Back" }
            ) { Icon(Icons.AutoMirrored.Outlined.ArrowBack, "Back", tint = MaterialTheme.colorScheme.onBackground) }
            if (tool.iconRes != 0) {
                Image(painterResource(tool.iconRes), null, Modifier.size(30.dp))
                Spacer(Modifier.width(10.dp))
            }
            Text(
                tool.name, color = MaterialTheme.colorScheme.onBackground,
                style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.ExtraBold, maxLines = 1
            )
        }
        Box(Modifier.weight(1f)) {
            // Soft half-gradient in the tool's own signature colour — a professional wash over the top of
            // the page that melts into the background by mid-screen, so every tool's page clearly belongs
            // to THAT tool without a busy photo. Two soft glows (one top-centre, one offset) give it depth.
            // A per-mode accent eases in over 450ms so the backdrop tracks the active sub-tool.
            val tint by animateColorAsState(accent ?: toolTint(route), animationSpec = tween(450), label = "toolTint")
            Box(
                Modifier.fillMaxWidth().fillMaxHeight(0.52f).align(Alignment.TopCenter)
                    .background(
                        Brush.verticalGradient(
                            0f to tint.copy(alpha = 0.20f),
                            0.45f to tint.copy(alpha = 0.07f),
                            1f to Color.Transparent
                        )
                    )
            )
            Box(
                Modifier.fillMaxWidth().fillMaxHeight(0.4f).align(Alignment.TopCenter)
                    .background(
                        Brush.radialGradient(
                            colors = listOf(tint.copy(alpha = 0.14f), Color.Transparent),
                            center = androidx.compose.ui.geometry.Offset(Float.POSITIVE_INFINITY, 0f),
                            radius = 700f
                        )
                    )
            )
            // imePadding keeps the focused field above the keyboard; verticalScroll brings any lower
            // control into view so the keyboard never covers where you're typing.
            Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState()).imePadding()) {
                // What the tool does — full text, never chopped.
                if (tool.about.isNotEmpty()) {
                    Text(
                        tool.about, style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary,
                        modifier = Modifier.padding(horizontal = HandyTokens.Gutter).padding(top = 2.dp, bottom = 12.dp)
                    )
                }
                if (tabs.isNotEmpty()) {
                    // FlowRow wraps the option chips onto as many lines as needed — every option is on
                    // the page at once, no horizontal scrolling to discover hidden tabs.
                    FlowRow(
                        Modifier.fillMaxWidth().padding(horizontal = HandyTokens.Gutter).padding(bottom = 10.dp),
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp)
                    ) {
                        tabs.forEachIndexed { i, t -> HChip(t, selected = i == selected, leading = tabIcons?.getOrNull(i)) { onTab(i) } }
                    }
                }
                Column(Modifier.fillMaxWidth().padding(horizontal = HandyTokens.Gutter).padding(bottom = 20.dp), content = content)
            }
        }
        BannerAd()
    }
}

/** Each tool's signature colour, used for the soft page backdrop so every tool's page has its own
 *  professional tint. Drawn from the tool's card art / identity. */
fun toolTint(route: String): Color = when (route) {
    "fileviewer" -> Color(0xFF2B68FF)   // blue
    "docs" -> Color(0xFF3B82F6)         // blue
    "media" -> Color(0xFF8B5CF6)        // violet
    "cleanup" -> Color(0xFF10B981)      // emerald
    "converter" -> Color(0xFF06B6D4)    // cyan
    "instruments" -> Color(0xFFF43F5E)  // rose
    "safety" -> Color(0xFF22C55E)       // green
    "share" -> Color(0xFF3B82F6)        // blue
    "codes" -> Color(0xFF6366F1)        // indigo
    "scrubber" -> Color(0xFF14B8A6)     // teal
    "flashlight" -> Color(0xFFF59E0B)   // amber
    "network" -> Color(0xFF0891B2)      // cyan
    "voice" -> Color(0xFFEF4444)        // red
    "translate" -> Color(0xFF8B5CF6)    // violet
    "memory" -> Color(0xFFD97706)       // amber
    "sorted" -> Color(0xFF0EA5E9)       // sky
    "receipts" -> Color(0xFFEA580C)     // orange
    "scancsv" -> Color(0xFF4F46E5)      // indigo
    "lens" -> Color(0xFF0D9488)         // teal
    "identify" -> Color(0xFF9333EA)     // purple
    "gpsdash" -> Color(0xFF0284C7)      // sky blue
    else -> HandyColors.Accent
}

/** Small uppercase section label, like the prototype's .lbl */
@Composable
fun SectionLabel(text: String) {
    Text(
        text.uppercase(), style = MaterialTheme.typography.labelSmall, color = Handy.palette.textSecondary,
        modifier = Modifier.padding(top = 12.dp, bottom = 6.dp, start = 2.dp)
    )
}

/** Muted explanatory footnote, like the prototype's .note */
@Composable
fun NoteText(text: String) {
    Text(text, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(top = 12.dp))
}

/** "Runs natively" / status pill, like the prototype's .tag */
@Composable
fun Pill(text: String, tint: Color = HandyColors.Accent) {
    Text(
        text, style = MaterialTheme.typography.labelSmall, color = tint,
        modifier = Modifier.padding(bottom = 8.dp).clip(RoundedCornerShape(50)).background(tint.copy(alpha = 0.16f)).padding(horizontal = 9.dp, vertical = 3.dp)
    )
}

/** The empty "pick something" preview box, like the prototype's .preview */
@Composable
fun PreviewBox(modifier: Modifier = Modifier, minHeight: androidx.compose.ui.unit.Dp = 170.dp, content: @Composable () -> Unit) {
    Box(
        modifier.fillMaxWidth().height(minHeight).clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.surface)
            .border(1.dp, Handy.palette.border, RoundedCornerShape(16.dp)),
        contentAlignment = Alignment.Center
    ) { content() }
}

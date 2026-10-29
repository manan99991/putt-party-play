package com.handytools.app.ui

import androidx.activity.compose.LocalOnBackPressedDispatcherOwner
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
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
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.handytools.app.ads.BannerAd

/**
 * The approved power-tool page (HTML prototype v5): a hero band with the tool's card art, the
 * claymorphic icon + name + blurb over it, an optional scrolling tab strip, then a scrolling body.
 * Every one of the 10 tools uses this so they look identical.
 */
@Composable
fun PowerToolPage(
    route: String,
    tabs: List<String> = emptyList(),
    selected: Int = 0,
    onTab: (Int) -> Unit = {},
    content: @Composable ColumnScope.() -> Unit,
) {
    val tool = TOOLS.firstOrNull { it.route == route } ?: TOOLS.first()
    val back = LocalOnBackPressedDispatcherOwner.current
    Column(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState())) {
            // Hero
            Box(Modifier.fillMaxWidth().aspectRatio(1290f / 480f)) {
                Image(painterResource(tool.cardRes), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
                Box(
                    Modifier.fillMaxSize().background(
                        // The card art is dark, so the hero stays dark in light mode too; the body
                        // below uses the theme background like a normal header-image layout.
                        Brush.verticalGradient(
                            0f to Color(0x26070710), 0.6f to Color(0x40070710), 1f to Color(0xF2070710)
                        )
                    )
                )
                Row(Modifier.statusBarsPadding().padding(start = 8.dp, top = 4.dp)) {
                    IconButton(
                        onClick = { back?.onBackPressedDispatcher?.onBackPressed() },
                        modifier = Modifier.size(40.dp).clip(RoundedCornerShape(12.dp)).background(Color(0xCC14141F))
                    ) { Icon(Icons.AutoMirrored.Outlined.ArrowBack, "Back", tint = Color.White) }
                }
                Row(
                    Modifier.align(Alignment.BottomStart).padding(start = 16.dp, bottom = 10.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Image(painterResource(tool.iconRes), null, Modifier.size(50.dp))
                    Spacer(Modifier.width(12.dp))
                    Column {
                        Text(tool.name, color = Color.White, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.ExtraBold)
                        Text(tool.blurb, color = Color(0xFF9A9AB0), style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
            if (tabs.isNotEmpty()) {
                Row(
                    Modifier.fillMaxWidth().horizontalScroll(rememberScrollState())
                        .padding(horizontal = HandyTokens.Gutter, vertical = 10.dp),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    tabs.forEachIndexed { i, t -> HChip(t, selected = i == selected) { onTab(i) } }
                }
            } else Spacer(Modifier.height(10.dp))
            Column(Modifier.fillMaxWidth().padding(horizontal = HandyTokens.Gutter).padding(bottom = 40.dp), content = content)
        }
        BannerAd()
    }
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
        modifier.fillMaxWidth().height(minHeight).clip(RoundedCornerShape(16.dp)).background(MaterialTheme.colorScheme.surface),
        contentAlignment = Alignment.Center
    ) { content() }
}

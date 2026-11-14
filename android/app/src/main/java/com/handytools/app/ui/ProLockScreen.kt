package com.handytools.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ArrowBack
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

/** The unlock screen a free user lands on when they open a Pro tool — iPhone-style: it names the
 *  tool, says it's part of Pro, and offers the one upgrade that unlocks every Pro tool. Never a
 *  dead end: "Not now" takes them straight back. */
@Composable
fun ProLockScreen(route: String, onBack: () -> Unit, onPro: () -> Unit) {
    val tool = (TOOLS + SCANSORT_TOOLS + MORE_TOOLS).firstOrNull { it.route == route }
    val name = tool?.name ?: "This tool"
    Box(Modifier.fillMaxSize().background(MaterialTheme.colorScheme.background)) {
        IconButton(onClick = onBack, modifier = Modifier.align(Alignment.TopStart).statusBarsPadding().padding(4.dp)) {
            Icon(Icons.Outlined.ArrowBack, "Back", tint = MaterialTheme.colorScheme.onBackground)
        }
        Column(
            Modifier.align(Alignment.Center).fillMaxWidth().padding(HandyTokens.Gutter),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(HandyTokens.Space16)
        ) {
            Box(Modifier.size(76.dp).background(Handy.palette.accentSoft, CircleShape), contentAlignment = Alignment.Center) {
                Icon(Icons.Outlined.Lock, null, tint = HandyColors.Accent, modifier = Modifier.size(34.dp))
            }
            Text("$name is a Pro tool", style = MaterialTheme.typography.headlineSmall, textAlign = TextAlign.Center)
            Text(
                "Go Pro to unlock it and every other Pro tool — no ads, no daily limits, and unlimited tools you build yourself.",
                style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary, textAlign = TextAlign.Center
            )
            HPrimaryButton("Go Pro — \$19.99 a year", onClick = onPro)
            TextButton(onClick = onBack) { Text("Not now") }
        }
    }
}

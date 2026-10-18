package com.handytools.app.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Bolt
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

/** Temporary placeholder for tools being ported to Android. Never shipped to Play until replaced. */
@Composable
fun ComingSoonScreen(name: String) {
    Box(Modifier.fillMaxSize().padding(HandyTokens.Space24), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(HandyTokens.Space12)) {
            Box(Modifier.size(64.dp).background(Handy.palette.accentSoft, CircleShape), contentAlignment = Alignment.Center) {
                Icon(Icons.Outlined.Bolt, null, tint = HandyColors.Accent, modifier = Modifier.size(30.dp))
            }
            Text(name, style = MaterialTheme.typography.headlineSmall)
            Text("Coming to Android in the next update.", style = MaterialTheme.typography.bodyMedium,
                color = Handy.palette.textSecondary, textAlign = TextAlign.Center)
        }
    }
}

package com.handytools.app.ui

import android.content.Context
import android.content.Intent
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp

private val Blue = Color(0xFF1F5EFF)

@Composable
fun HandyTheme(content: @Composable () -> Unit) {
    val dark = isSystemInDarkTheme()
    val scheme = if (dark) darkColorScheme(primary = Blue, background = Color(0xFF0E0E12), surface = Color(0xFF16161C))
    else lightColorScheme(primary = Blue, background = Color(0xFFF6F7FB), surface = Color.White)
    MaterialTheme(colorScheme = scheme, content = content)
}

/** Inline card that explains one missing permission and jumps straight to the right Settings page. */
@Composable
fun PermissionCard(title: String, why: String, granted: Boolean, intent: Intent, buttonText: String = "Allow") {
    if (granted) return
    val ctx: Context = LocalContext.current
    Card(
        Modifier.fillMaxWidth().padding(bottom = 12.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.errorContainer)
    ) {
        Column(Modifier.padding(16.dp)) {
            Text(title, style = MaterialTheme.typography.titleMedium)
            Spacer(Modifier.height(4.dp))
            Text(why, style = MaterialTheme.typography.bodyMedium)
            Spacer(Modifier.height(12.dp))
            Button(onClick = { ctx.startActivity(intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)) }) { Text(buttonText) }
        }
    }
}

@Composable
fun ToolHeader(title: String, subtitle: String) {
    Column(Modifier.padding(bottom = 16.dp)) {
        Text(title, style = MaterialTheme.typography.headlineMedium)
        Text(subtitle, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

@Composable
fun BigToggle(label: String, on: Boolean, onToggle: (Boolean) -> Unit) {
    Row(
        Modifier.fillMaxWidth().padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically
    ) {
        Text(label, style = MaterialTheme.typography.titleMedium)
        Spacer(Modifier.width(8.dp))
        androidx.compose.material3.Switch(checked = on, onCheckedChange = onToggle)
    }
}

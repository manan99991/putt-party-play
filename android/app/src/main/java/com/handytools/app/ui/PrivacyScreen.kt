package com.handytools.app.ui

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Block
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp

/** The privacy policy, written to be read: what stays, what leaves, in two lists. Same text is hosted at PRIVACY_URL. */
@Composable
fun PrivacyScreen() {
    Column(Modifier.fillMaxSize().statusBarsPadding().verticalScroll(rememberScrollState()).navigationBarsPadding().padding(horizontal = HandyTokens.Gutter)) {
        Spacer(Modifier.height(HandyTokens.Space16))
        Text("Privacy", style = MaterialTheme.typography.headlineMedium)
        Spacer(Modifier.height(HandyTokens.Space4))
        Text("Short version: everything you do in Tenzy stays on this phone.", style = MaterialTheme.typography.bodyLarge, color = Handy.palette.textSecondary)
        Spacer(Modifier.height(HandyTokens.Space24))

        Block("Stays on your phone", true, listOf(
            "Text you copy while Multi-Clipboard is on",
            "Screenshots and screen text you capture (saved to Pictures/Tenzy)",
            "Alarms you set",
            "Notifications, for 7 days, while Notification Log is on",
            "Your scratchpad note",
        ), "Stored in the app's private storage. Deleting the app deletes all of it. We can't see it; there is no server.")

        Block("Never collected", true, listOf(
            "Your name, email, or any account — there isn't one",
            "Passwords (Accessibility is told to ignore password fields)",
            "Your location, contacts, photos, or files",
            "Analytics or crash reports — Tenzy has none",
        ), null)

        Block("The one exception: ads", false, listOf(
            "The free version shows ads through Google AdMob.",
            "AdMob may use your phone's advertising ID and basic device info to pick and count ads, under Google's privacy policy.",
            "You can reset or delete that ID in Android Settings › Google › Ads.",
            "Pro removes the ads and the ad code doesn't run.",
        ), null)

        Block("Payments", false, listOf("Pro is $9.99 a year, billed by Google Play. We never see your card."), null)
        Block("Permissions", false, listOf(
            "Each one is asked for by the tool that needs it, with the reason next to the switch.",
            "Accessibility: Multi-Clipboard and full-page screenshots only.",
            "Notification access: Notification Log only.",
            "Draw over other apps: the floating buttons.",
        ), null)
        Block("Children", false, listOf("Tenzy isn't for children under 13 and doesn't knowingly collect anything from them."), null)
        Text("Questions: $SUPPORT_EMAIL · Last updated October 15, 2026", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
        Spacer(Modifier.height(HandyTokens.Space32))
    }
}

@Composable
private fun Block(title: String, checks: Boolean, lines: List<String>, note: String?) {
    Text(title, style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold))
    Spacer(Modifier.height(HandyTokens.Space8))
    lines.forEach {
        Row(Modifier.padding(vertical = 4.dp), verticalAlignment = Alignment.Top) {
            if (checks) Icon(Icons.Outlined.CheckCircle, null, Modifier.size(18.dp).padding(top = 2.dp), tint = HandyColors.Accent)
            else Icon(Icons.Outlined.Block, null, Modifier.size(18.dp).padding(top = 2.dp), tint = Handy.palette.textSecondary)
            Spacer(Modifier.width(HandyTokens.Space8))
            Text(it, style = MaterialTheme.typography.bodyMedium)
        }
    }
    if (note != null) Text(note, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(top = 4.dp))
    Spacer(Modifier.height(HandyTokens.Space24))
}

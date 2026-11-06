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
import androidx.compose.foundation.layout.offset
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
        Spacer(Modifier.height(HandyTokens.Space8))
        BackArrow(Modifier.offset(x = (-12).dp))
        Text("Privacy", style = MaterialTheme.typography.headlineMedium)
        Spacer(Modifier.height(HandyTokens.Space4))
        Text("Short version: everything you do in Tenzy stays on this phone.", style = MaterialTheme.typography.bodyLarge, color = Handy.palette.textSecondary)
        Spacer(Modifier.height(HandyTokens.Space24))

        Block("Stays on your phone", true, listOf(
            "Photos, videos, PDFs and files you open in a tool, and the results, until you save or share them yourself",
            "Scans, extracted text, receipts, warranties and invoices you make",
            "Voice recordings and transcripts, only when you tap record",
            "Screenshots Memory indexes (the index is built and kept on your phone)",
            "Alarms, clips, notes and your settings",
            "Notifications, for 7 days, while Notification Log is on",
        ), "Stored in the app's private storage. Deleting the app deletes all of it. We can't see it; there is no server.")

        Block("Never collected", true, listOf(
            "Your name, email, or any account — there isn't one",
            "Analytics, tracking of what you do inside the app, or crash reports — Tenzy has none",
            "Your contacts, location, photos or recordings: they are used on your phone to do the job you asked for and are never sent to us",
        ), null)

        Block("The one exception: ads", false, listOf(
            "The free version shows ads through Google AdMob.",
            "AdMob may use your phone's advertising ID and basic device info to pick and count ads, under Google's privacy policy.",
            "You can reset or delete that ID in Android Settings › Google › Ads.",
            "Pro removes the ads and the ad code doesn't run.",
        ), null)

        Block("Payments", false, listOf("Pro is $19.99 a year, billed by Google Play. We never see your card."), null)
        Block("Permissions", false, listOf(
            "Each one is asked for by the tool that needs it, with the reason next to the switch.",
            "Camera: scanning, codes, Pro Camera, Identify, Color Vision. Microphone: Voice, Hearing Boost, Rest, sound meter.",
            "Contacts: Clean Up tidies duplicate contacts, only when you open it. Location: compass, GPS Dashboard, Where I Parked and Wi-Fi tools. It stays on your phone.",
            "Photos and videos: the tools you pick media in. NFC: reading tags in Codes.",
            "Draw over other apps: the floating buttons (clipboard, screenshot, scratchpad). Notification access: Notification Log only.",
            "Tenzy uses no Accessibility service.",
        ), null)
        Block("Network use", false, listOf(
            "See & Read downloads a web page only when you paste its link.",
            "The speed test downloads a test file from Cloudflare (speed.cloudflare.com) only when you tap start, so Cloudflare sees your IP address like any website you visit.",
            "Network device scans stay on your own Wi-Fi.",
            "Ads and purchases, as described above.",
        ), null)
        Block("Children", false, listOf("Tenzy isn't for children under 13 and doesn't knowingly collect anything from them."), null)
        Text("Questions: $SUPPORT_EMAIL · Last updated November 5, 2026", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
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

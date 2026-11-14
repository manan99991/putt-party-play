package com.handytools.app.ui

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.widget.Toast
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.Check
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.Mail
import androidx.compose.material.icons.outlined.Star
import androidx.compose.material.icons.outlined.Tune
import androidx.compose.material.icons.outlined.WorkspacePremium
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import com.handytools.app.BuildConfig
import com.handytools.app.HandyApp
import com.handytools.app.ads.BannerAd

const val PRIVACY_URL = "https://manan99991.github.io/tenzy/privacy.html"
const val SUPPORT_EMAIL = "tenzy.app@gmail.com"

@Composable
fun SettingsScreen(onOpen: (String) -> Unit) {
    val ctx = LocalContext.current
    val premium by HandyApp.instance.billing.isPremium.collectAsState()
    var showAbout by remember { mutableStateOf(false) }

    if (showAbout) AboutDialog(onDismiss = { showAbout = false })

    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = HandyTokens.Gutter)) {
            Spacer(Modifier.height(HandyTokens.Space8))
            Text("Settings", style = MaterialTheme.typography.headlineMedium)
            Spacer(Modifier.height(HandyTokens.Space16))

            // Pro card
            HCard(Modifier.fillMaxWidth(), onClick = { if (!premium) onOpen("paywall") }) {
                Row(Modifier.padding(HandyTokens.Space16), verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(44.dp).background(if (premium) HandyColors.Accent else Handy.palette.accentSoft, CircleShape), contentAlignment = Alignment.Center) {
                        Icon(Icons.Outlined.WorkspacePremium, null, tint = if (premium) Color.White else HandyColors.Accent)
                    }
                    Spacer(Modifier.width(HandyTokens.Space12))
                    Column(Modifier.weight(1f)) {
                        Text(if (premium) "Tenzy Pro" else "Go Pro", style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.SemiBold))
                        Text(if (com.handytools.app.BuildConfig.INTERNAL_UNLOCK) "Internal testing build — everything unlocked, no ads, no limits." else if (premium) "Ads off. Renews yearly at $19.99." else "$19.99 a year. Ads gone, unlimited use of every tool.",
                            style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                    }
                    if (!premium) Icon(Icons.Outlined.ChevronRight, null, tint = Handy.palette.textSecondary)
                }
            }
            if (premium && !com.handytools.app.BuildConfig.INTERNAL_UNLOCK) {
                HTextButton("Manage subscription") {
                    ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/account/subscriptions?sku=tenzy_pro_yearly&package=${ctx.packageName}")))
                }
            }

            Spacer(Modifier.height(HandyTokens.Space24))
            SettingsSectionLabel("Appearance")
            Text("Theme", style = MaterialTheme.typography.bodyLarge)
            Spacer(Modifier.height(HandyTokens.Space4))
            Text(if (premium) "Tap to switch — applies instantly." else "Aurora is free; the rest come with Pro.",
                style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
            Spacer(Modifier.height(HandyTokens.Space12))
            ThemePicker(premium) { onOpen("paywall") }

            Spacer(Modifier.height(HandyTokens.Space24))
            SettingsSectionLabel("What Tenzy does")
            Text("Every tool in one place — tap any to open it. It all runs on your phone.",
                style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
            Spacer(Modifier.height(HandyTokens.Space8))
            TOOLS.forEach { t -> MapRow(t.name, t.blurb) { onOpen(t.route) } }

            Spacer(Modifier.height(HandyTokens.Space24))
            SettingsSectionLabel("App")
            SettingsRow(Icons.Outlined.Tune, "Permissions", "Manage camera, photos, contacts & more in Android Settings") {
                ctx.startActivity(
                    Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${ctx.packageName}"))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                )
            }
            SettingsRow(Icons.Outlined.Lock, "Privacy", "What stays on your phone (everything)") { onOpen("privacy") }

            Spacer(Modifier.height(HandyTokens.Space24))
            SettingsSectionLabel("Help")
            SettingsRow(Icons.Outlined.Mail, "Send feedback", SUPPORT_EMAIL) {
                ctx.startActivity(Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:$SUPPORT_EMAIL?subject=Tenzy%20Android%20${BuildConfig.VERSION_NAME}")))
            }
            SettingsRow(Icons.Outlined.Star, "Rate Tenzy", "30 seconds, means a lot") {
                ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=${ctx.packageName}")))
            }
            SettingsRow(Icons.Outlined.Info, "About", "Version ${BuildConfig.VERSION_NAME} · Made by one person in Illinois") { showAbout = true }

            Spacer(Modifier.height(HandyTokens.Space24))
        }
        BannerAd()
    }
}

/** One line in the "What Tenzy does" map: the tool's name and what it's for, tappable to open it. */
@Composable
private fun MapRow(name: String, blurb: String, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clip(androidx.compose.foundation.shape.RoundedCornerShape(12.dp))
            .clickable { onClick() }.padding(vertical = HandyTokens.Space12),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Column(Modifier.weight(1f)) {
            Text(name, style = MaterialTheme.typography.bodyLarge)
            Text(blurb, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
        }
        Icon(Icons.Outlined.ChevronRight, null, tint = Handy.palette.textSecondary)
    }
}

@Composable
private fun AboutDialog(onDismiss: () -> Unit) {
    val ctx = LocalContext.current
    // Build number is the surest way to confirm which build you're actually running.
    val version = "${BuildConfig.VERSION_NAME} (${BuildConfig.VERSION_CODE})"
    val details = "Tenzy $version\n${Build.MANUFACTURER} ${Build.MODEL} · Android ${Build.VERSION.RELEASE}"
    AlertDialog(
        onDismissRequest = onDismiss,
        icon = { Icon(Icons.Outlined.Info, null, tint = HandyColors.Accent) },
        title = { Text("Tenzy") },
        text = {
            Column {
                Text("Version $version", style = MaterialTheme.typography.bodyLarge)
                Spacer(Modifier.height(HandyTokens.Space4))
                Text("${Build.MANUFACTURER.replaceFirstChar { it.uppercase() }} ${Build.MODEL} · Android ${Build.VERSION.RELEASE}",
                    style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                Spacer(Modifier.height(HandyTokens.Space12))
                Text("Made by one person in Illinois. Every tool runs on your phone — nothing is uploaded.",
                    style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary)
            }
        },
        confirmButton = { TextButton(onClick = onDismiss) { Text("Close") } },
        dismissButton = {
            TextButton(onClick = {
                val cb = ctx.getSystemService(Context.CLIPBOARD_SERVICE) as? ClipboardManager
                cb?.setPrimaryClip(ClipData.newPlainText("Tenzy", details))
                Toast.makeText(ctx, "Copied — paste it into your feedback email", Toast.LENGTH_SHORT).show()
            }) { Text("Copy details") }
        }
    )
}

@OptIn(androidx.compose.foundation.layout.ExperimentalLayoutApi::class)
@Composable
private fun ThemePicker(premium: Boolean, onLockedTap: () -> Unit) {
    val ctx = LocalContext.current
    val current = ThemeStore.selected.value ?: ThemeStore.load(ctx)
    androidx.compose.foundation.layout.FlowRow(
        horizontalArrangement = Arrangement.spacedBy(HandyTokens.Space12),
        verticalArrangement = Arrangement.spacedBy(HandyTokens.Space12)
    ) {
        TenzyTheme.entries.forEach { th ->
            val selected = th == current
            val locked = th.isPro && !premium
            // The whole tile (swatch + its name/blurb) is one tap target, so tapping the label works too.
            Column(
                Modifier.width(100.dp)
                    .clip(androidx.compose.foundation.shape.RoundedCornerShape(12.dp))
                    .clickable { HandyHaptics.light(ctx); if (locked) onLockedTap() else ThemeStore.set(ctx, th) }
                    .semantics(mergeDescendants = true) {
                        contentDescription = th.title + " theme" +
                            if (selected) ", selected" else if (locked) ", Pro — tap to unlock" else ", tap to apply"
                    }
            ) {
                Box(
                    Modifier.fillMaxWidth().height(58.dp)
                        .clip(androidx.compose.foundation.shape.RoundedCornerShape(12.dp))
                        .background(androidx.compose.ui.graphics.Brush.linearGradient(th.swatch))
                        .border(
                            if (selected) 2.5.dp else 1.dp,
                            if (selected) HandyColors.Accent else Handy.palette.border,
                            androidx.compose.foundation.shape.RoundedCornerShape(12.dp)
                        ),
                    contentAlignment = Alignment.Center
                ) {
                    when {
                        selected -> Icon(Icons.Outlined.Check, "Selected", tint = Color.White)
                        locked -> Icon(Icons.Outlined.Lock, "Pro", tint = Color.White.copy(alpha = 0.9f), modifier = Modifier.size(18.dp))
                        else -> {}
                    }
                }
                Spacer(Modifier.height(HandyTokens.Space4))
                Text(th.title, style = MaterialTheme.typography.labelMedium, maxLines = 1,
                    color = if (selected) HandyColors.Accent else MaterialTheme.colorScheme.onSurface)
                Text(if (th.isPro && !premium) "Pro" else th.blurb, style = MaterialTheme.typography.labelSmall,
                    color = Handy.palette.textSecondary, maxLines = 1,
                    overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis)
            }
        }
    }
}

@Composable
private fun SettingsSectionLabel(t: String) {
    Text(t.uppercase(), style = MaterialTheme.typography.labelSmall, color = Handy.palette.textSecondary, modifier = Modifier.padding(bottom = HandyTokens.Space8))
}

@Composable
private fun SettingsRow(icon: ImageVector, title: String, sub: String, onClick: () -> Unit) {
    Row(Modifier.fillMaxWidth().clickable(onClick = onClick).padding(vertical = HandyTokens.Space12), verticalAlignment = Alignment.CenterVertically) {
        Icon(icon, null, Modifier.size(24.dp), tint = HandyColors.Accent)
        Spacer(Modifier.width(HandyTokens.Space16))
        Column(Modifier.weight(1f)) {
            Text(title, style = MaterialTheme.typography.bodyLarge)
            Text(sub, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
        }
        Icon(Icons.Outlined.ChevronRight, null, tint = Handy.palette.textSecondary)
    }
    Box(Modifier.fillMaxWidth().height(1.dp).background(Handy.palette.border))
}

package com.handytools.app.ui

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
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
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.ChevronRight
import androidx.compose.material.icons.outlined.Info
import androidx.compose.material.icons.outlined.Lock
import androidx.compose.material.icons.outlined.Mail
import androidx.compose.material.icons.outlined.Star
import androidx.compose.material.icons.outlined.Tune
import androidx.compose.material.icons.outlined.WorkspacePremium
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
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

    Column(Modifier.fillMaxSize().statusBarsPadding()) {
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState()).padding(horizontal = HandyTokens.Gutter)) {
            Spacer(Modifier.height(HandyTokens.Space16))
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
                        Text(if (premium) "Ads off. Renews yearly at $9.99." else "$9.99 a year. Ads gone, unlimited clips and alarms.",
                            style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
                    }
                    if (!premium) Icon(Icons.Outlined.ChevronRight, null, tint = Handy.palette.textSecondary)
                }
            }
            if (premium) {
                HTextButton("Manage subscription") {
                    ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/account/subscriptions?sku=tenzy_pro_yearly&package=${ctx.packageName}")))
                }
            }

            Spacer(Modifier.height(HandyTokens.Space24))
            SectionLabel("App")
            SettingsRow(Icons.Outlined.Tune, "Permissions", "See what's on, turn things on or off") { onOpen("setup") }
            SettingsRow(Icons.Outlined.Lock, "Privacy", "What stays on your phone (everything)") { onOpen("privacy") }

            Spacer(Modifier.height(HandyTokens.Space24))
            SectionLabel("Help")
            SettingsRow(Icons.Outlined.Mail, "Send feedback", SUPPORT_EMAIL) {
                ctx.startActivity(Intent(Intent.ACTION_SENDTO, Uri.parse("mailto:$SUPPORT_EMAIL?subject=Tenzy%20Android%20${BuildConfig.VERSION_NAME}")))
            }
            SettingsRow(Icons.Outlined.Star, "Rate Tenzy", "30 seconds, means a lot") {
                ctx.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=${ctx.packageName}")))
            }
            SettingsRow(Icons.Outlined.Info, "About", "Version ${BuildConfig.VERSION_NAME} · Made by one person in Illinois") { }

            Spacer(Modifier.height(HandyTokens.Space24))
        }
        BannerAd()
    }
}

@Composable
private fun SectionLabel(t: String) {
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

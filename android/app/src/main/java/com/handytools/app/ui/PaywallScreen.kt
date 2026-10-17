package com.handytools.app.ui

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.WorkspacePremium
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handytools.app.HandyApp

/** Paywall as a bottom sheet over whatever screen opened it. Honest: price, term, cancel path, no timers. */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PaywallScreen(onBack: () -> Unit) {
    val state = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    ModalBottomSheet(
        onDismissRequest = onBack, sheetState = state,
        containerColor = Handy.palette.surfaceRaised, shape = MaterialTheme.shapes.large
    ) { PaywallContent(onBack) }
}

@Composable
fun PaywallContent(onBack: () -> Unit) {
    val billing = HandyApp.instance.billing
    val premium by billing.isPremium.collectAsState()
    val product by billing.product.collectAsState()
    val activity = LocalContext.current.findActivity()

    Column(Modifier.fillMaxWidth().padding(horizontal = HandyTokens.Space24).padding(bottom = HandyTokens.Space24).navigationBarsPadding(),
        horizontalAlignment = Alignment.CenterHorizontally) {
        Box(Modifier.size(64.dp).background(Handy.palette.accentSoft, CircleShape), contentAlignment = Alignment.Center) {
            Icon(Icons.Outlined.WorkspacePremium, null, Modifier.size(32.dp), tint = HandyColors.Accent)
        }
        Spacer(Modifier.height(HandyTokens.Space16))
        Text("Oddbox Pro", style = MaterialTheme.typography.headlineSmall.copy(fontSize = 28.sp))
        Spacer(Modifier.height(HandyTokens.Space4))
        Text("One yearly payment. Ads gone for good.", style = MaterialTheme.typography.bodyLarge, color = Handy.palette.textSecondary)
        Spacer(Modifier.height(HandyTokens.Space24))
        Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(HandyTokens.Space12)) {
            listOf("No banner or full-screen ads", "Unlimited clipboard history (free: 20)", "Unlimited alarms (free: 3)", "Support one indie developer").forEach {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Outlined.CheckCircle, null, Modifier.size(22.dp), tint = HandyColors.Accent)
                    Spacer(Modifier.width(HandyTokens.Space12))
                    Text(it, style = MaterialTheme.typography.bodyLarge)
                }
            }
        }
        Spacer(Modifier.height(HandyTokens.Space32))
        if (premium) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Outlined.CheckCircle, null, tint = HandyColors.Success)
                Spacer(Modifier.width(HandyTokens.Space8))
                Text("You're Pro. Thank you.", style = MaterialTheme.typography.titleMedium)
            }
        } else {
            HPrimaryButton("Go Pro · ${billing.priceLabel ?: "$9.99 / year"}") { billing.launchPurchase(activity) }
            Spacer(Modifier.height(HandyTokens.Space8))
            Text("$9.99 a year, auto-renews. Cancel anytime in Google Play. Price shown in your currency at checkout.", style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary,
                textAlign = androidx.compose.ui.text.style.TextAlign.Center)
        }
        Spacer(Modifier.height(HandyTokens.Space8))
        HTextButton("Not now", onClick = onBack)
    }
}

/** Dialogs and sheets hand composables a ContextThemeWrapper; walk up to the real Activity. */
private fun Context.findActivity(): Activity {
    var c: Context = this
    while (c is ContextWrapper) { if (c is Activity) return c; c = c.baseContext }
    error("No Activity in context chain")
}

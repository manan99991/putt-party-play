package com.handytools.app.ui

import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import androidx.compose.foundation.BorderStroke
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CheckCircle
import androidx.compose.material.icons.outlined.RadioButtonUnchecked
import androidx.compose.material.icons.filled.CheckCircle
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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
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
    billing.yearly.collectAsState()   // recompose when the prices load
    billing.monthly.collectAsState()
    var pickYearly by androidx.compose.runtime.saveable.rememberSaveable { androidx.compose.runtime.mutableStateOf(true) }
    val activity = LocalContext.current.findActivity()

    Column(Modifier.fillMaxWidth().padding(horizontal = HandyTokens.Space24).padding(bottom = HandyTokens.Space24).navigationBarsPadding(),
        horizontalAlignment = Alignment.CenterHorizontally) {
        Box(Modifier.size(64.dp).background(Handy.palette.accentSoft, CircleShape), contentAlignment = Alignment.Center) {
            Icon(Icons.Outlined.WorkspacePremium, null, Modifier.size(32.dp), tint = HandyColors.Accent)
        }
        Spacer(Modifier.height(HandyTokens.Space16))
        Text(com.handytools.app.I18n.t("Tenzy Pro"), style = MaterialTheme.typography.headlineSmall.copy(fontSize = 28.sp))
        Spacer(Modifier.height(HandyTokens.Space4))
        Text(com.handytools.app.I18n.t("Every helper and every builder step. No ads, no limits."), style = MaterialTheme.typography.bodyLarge, color = Handy.palette.textSecondary)
        Spacer(Modifier.height(HandyTokens.Space24))
        Column(Modifier.fillMaxWidth(), verticalArrangement = Arrangement.spacedBy(HandyTokens.Space12)) {
            listOf("Unlock every tool", "Every Build-your-own step, unlimited saved tools", "No banner or full-screen ads", "No daily limits — build and run freely").forEach {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Outlined.CheckCircle, null, Modifier.size(22.dp), tint = HandyColors.Accent)
                    Spacer(Modifier.width(HandyTokens.Space12))
                    Text(it, style = MaterialTheme.typography.bodyLarge)
                }
            }
        }
        Spacer(Modifier.height(HandyTokens.Space24))
        if (premium) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Outlined.CheckCircle, null, tint = HandyColors.Success)
                Spacer(Modifier.width(HandyTokens.Space8))
                Text(com.handytools.app.I18n.t("You're Pro. Thank you."), style = MaterialTheme.typography.titleMedium)
            }
        } else {
            // Two honest plans, yearly picked first (the same as the iPhone): $2.99 a month or $29.99 a year, each with a
            // 7-day free trial while the person can still have one. Prices are Play's, in the person's currency.
            val yTrial = billing.trialDays(true); val mTrial = billing.trialDays(false)
            val I = com.handytools.app.I18n
            PlanRow(I.t("Yearly"), billing.yearlyPriceShown,
                if (yTrial != null) I.f("%@ free, then %@ a year", billing.daysWords(yTrial), billing.yearlyPriceShown) else I.t("Renews yearly · cancel anytime"),
                billing.yearlySaving?.let { I.f("Save %d%%", it) }, pickYearly) { pickYearly = true }
            Spacer(Modifier.height(HandyTokens.Space8))
            PlanRow(I.t("Monthly"), billing.monthlyPriceShown,
                if (mTrial != null) I.f("%@ free, then %@ a month", billing.daysWords(mTrial), billing.monthlyPriceShown) else I.t("Renews monthly · cancel anytime"),
                null, !pickYearly) { pickYearly = false }
            Spacer(Modifier.height(HandyTokens.Space16))
            val trial = if (pickYearly) yTrial else mTrial
            HPrimaryButton(if (trial != null) I.f("Try Pro free for %@", billing.daysWords(trial))
                           else I.f(if (pickYearly) "Go Pro · %@ a year" else "Go Pro · %@ a month", if (pickYearly) billing.yearlyPriceShown else billing.monthlyPriceShown)) {
                billing.launchPurchase(activity, yearlyPlan = pickYearly)
            }
            Spacer(Modifier.height(HandyTokens.Space8))
            Text(com.handytools.app.I18n.t("Auto-renews until cancelled in Google Play. Price shown in your currency at checkout."), style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary,
                textAlign = androidx.compose.ui.text.style.TextAlign.Center)
        }
        Spacer(Modifier.height(HandyTokens.Space8))
        HTextButton("Not now", onClick = onBack)
    }
}

@Composable
private fun PlanRow(title: String, price: String, caption: String, badge: String?, selected: Boolean, onTap: () -> Unit) {
    Row(
        Modifier.fillMaxWidth()
            .border(BorderStroke(if (selected) 2.dp else 1.dp, if (selected) HandyColors.Accent else Handy.palette.border), RoundedCornerShape(HandyTokens.RadiusInput))
            .clickable { onTap() }
            .padding(HandyTokens.Space16),
        verticalAlignment = Alignment.CenterVertically
    ) {
        Icon(if (selected) Icons.Filled.CheckCircle else Icons.Outlined.RadioButtonUnchecked, null,
            Modifier.size(22.dp), tint = if (selected) HandyColors.Accent else Handy.palette.textSecondary)
        Spacer(Modifier.width(HandyTokens.Space12))
        Column(Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(title, style = MaterialTheme.typography.titleMedium)
                if (badge != null) {
                    Spacer(Modifier.width(HandyTokens.Space8))
                    Box(Modifier.background(HandyColors.Accent, RoundedCornerShape(50)).padding(horizontal = 6.dp, vertical = 2.dp)) {
                        Text(badge, style = MaterialTheme.typography.labelSmall, color = androidx.compose.ui.graphics.Color.White, fontWeight = FontWeight.Bold)
                    }
                }
            }
            Text(caption, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary)
        }
        Text(price, style = MaterialTheme.typography.titleMedium)
    }
}

/** Dialogs and sheets hand composables a ContextThemeWrapper; walk up to the real Activity. */
private fun Context.findActivity(): Activity {
    var c: Context = this
    while (c is ContextWrapper) { if (c is Activity) return c; c = c.baseContext }
    error("No Activity in context chain")
}

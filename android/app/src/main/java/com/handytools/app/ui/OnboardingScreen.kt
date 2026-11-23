package com.handytools.app.ui

import android.content.Context
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.wrapContentHeight
import androidx.compose.ui.platform.testTag
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
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handytools.app.R
import kotlinx.coroutines.delay
import kotlinx.coroutines.launch

object Onboarding {
    private const val PREF = "onboarding"
    fun seen(ctx: Context) = ctx.getSharedPreferences(PREF, 0).getBoolean("seen", false)
    fun markSeen(ctx: Context) = ctx.getSharedPreferences(PREF, 0).edit().putBoolean("seen", true).apply()
}

private val ILLOS = listOf(R.drawable.illo_clipboard, R.drawable.illo_alarm, R.drawable.illo_screenshot, R.drawable.illo_flashlight, R.drawable.illo_sticky, R.drawable.illo_qr)

/** What the welcome's optional "What do you want help with?" offers, and the Home tab each opens (same as iPhone). */
enum class WelcomeChoice(val title: String, val homeTab: String) {
    PHOTOS("Photos and space", "photos"), DOCUMENTS("Documents and PDFs", "pdf"), DAILY("Daily life and health", "day"),
    CAR("Car and travel", "phone"), CONTACTS("Contacts and phone", "phone"), WORDS("Words and messages", "words"),
    BUSINESS("Running a small business", "business");
    companion object {
        /** Running a small business opens the Business tab first; otherwise the first choice in the order shown decides. */
        fun homeTab(picked: Set<WelcomeChoice>): String? =
            if (BUSINESS in picked) "business" else values().firstOrNull { it in picked }?.homeTab
    }
}

/**
 * One welcome screen, shown once (UX audit decision 4, same as the iPhone): what Tenzy is in one line, an optional
 * "What do you want help with?", then Home. No permission prompts here — each tool asks when it's first used.
 * [startPage] and [onSeePro] stay for the old routes; there is one page now and no price talk before the app is used.
 */
@Composable
fun OnboardingScreen(startPage: Int = 0, onDone: () -> Unit, onSeePro: () -> Unit) {
    val ctx = androidx.compose.ui.platform.LocalContext.current
    var picked by remember { androidx.compose.runtime.mutableStateOf(setOf<WelcomeChoice>()) }
    var idx by remember { mutableIntStateOf(0) }
    LaunchedEffect(Unit) { while (true) { delay(2200); idx = (idx + 1) % ILLOS.size } }
    fun finish() {
        if (WelcomeChoice.BUSINESS in picked) HomeShelves.setBusiness(ctx, true)
        WelcomeChoice.homeTab(picked)?.let { ctx.getSharedPreferences(HomeShelves.PREFS, 0).edit().putString(HomeShelves.TAB_KEY, it).apply() }
        onDone()
    }
    androidx.compose.foundation.layout.BoxWithConstraints(Modifier.fillMaxSize().background(HandyColors.Accent)) {
        val tall = maxHeight >= 720.dp
        Column(
            Modifier.fillMaxSize().statusBarsPadding().navigationBarsPadding().padding(horizontal = HandyTokens.Space24, vertical = HandyTokens.Space16),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Row(Modifier.fillMaxWidth()) {
                Spacer(Modifier.weight(1f))
                HTextButtonOn(HandyColors.OnAccent, com.handytools.app.I18n.t("Skip"), Modifier) { finish() }
            }
            // Short phones leave the drawing out so the seven choices and Start still fit.
            if (tall) {
                AnimatedContent(idx, transitionSpec = { fadeIn(tween(400)) togetherWith fadeOut(tween(400)) }, label = "illo") { i ->
                    Image(painterResource(ILLOS[i]), null, Modifier.size(120.dp), colorFilter = androidx.compose.ui.graphics.ColorFilter.tint(HandyColors.OnAccent))
                }
                Spacer(Modifier.height(HandyTokens.Space12))
            }
            Text(com.handytools.app.I18n.t("Everyday jobs, done on your phone"), color = HandyColors.OnAccent, fontSize = 30.sp, lineHeight = 36.sp,
                fontWeight = FontWeight.Bold, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
            Spacer(Modifier.height(HandyTokens.Space8))
            Text(com.handytools.app.I18n.t("Sign a PDF, shrink a video, find your car, remember your pills. Nothing is uploaded."),
                color = HandyColors.OnAccent.copy(alpha = 0.85f), style = MaterialTheme.typography.bodyLarge, textAlign = androidx.compose.ui.text.style.TextAlign.Center)
            Spacer(Modifier.weight(1f))
            Text(com.handytools.app.I18n.t("What do you want help with? (optional)"), color = HandyColors.OnAccent, fontWeight = FontWeight.SemiBold,
                modifier = Modifier.fillMaxWidth())
            Spacer(Modifier.height(HandyTokens.Space8))
            WelcomeChoice.values().toList().chunked(2).forEach { row ->
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    row.forEach { c ->
                        val on = c in picked
                        Text(
                            (if (on) "✓  " else "") + com.handytools.app.I18n.t(c.title), fontSize = 14.sp, fontWeight = FontWeight.SemiBold, maxLines = 2,
                            color = if (on) HandyColors.Accent else HandyColors.OnAccent,
                            modifier = Modifier.weight(1f).height(52.dp)
                                .background(if (on) HandyColors.OnAccent else HandyColors.OnAccent.copy(alpha = 0.10f), androidx.compose.foundation.shape.RoundedCornerShape(14.dp))
                                .border(1.dp, HandyColors.OnAccent.copy(alpha = if (on) 0f else 0.35f), androidx.compose.foundation.shape.RoundedCornerShape(14.dp))
                                .clickable { picked = if (on) picked - c else picked + c }
                                .testTag("welcome-${c.name.lowercase()}")
                                .wrapContentHeight(Alignment.CenterVertically).padding(horizontal = 12.dp),
                        )
                    }
                    if (row.size == 1) Spacer(Modifier.weight(1f))
                }
                Spacer(Modifier.height(8.dp))
            }
            Spacer(Modifier.height(HandyTokens.Space8))
            androidx.compose.material3.Button(
                onClick = { finish() },
                modifier = Modifier.fillMaxWidth().height(HandyTokens.PrimaryButtonHeight).testTag("welcome-start"),
                colors = androidx.compose.material3.ButtonDefaults.buttonColors(containerColor = HandyColors.OnAccent, contentColor = HandyColors.Accent),
            ) { Text(com.handytools.app.I18n.t("Start"), style = MaterialTheme.typography.labelLarge) }
        }
    }
}

@Composable
private fun HTextButtonOn(color: Color, text: String, modifier: Modifier, onClick: () -> Unit) {
    androidx.compose.material3.TextButton(onClick = onClick, modifier = modifier) { Text(text, color = color, style = MaterialTheme.typography.labelLarge) }
}

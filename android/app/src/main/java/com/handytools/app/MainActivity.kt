package com.handytools.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.animation.core.EaseIn
import androidx.compose.animation.core.EaseOut
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.handytools.app.ads.Interstitials
import com.handytools.app.tools.alarm.AlarmListScreen
import com.handytools.app.tools.alarm.AlarmRingPreview
import com.handytools.app.tools.awake.KeepAwakeScreen
import com.handytools.app.tools.clipboard.ClipboardScreen
import com.handytools.app.tools.flashlight.FlashlightScreen
import com.handytools.app.tools.timers.TimersScreen
import com.handytools.app.tools.notifhistory.NotifHistoryScreen
import com.handytools.app.tools.ocr.ScreenTextScreen
import com.handytools.app.tools.quick.QuickButtonsScreen
import com.handytools.app.tools.scratchpad.ScratchpadScreen
import com.handytools.app.tools.screenshot.ScreenshotScreen
import com.handytools.app.tools.shortcut.WebShortcutScreen
import com.handytools.app.tools.volume.VolumeMixerScreen
import com.handytools.app.ui.ComingSoonScreen
import com.handytools.app.ui.HandyTheme
import com.handytools.app.ui.HomeScreen
import com.handytools.app.ui.TOOLS
import com.handytools.app.ui.Onboarding
import com.handytools.app.ui.OnboardingScreen
import com.handytools.app.ui.PrivacyScreen
import com.handytools.app.ui.SettingsScreen
import com.handytools.app.ui.SetupScreen
import com.handytools.app.ui.PaywallScreen

class MainActivity : ComponentActivity() {

    private var sharedUrl by mutableStateOf<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        sharedUrl = extractSharedUrl(intent)
        Interstitials.preload(this)
        val routeExtra = intent.getStringExtra("route")
        if (routeExtra == "homepro") HandyApp.instance.billing.setPreviewPremium(true)
        val startRoute = routeExtra ?: if (sharedUrl != null) "shortcut" else if (!Onboarding.seen(this)) "onboarding" else "home"

        setContent {
            HandyTheme {
                val nav = rememberNavController()
                androidx.compose.runtime.CompositionLocalProvider(com.handytools.app.ads.LocalRemoveAds provides { nav.navigate("paywall") }) {
                NavHost(
                    nav, startDestination = startRoute,
                    // Prompt 1 motion: push = slide-in ~24dp (6% of width) + fade over base
                    // (200ms, ease-out); exit fades (ease-in); pops mirror. Tokens: ui/Motion.kt.
                    enterTransition = { slideInHorizontally(animationSpec = tween(200, easing = EaseOut)) { (it * 0.06f).toInt() } + fadeIn(animationSpec = tween(200, easing = EaseOut)) },
                    exitTransition = { fadeOut(animationSpec = tween(200, easing = EaseIn)) },
                    popEnterTransition = { fadeIn(animationSpec = tween(200, easing = EaseOut)) },
                    popExitTransition = { slideOutHorizontally(animationSpec = tween(200, easing = EaseIn)) { (it * 0.06f).toInt() } + fadeOut(animationSpec = tween(200, easing = EaseIn)) }
                ) {
                    composable("home") { HomeScreen(onOpen = { nav.navigate(it) }) }
                    // CI screenshot route: home in Pro state (no ad strip) for the store split slide.
                    composable("homepro") { HomeScreen(onOpen = { nav.navigate(it) }) }
                    composable("onboarding") { OnboardingScreen(onDone = { Onboarding.markSeen(this@MainActivity); nav.navigate("setup") { popUpTo("onboarding") { inclusive = true } } }, onSeePro = { nav.navigate("paywall") }) }
                    composable("setup") { SetupScreen(onDone = { nav.navigate("home") { popUpTo("setup") { inclusive = true } } }) }
                    composable("settings") { SettingsScreen(onOpen = { nav.navigate(it) }) }
                    composable("privacy") { PrivacyScreen() }
                    composable("onboarding2") { OnboardingScreen(startPage = 1, onDone = { nav.navigate("home") }, onSeePro = { nav.navigate("paywall") }) }
                    composable("onboarding3") { OnboardingScreen(startPage = 2, onDone = { nav.navigate("home") }, onSeePro = { nav.navigate("paywall") }) }
                    composable("paywall") {
                        // Sheet over the home grid; dismissing pops back.
                        HomeScreen(onOpen = { nav.navigate(it) })
                        PaywallScreen(onBack = { if (!nav.popBackStack()) nav.navigate("home") })
                    }
                    composable("clipboard") { ClipboardScreen() }
                    composable("screenshot") { ScreenshotScreen() }
                    composable("quick") { QuickButtonsScreen() }
                    composable("shortcut") { WebShortcutScreen(initialUrl = sharedUrl) }
                    composable("alarm") { AlarmListScreen(onUpgrade = { nav.navigate("paywall") }) }
                    composable("volume") { VolumeMixerScreen() }
                    composable("ocr") { ScreenTextScreen() }
                    composable("notifs") { NotifHistoryScreen() }
                    composable("scratchpad") { ScratchpadScreen() }
                    composable("awake") { KeepAwakeScreen() }
                    composable("flash") { FlashlightScreen() }
                    composable("timer") { TimersScreen() }
                    // New catalog tools not yet ported to Android show a placeholder (never shipped
                    // to Play until real). Existing routes above keep their real screens.
                    val ported = setOf("clipboard", "ocr", "shortcut", "alarm", "scratchpad", "flash", "timer")
                    TOOLS.map { it.route }.filter { it !in ported }.distinct().forEach { r ->
                        composable(r) { ComingSoonScreen(TOOLS.first { it.route == r }.name) }
                    }
                    // CI screenshot route: static ring preview, no alarm or service involved.
                    composable("ring") { AlarmRingPreview() }
                }
                }
            }
        }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        sharedUrl = extractSharedUrl(intent)
    }

    private fun extractSharedUrl(i: Intent?): String? {
        if (i?.action != Intent.ACTION_SEND) return null
        val text = i.getStringExtra(Intent.EXTRA_TEXT) ?: return null
        return Regex("https?://\\S+").find(text)?.value
    }
}

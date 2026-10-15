package com.handytools.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.navigation.compose.NavHost
import androidx.navigation.compose.composable
import androidx.navigation.compose.rememberNavController
import com.handytools.app.ads.Interstitials
import com.handytools.app.tools.alarm.AlarmListScreen
import com.handytools.app.tools.awake.KeepAwakeScreen
import com.handytools.app.tools.clipboard.ClipboardScreen
import com.handytools.app.tools.notifhistory.NotifHistoryScreen
import com.handytools.app.tools.ocr.ScreenTextScreen
import com.handytools.app.tools.quick.QuickButtonsScreen
import com.handytools.app.tools.scratchpad.ScratchpadScreen
import com.handytools.app.tools.screenshot.ScreenshotScreen
import com.handytools.app.tools.shortcut.WebShortcutScreen
import com.handytools.app.tools.volume.VolumeMixerScreen
import com.handytools.app.ui.HandyTheme
import com.handytools.app.ui.HomeScreen
import com.handytools.app.ui.PaywallScreen

class MainActivity : ComponentActivity() {

    private var sharedUrl by mutableStateOf<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        sharedUrl = extractSharedUrl(intent)
        Interstitials.preload(this)
        val startRoute = intent.getStringExtra("route") ?: if (sharedUrl != null) "shortcut" else "home"

        setContent {
            HandyTheme {
                val nav = rememberNavController()
                NavHost(nav, startDestination = startRoute) {
                    composable("home") { HomeScreen(onOpen = { nav.navigate(it) }) }
                    composable("paywall") { PaywallScreen(onBack = { nav.popBackStack() }) }
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

package com.handytools.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.LaunchedEffect
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
import com.handytools.app.tools.shield.ShieldScreen
import com.handytools.app.tools.scancsv.ScanCsvScreen
import com.handytools.app.tools.invoice.QuickInvoiceScreen
import com.handytools.app.tools.voicerec.VoiceRecorderScreen
import com.handytools.app.tools.idphoto.PassportPhotoScreen
import com.handytools.app.tools.redact.RedactScreen
import com.handytools.app.tools.receipts.ReceiptKeeperScreen
import com.handytools.app.tools.gifmaker.GifMakerScreen
import com.handytools.app.tools.sendany.SendAnywhereScreen
import com.handytools.app.tools.parked.ParkedScreen
import com.handytools.app.tools.netscout.NetworkScoutScreen
import com.handytools.app.tools.signfill.DocSignerScreen
import com.handytools.app.tools.hearing.HearingBoostScreen
import com.handytools.app.tools.heartrate.HeartRateScreen
import com.handytools.app.tools.audiocut.AudioCutterScreen
import com.handytools.app.tools.ai.AiScreen
import com.handytools.app.tools.lens.LensScreen
import com.handytools.app.tools.memory.MemoryScreen
import com.handytools.app.tools.sorted.SortedScreen
import com.handytools.app.tools.contacts.ContactsScreen
import com.handytools.app.tools.spaceclean.SpaceCleanerScreen
import com.handytools.app.tools.shrink.ShrinkScreen
import com.handytools.app.tools.storage.StorageScreen
import com.handytools.app.tools.myphone.MyPhoneScreen
import com.handytools.app.tools.texttools.TextToolsScreen
import com.handytools.app.tools.audiotext.AudioToTextScreen
import com.handytools.app.tools.bgremove.BackgroundRemoverScreen
import com.handytools.app.tools.exif.ExifScreen
import com.handytools.app.tools.imgconvert.ImageConverterScreen
import com.handytools.app.tools.magnifier.MagnifierScreen
import com.handytools.app.tools.qr.QRScreen
import com.handytools.app.tools.translate.TranslateScreen
import com.handytools.app.tools.measure.MeasureScreen
import com.handytools.app.tools.pdftools.PDFToolkitScreen
import com.handytools.app.tools.scan.DocScannerScreen
import com.handytools.app.tools.vidcompress.VideoCompressorScreen
import com.handytools.app.tools.timers.TimersScreen
import com.handytools.app.tools.wallet.WalletScreen
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

/** Lets a tool open another tool's route (e.g. Instruments → the folded-in Flashlight). Mirrors
 *  LocalRemoveAds; null when no navigator is in scope. */
val LocalOpenTool = androidx.compose.runtime.staticCompositionLocalOf<((String) -> Unit)?> { null }

class MainActivity : ComponentActivity() {

    private var sharedUrl by mutableStateOf<String?>(null)
    // A file handed to us by another app ("Open with" / share) → opened in the universal File Viewer.
    private var sharedFileUri by mutableStateOf<android.net.Uri?>(null)
    // A route delivered to an already-running activity (singleTop reuse → onNewIntent, e.g. a deep
    // link while the app is open). onCreate handles the cold-start route via startDestination; this
    // state carries a warm route into the composition so it actually navigates instead of being
    // dropped. Observed by a LaunchedEffect inside setContent.
    private var pendingRoute by mutableStateOf<String?>(null)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        sharedUrl = extractSharedUrl(intent)
        sharedFileUri = extractFileUri(intent)
        Interstitials.preload(this)
        val routeExtra = intent.getStringExtra("route")
        // Pro-preview unlock exists ONLY for the CI screenshot capture and is compiled out of
        // release builds, so a crafted intent can never grant entitlement on a shipped app.
        if (routeExtra == "homepro" && com.handytools.app.BuildConfig.DEBUG) HandyApp.instance.billing.setPreviewPremium(true)
        val startRoute = routeExtra ?: if (sharedFileUri != null) "fileviewer" else if (sharedUrl != null) "shortcut" else if (!Onboarding.seen(this)) "onboarding" else "home"

        setContent {
            HandyTheme {
                val nav = rememberNavController()
                androidx.compose.runtime.CompositionLocalProvider(
                    com.handytools.app.ads.LocalRemoveAds provides { nav.navigate("paywall") },
                    LocalOpenTool provides { r: String -> nav.navigate(r) }
                ) {
                // A warm deep link (route delivered via onNewIntent) navigates here. launchSingleTop
                // avoids stacking duplicates when the same route is re-opened.
                LaunchedEffect(pendingRoute) {
                    pendingRoute?.let { r -> nav.navigate(r) { launchSingleTop = true }; pendingRoute = null }
                }
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
                    composable("onboarding") { OnboardingScreen(onDone = { Onboarding.markSeen(this@MainActivity); nav.navigate("home") { popUpTo("onboarding") { inclusive = true } } }, onSeePro = { nav.navigate("paywall") }) }
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
                    composable("shield") { ShieldScreen() }
                    composable("scancsv") { ScanCsvScreen() }
                    composable("invoice") { QuickInvoiceScreen() }
                    composable("voicerec") { VoiceRecorderScreen() }
                    composable("idphoto") { PassportPhotoScreen() }
                    composable("redact") { RedactScreen() }
                    composable("receipts") { ReceiptKeeperScreen() }
                    composable("gifmaker") { GifMakerScreen() }
                    composable("sendany") { SendAnywhereScreen() }
                    // --- Rebuilt 10-power-tool catalog routes (interim targets reuse existing
                    // screens until each merged tool is rebuilt; Capture is first in line). ---
                    // The 10 power tools (rebuilt to the approved prototype)
                    composable("fileviewer") { com.handytools.app.tools.power.FileViewerToolScreen(initialUri = sharedFileUri) }
                    composable("capture") { com.handytools.app.tools.power.CaptureToolScreen() }
                    composable("documents") { com.handytools.app.tools.power.DocumentsToolScreen() }
                    composable("media") { com.handytools.app.tools.power.MediaToolScreen() }
                    composable("cleanup") { com.handytools.app.tools.power.CleanupToolScreen() }
                    composable("voice") { com.handytools.app.tools.power.VoiceToolScreen() }
                    composable("instruments") { com.handytools.app.tools.power.InstrumentsToolScreen() }
                    composable("flashlight") { com.handytools.app.tools.power.FlashlightToolScreen() }
                    composable("safety") { com.handytools.app.tools.power.SafetyToolScreen() }
                    composable("share") { com.handytools.app.tools.power.ShareToolScreen() }
                    composable("parked") { ParkedScreen() }
                    composable("netscout") { NetworkScoutScreen() }
                    composable("signfill") { DocSignerScreen() }
                    composable("hearing") { HearingBoostScreen() }
                    composable("heartrate") { HeartRateScreen() }
                    composable("audiocut") { AudioCutterScreen() }
                    composable("timer") { TimersScreen() }
                    composable("measure") { MeasureScreen() }
                    composable("wallet") { WalletScreen() }
                    composable("imgconvert") { ImageConverterScreen() }
                    composable("audiotext") { AudioToTextScreen() }
                    composable("pdftools") { PDFToolkitScreen() }
                    composable("translate") { com.handytools.app.tools.power.TranslateToolScreen() }
                    composable("exif") { ExifScreen() }
                    composable("scan") { DocScannerScreen() }
                    composable("vidcompress") { VideoCompressorScreen() }
                    composable("qr") { QRScreen() }
                    composable("magnifier") { MagnifierScreen() }
                    composable("bgremove") { BackgroundRemoverScreen() }
                    composable("sorted") { SortedScreen() }
                    composable("memory") { MemoryScreen() }
                    composable("lens") { LensScreen() }
                    composable("contacts") { ContactsScreen() }
                    composable("spaceclean") { SpaceCleanerScreen() }
                    composable("shrink") { ShrinkScreen() }
                    composable("storage") { StorageScreen(onOpen = { nav.navigate(it) }) }
                    composable("myphone") { MyPhoneScreen() }
                    composable("texttools") { TextToolsScreen() }
                    // New catalog tools not yet ported to Android show a placeholder (never shipped
                    // to Play until real). Existing routes above keep their real screens.
                    val ported = setOf("clipboard", "ocr", "shortcut", "alarm", "scratchpad", "flash", "timer", "measure", "wallet", "imgconvert", "audiotext", "pdftools", "translate", "exif", "scan", "vidcompress", "qr", "magnifier", "bgremove", "sorted", "memory", "lens", "contacts", "spaceclean", "shrink", "storage", "myphone", "texttools", "shield", "scancsv", "invoice", "voicerec", "idphoto", "redact", "receipts", "gifmaker", "sendany", "parked", "netscout", "signfill", "hearing", "heartrate", "audiocut", "capture", "documents", "media", "cleanup", "voice", "instruments", "flashlight", "safety", "share", "fileviewer")
                    TOOLS.map { it.route }.filter { it !in ported }.distinct().forEach { r ->
                        composable(r) {
                            if (r.startsWith("ai_")) AiScreen(r)
                            else ComingSoonScreen(TOOLS.first { it.route == r }.name)
                        }
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
        setIntent(intent)
        sharedUrl = extractSharedUrl(intent)
        sharedFileUri = extractFileUri(intent)
        // Honour a route delivered to the already-running activity (deep link / QA route-seeding),
        // which singleTop would otherwise drop. Pro-preview stays debug-only, exactly as in onCreate.
        val routeExtra = intent.getStringExtra("route")
        if (routeExtra == "homepro" && com.handytools.app.BuildConfig.DEBUG) HandyApp.instance.billing.setPreviewPremium(true)
        if (routeExtra != null) pendingRoute = routeExtra
        else if (sharedFileUri != null) pendingRoute = "fileviewer"
        else if (sharedUrl != null) pendingRoute = "shortcut"
    }

    private fun extractSharedUrl(i: Intent?): String? {
        if (i?.action != Intent.ACTION_SEND) return null
        val text = i.getStringExtra(Intent.EXTRA_TEXT) ?: return null
        return Regex("https?://\\S+").find(text)?.value
    }

    /** A real file handed to us to open: ACTION_VIEW's data, or a single ACTION_SEND stream. */
    private fun extractFileUri(i: Intent?): android.net.Uri? {
        if (i == null) return null
        return when (i.action) {
            Intent.ACTION_VIEW -> i.data?.takeIf { it.scheme == "content" || it.scheme == "file" }
            Intent.ACTION_SEND -> if (i.getStringExtra(Intent.EXTRA_TEXT) == null) {
                @Suppress("DEPRECATION") (i.getParcelableExtra(Intent.EXTRA_STREAM) as? android.net.Uri)
            } else null
            else -> null
        }
    }
}

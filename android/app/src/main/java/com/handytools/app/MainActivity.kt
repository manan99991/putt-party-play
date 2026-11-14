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
import com.handytools.app.tools.clipboard.ClipboardScreen
import com.handytools.app.tools.scancsv.ScanCsvScreen
import com.handytools.app.tools.invoice.QuickInvoiceScreen
import com.handytools.app.tools.receipts.ReceiptKeeperScreen
import com.handytools.app.tools.gifmaker.GifMakerScreen
import com.handytools.app.tools.parked.ParkedScreen
import com.handytools.app.tools.hearing.HearingBoostScreen
import com.handytools.app.tools.ai.AiScreen
import com.handytools.app.tools.lens.LensScreen
import com.handytools.app.tools.memory.MemoryScreen
import com.handytools.app.tools.sorted.SortedScreen
import com.handytools.app.tools.storage.StorageScreen
import com.handytools.app.tools.myphone.MyPhoneScreen
import com.handytools.app.tools.texttools.TextToolsScreen
import com.handytools.app.tools.translate.TranslateScreen
import com.handytools.app.tools.timers.TimersScreen
import com.handytools.app.tools.wallet.WalletScreen
import com.handytools.app.tools.notifhistory.NotifHistoryScreen
import com.handytools.app.tools.ocr.ScreenTextScreen
import com.handytools.app.tools.quick.QuickButtonsScreen
import com.handytools.app.tools.screenshot.ScreenshotScreen
import com.handytools.app.tools.shortcut.WebShortcutScreen
import com.handytools.app.ui.ComingSoonScreen
import com.handytools.app.ui.HandyTheme
import com.handytools.app.ui.HomeScreen
import com.handytools.app.ui.GroupScreen
import com.handytools.app.ui.SCANSORT_TOOLS
import com.handytools.app.ui.MORE_TOOLS
import com.handytools.app.ui.TOOLS
import com.handytools.app.ui.Onboarding
import com.handytools.app.ui.OnboardingScreen
import com.handytools.app.ui.PrivacyScreen
import com.handytools.app.ui.SettingsScreen
import com.handytools.app.ui.PaywallScreen

/** Lets a tool open another tool's route (e.g. Instruments → the folded-in Flashlight). Mirrors
 *  LocalRemoveAds; null when no navigator is in scope. */
val LocalOpenTool = androidx.compose.runtime.staticCompositionLocalOf<((String) -> Unit)?> { null }

class MainActivity : ComponentActivity() {

    private var sharedUrl by mutableStateOf<String?>(null)
    // A file handed to us by another app ("Open with" / share) → opened in the universal File Viewer.
    private var sharedFileUri by mutableStateOf<android.net.Uri?>(null)
    // Text or a link shared to Tenzy, and the type of a shared file: both go to "pick a tool to run on it".
    private var sharedText by mutableStateOf<String?>(null)
    private var sharedMime by mutableStateOf<String?>(null)
    // A route delivered to an already-running activity (singleTop reuse → onNewIntent, e.g. a deep
    // link while the app is open). onCreate handles the cold-start route via startDestination; this
    // state carries a warm route into the composition so it actually navigates instead of being
    // dropped. Observed by a LaunchedEffect inside setContent.
    private var pendingRoute by mutableStateOf<String?>(null)

    // Google Play's update step. It is asked for once each time the app is opened from cold; a person who backs out of
    // it can still use the app (a failed download must never lock anyone out) and is asked again next time.
    private val updateStep = registerForActivityResult(androidx.activity.result.contract.ActivityResultContracts.StartIntentSenderForResult()) { }
    private var updateAsked = false

    /**
     * If Play has a newer build, show its full-screen update step. Also picks an update back up if the app was left
     * while one was downloading. Does nothing when the app didn't come from Play (a test install, a screenshot run).
     */
    private fun checkForUpdate() {
        try {
            val manager = com.google.android.play.core.appupdate.AppUpdateManagerFactory.create(this)
            val options = com.google.android.play.core.appupdate.AppUpdateOptions.newBuilder(com.google.android.play.core.install.model.AppUpdateType.IMMEDIATE).build()
            manager.appUpdateInfo.addOnSuccessListener { info ->
                val state = info.updateAvailability()
                val underway = state == com.google.android.play.core.install.model.UpdateAvailability.DEVELOPER_TRIGGERED_UPDATE_IN_PROGRESS
                val fresh = state == com.google.android.play.core.install.model.UpdateAvailability.UPDATE_AVAILABLE &&
                    info.isUpdateTypeAllowed(com.google.android.play.core.install.model.AppUpdateType.IMMEDIATE) && !updateAsked
                if (underway || fresh) {
                    updateAsked = true
                    runCatching { manager.startUpdateFlowForResult(info, updateStep, options) }
                }
            }
        } catch (_: Throwable) { }
    }

    override fun onResume() {
        super.onResume()
        // Never over a CI screenshot or QA route: those runs must show the app's own screens.
        if (intent?.getStringExtra("route") == null) checkForUpdate()
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        sharedUrl = extractSharedUrl(intent)
        sharedFileUri = extractFileUri(intent)
        sharedText = extractSharedText(intent)
        sharedMime = sharedType(intent)
        Interstitials.preload(this)
        intent.getStringExtra("tool")?.let { id ->                                   // a tapped tool reminder or "run on this new photo"
            com.handytools.app.tools.builder.ToolReminders.pendingPhoto = intent.getStringExtra("photo")?.let { android.net.Uri.parse(it) }?.takeIf { it.scheme == "content" }
            com.handytools.app.tools.builder.ToolReminders.pending = id
        }
        importTool(intent)
        val routeExtra = intent.getStringExtra("route")
        // Pro-preview unlock exists ONLY for the CI screenshot capture and is compiled out of
        // release builds, so a crafted intent can never grant entitlement on a shipped app.
        if (routeExtra == "homepro" && com.handytools.app.BuildConfig.DEBUG) HandyApp.instance.billing.setPreviewPremium(true)
        val startRoute = routeExtra ?: if (sharedFileUri != null) sharedFileRoute(intent) else if (sharedText != null) "sharetool" else if (!Onboarding.seen(this)) "onboarding" else "home"

        setContent {
            // The nav controller is created OUTSIDE HandyTheme so it survives a theme switch: HandyTheme
            // rebuilds its content under key(theme) to re-skin every surface, and if the controller lived
            // inside that block a theme change would recreate it and bounce you back to home (which made
            // theme switches look like they did nothing). Hoisted here, the back stack is preserved.
            val nav = rememberNavController()
            // iPhone-style payment wall: a Pro tool opened by a free user goes to its unlock screen
            // instead of the tool. One choke point so every path — grid, search, the Settings map,
            // group tiles and warm deep links — is covered.
            val openTool: (String) -> Unit = { r ->
                if (com.handytools.app.ui.ToolGate.locked(r)) nav.navigate("lock/$r") else nav.navigate(r)
            }
            HandyTheme {
                androidx.compose.runtime.CompositionLocalProvider(
                    com.handytools.app.ads.LocalRemoveAds provides { nav.navigate("paywall") },
                    LocalOpenTool provides { r: String -> openTool(r) }
                ) {
                // A warm deep link (route delivered via onNewIntent) navigates here. launchSingleTop
                // avoids stacking duplicates when the same route is re-opened.
                LaunchedEffect(pendingRoute) {
                    pendingRoute?.let { r ->
                        if (com.handytools.app.ui.ToolGate.locked(r)) nav.navigate("lock/$r")
                        else nav.navigate(r) { launchSingleTop = true }
                        pendingRoute = null
                    }
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
                    composable("home") { HomeScreen(onOpen = { openTool(it) }) }
                    // CI screenshot route: home in Pro state (no ad strip) for the store split slide.
                    composable("homepro") { HomeScreen(onOpen = { openTool(it) }) }
                    composable(
                        "lock/{route}",
                        arguments = listOf(androidx.navigation.navArgument("route") { type = androidx.navigation.NavType.StringType })
                    ) { entry ->
                        val r = entry.arguments?.getString("route") ?: ""
                        com.handytools.app.ui.ProLockScreen(
                            route = r,
                            onBack = { if (!nav.popBackStack()) nav.navigate("home") },
                            onPro = { nav.navigate("paywall") }
                        )
                    }
                    composable("onboarding") { OnboardingScreen(onDone = { Onboarding.markSeen(this@MainActivity); nav.navigate("home") { popUpTo("onboarding") { inclusive = true } } }, onSeePro = { nav.navigate("paywall") }) }
                    composable("settings") { SettingsScreen(onOpen = { openTool(it) }) }
                    composable("privacy") { PrivacyScreen() }
                    composable("onboarding2") { OnboardingScreen(startPage = 1, onDone = { nav.navigate("home") }, onSeePro = { nav.navigate("paywall") }) }
                    composable("onboarding3") { OnboardingScreen(startPage = 2, onDone = { nav.navigate("home") }, onSeePro = { nav.navigate("paywall") }) }
                    composable("paywall") {
                        // Sheet over the home grid; dismissing pops back.
                        HomeScreen(onOpen = { openTool(it) })
                        PaywallScreen(onBack = { if (!nav.popBackStack()) nav.navigate("home") })
                    }
                    composable("clipboard") { ClipboardScreen() }
                    composable("screenshot") { ScreenshotScreen() }
                    composable("quick") { QuickButtonsScreen() }
                    composable("shortcut") { WebShortcutScreen(initialUrl = sharedUrl) }
                    composable("alarm") { AlarmListScreen(onUpgrade = { nav.navigate("paywall") }) }
                    composable("ocr") { ScreenTextScreen() }
                    composable("notifs") { NotifHistoryScreen() }
                    composable("scancsv") { ScanCsvScreen() }
                    composable("invoice") { QuickInvoiceScreen() }
                    composable("receipts") { ReceiptKeeperScreen() }
                    composable("gifmaker") { GifMakerScreen() }
                    // --- Rebuilt 10-power-tool catalog routes (interim targets reuse existing
                    // screens until each merged tool is rebuilt; Capture is first in line). ---
                    // The 10 power tools (rebuilt to the approved prototype)
                    composable("fileviewer") { com.handytools.app.tools.power.FileViewerToolScreen(initialUri = sharedFileUri) }
                    composable("docs") { com.handytools.app.tools.power.DocsCaptureToolScreen() }
                    composable("converter") { com.handytools.app.tools.power.ConverterToolScreen() }
                    composable("codes") { com.handytools.app.tools.power.CodesToolScreen() }
                    composable("scrubber") { com.handytools.app.tools.power.ScrubberToolScreen() }
                    composable("media") { com.handytools.app.tools.power.MediaToolScreen() }
                    composable("cleanup") { com.handytools.app.tools.power.CleanupToolScreen() }
                    composable("voice") { com.handytools.app.tools.power.VoiceToolScreen() }
                    composable("instruments") { com.handytools.app.tools.power.InstrumentsToolScreen() }
                    composable("flashlight") { com.handytools.app.tools.power.FlashlightToolScreen() }
                    composable("safety") { com.handytools.app.tools.power.SafetyToolScreen() }
                    composable("share") { com.handytools.app.tools.power.ShareToolScreen() }
                    composable("parked") { ParkedScreen() }
                    composable("network") { com.handytools.app.tools.power.NetworkToolScreen() }
                    composable("identify") { com.handytools.app.tools.power.IdentifyToolScreen() }
                    composable("gpsdash") { com.handytools.app.tools.power.GpsDashboardToolScreen() }
                    composable("rest") { com.handytools.app.tools.power.RestToolScreen() }
                    composable("pricecheck") { com.handytools.app.tools.power.PriceCheckToolScreen() }
                    composable("stitch") { com.handytools.app.tools.power.StitchToolScreen() }
                    composable("colorvision") { com.handytools.app.tools.power.ColorVisionToolScreen() }
                    composable("procam") { com.handytools.app.tools.power.ProCameraToolScreen() }
                    composable("hearing") { HearingBoostScreen() }
                    composable("timer") { TimersScreen() }
                    composable("wallet") { WalletScreen() }
                    composable("translate") { com.handytools.app.tools.power.TranslateToolScreen() }
                    composable("sorted") { SortedScreen() }
                    composable("memory") { MemoryScreen() }
                    composable("lens") { LensScreen() }
                    composable("storage") { StorageScreen(onOpen = { openTool(it) }) }
                    // Group launchers: one tile that opens a list of its folded-in tools.
                    composable("scansort") { GroupScreen("scansort", SCANSORT_TOOLS) { openTool(it) } }
                    composable("more") { GroupScreen("more", MORE_TOOLS) { openTool(it) } }
                    composable("myphone") { MyPhoneScreen() }
                    composable("texttools") { TextToolsScreen() }
                    composable("builder") { com.handytools.app.tools.builder.BuilderScreen() }
                    composable("sharetool") {
                        // A shared file can still just be opened; a shared link can still become a home-screen shortcut, as before.
                        if (sharedFileUri != null) com.handytools.app.tools.builder.ShareToToolScreen(uri = sharedFileUri, mime = sharedMime, onOpenInstead = { nav.navigate("fileviewer") })
                        else com.handytools.app.tools.builder.ShareToToolScreen(uri = null, text = sharedText, otherWay = if (sharedUrl != null) "Make a home-screen shortcut for this link" else "Go to Tenzy",
                            onOpenInstead = { nav.navigate(if (sharedUrl != null) "shortcut" else "home") })
                    }
                    // New catalog tools not yet ported to Android show a placeholder (never shipped
                    // to Play until real). Existing routes above keep their real screens.
                    val ported = setOf("scansort", "more", "quick", "clipboard", "ocr", "shortcut", "alarm", "scratchpad", "flash", "timer", "measure", "wallet", "imgconvert", "audiotext", "pdftools", "translate", "exif", "scan", "vidcompress", "qr", "magnifier", "bgremove", "sorted", "memory", "lens", "contacts", "spaceclean", "shrink", "storage", "myphone", "texttools", "shield", "scancsv", "invoice", "voicerec", "idphoto", "redact", "receipts", "gifmaker", "sendany", "parked", "netscout", "network", "identify", "gpsdash", "rest", "pricecheck", "stitch", "colorvision", "procam", "signfill", "hearing", "heartrate", "audiocut", "capture", "documents", "media", "cleanup", "voice", "instruments", "flashlight", "safety", "share", "fileviewer", "docs", "converter", "codes", "scrubber")
                    TOOLS.map { it.route }.filter { it !in ported }.distinct().forEach { r ->
                        composable(r) {
                            if (r.startsWith("ai_")) AiScreen(r)
                            else ComingSoonScreen(TOOLS.first { it.route == r }.name)
                        }
                    }
                    // CI screenshot route: static ring preview, no alarm or service involved.
                    composable("ring") { AlarmRingPreview() }
                }
                // Offer to send a crash report saved from a previous run (overlays the start screen).
                com.handytools.app.ui.CrashReportPrompt()
                }
            }
        }
    }

    /** A tool that arrived as a link (tenzy://import?d=...): save it and open Build your own, where it is listed with the person's own tools. */
    private fun importTool(i: Intent?) {
        val link = i?.data?.takeIf { i.action == Intent.ACTION_VIEW && it.scheme == "tenzy" && it.host == "import" } ?: return
        val tool = runCatching { com.handytools.app.tools.builder.ToolLink.chain(link.toString()) }.getOrNull() ?: return
        com.handytools.app.tools.builder.ChainStore.save(this, com.handytools.app.tools.builder.ChainStore.load(this) + tool)
        i.putExtra("route", "builder")
        i.data = null                 // so the same link is never read twice if the screen is rebuilt
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        sharedUrl = extractSharedUrl(intent)
        sharedFileUri = extractFileUri(intent)
        sharedText = extractSharedText(intent)
        sharedMime = sharedType(intent)
        // Honour a route delivered to the already-running activity (deep link / QA route-seeding),
        // which singleTop would otherwise drop. Pro-preview stays debug-only, exactly as in onCreate.
        intent.getStringExtra("tool")?.let { id ->                                   // a tapped tool reminder or "run on this new photo"
            com.handytools.app.tools.builder.ToolReminders.pendingPhoto = intent.getStringExtra("photo")?.let { android.net.Uri.parse(it) }?.takeIf { it.scheme == "content" }
            com.handytools.app.tools.builder.ToolReminders.pending = id
        }
        importTool(intent)
        val routeExtra = intent.getStringExtra("route")
        if (routeExtra == "homepro" && com.handytools.app.BuildConfig.DEBUG) HandyApp.instance.billing.setPreviewPremium(true)
        if (routeExtra != null) pendingRoute = routeExtra
        else if (sharedFileUri != null) pendingRoute = sharedFileRoute(intent)
        else if (sharedText != null) pendingRoute = "sharetool"
    }

    /** A photo, video, recording or PDF shared to Tenzy goes to "pick a tool to run on it"; any other file opens in File Opener as before. */
    private fun sharedFileRoute(i: Intent?): String {
        val kind = com.handytools.app.tools.builder.kindOf(sharedType(i), false)
        return if (i?.action == Intent.ACTION_SEND && kind != null && kind != com.handytools.app.tools.builder.Kind.TEXT) "sharetool" else "fileviewer"
    }

    /** The type of a shared file: what the sending app said, or what the phone knows about the file. */
    private fun sharedType(i: Intent?): String? {
        if (i?.action != Intent.ACTION_SEND) return null
        val said = i.type?.takeIf { !it.endsWith("/*") && it != "*/*" }
        return said ?: extractFileUri(i)?.let { runCatching { contentResolver.getType(it) }.getOrNull() } ?: i.type
    }

    /** Text or a link shared to Tenzy (not a file). */
    private fun extractSharedText(i: Intent?): String? {
        if (i?.action != Intent.ACTION_SEND) return null
        return i.getStringExtra(Intent.EXTRA_TEXT)?.trim()?.takeIf { it.isNotEmpty() }
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

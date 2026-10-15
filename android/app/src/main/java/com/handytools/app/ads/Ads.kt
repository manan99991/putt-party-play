package com.handytools.app.ads

import android.app.Activity
import android.content.Context
import android.util.Log
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.padding
import androidx.compose.material3.Text
import com.handytools.app.ui.HandyColors
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.material3.MaterialTheme
import androidx.compose.ui.Alignment
import androidx.compose.ui.unit.dp
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyTokens
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import com.google.android.gms.ads.AdRequest
import com.google.android.gms.ads.AdSize
import com.google.android.gms.ads.AdView
import com.google.android.gms.ads.FullScreenContentCallback
import com.google.android.gms.ads.LoadAdError
import com.google.android.gms.ads.interstitial.InterstitialAd
import com.google.android.gms.ads.interstitial.InterstitialAdLoadCallback
import com.handytools.app.HandyApp

/**
 * AdMob. These are Google's official TEST unit ids. Replace both before release
 * (AdMob console > Apps > HandyTools > Ad units) or you'll get your account flagged.
 */
object AdUnits {
    const val BANNER = "ca-app-pub-3940256099942544/6300978111"
    const val INTERSTITIAL = "ca-app-pub-3940256099942544/1033173712"
}

/** Provided by MainActivity so any screen's banner can open the paywall. */
val LocalRemoveAds = androidx.compose.runtime.staticCompositionLocalOf<(() -> Unit)?> { null }

/** Anchored adaptive banner in a chrome strip: hairline on top, bg color, height reserved so nothing jumps. Nothing for Pro. */
@Composable
fun BannerAd(modifier: Modifier = Modifier, onRemoveAds: (() -> Unit)? = LocalRemoveAds.current) {
    val premium by HandyApp.instance.billing.isPremium.collectAsState()
    if (premium) { Spacer(Modifier.fillMaxWidth().navigationBarsPadding()); return }
    val ctx = LocalContext.current
    Column(modifier.fillMaxWidth().background(MaterialTheme.colorScheme.background).navigationBarsPadding()) {
        Box(Modifier.fillMaxWidth().height(1.dp).background(Handy.palette.border))
        Row(
            Modifier.fillMaxWidth().padding(horizontal = HandyTokens.Gutter, vertical = 2.dp),
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Text("Ads keep HandyTools free", style = MaterialTheme.typography.labelSmall, color = Handy.palette.textSecondary)
            Text("Remove ads", style = MaterialTheme.typography.labelSmall, color = HandyColors.Accent,
                modifier = Modifier.clickable { onRemoveAds?.invoke() })
        }
        Box(Modifier.fillMaxWidth().heightIn(min = HandyTokens.AdReservedHeight), contentAlignment = Alignment.Center) {
            AndroidView(
                modifier = Modifier.fillMaxWidth(),
                factory = {
                    AdView(ctx).apply {
                        val widthDp = (ctx.resources.displayMetrics.widthPixels / ctx.resources.displayMetrics.density).toInt()
                        setAdSize(AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(ctx, widthDp))
                        adUnitId = AdUnits.BANNER
                        loadAd(AdRequest.Builder().build())
                    }
                }
            )
        }
    }
}

/**
 * Interstitial shown at most once every [MIN_GAP_MS] after a tool finishes.
 * Call [preload] at app start and [showIfReady] after a tool action completes.
 */
object Interstitials {
    private const val MIN_GAP_MS = 3 * 60 * 1000L
    private var ad: InterstitialAd? = null
    private var lastShown = 0L

    fun preload(ctx: Context) {
        if (HandyApp.instance.billing.isPremium.value || ad != null) return
        InterstitialAd.load(ctx, AdUnits.INTERSTITIAL, AdRequest.Builder().build(),
            object : InterstitialAdLoadCallback() {
                override fun onAdLoaded(a: InterstitialAd) { ad = a }
                override fun onAdFailedToLoad(e: LoadAdError) { Log.d("Ads", e.message) }
            })
    }

    fun showIfReady(activity: Activity) {
        if (HandyApp.instance.billing.isPremium.value) return
        val a = ad ?: run { preload(activity); return }
        if (System.currentTimeMillis() - lastShown < MIN_GAP_MS) return
        a.fullScreenContentCallback = object : FullScreenContentCallback() {
            override fun onAdDismissedFullScreenContent() { ad = null; preload(activity) }
        }
        lastShown = System.currentTimeMillis()
        a.show(activity)
    }
}

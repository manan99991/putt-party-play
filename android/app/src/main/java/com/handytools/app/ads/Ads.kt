package com.handytools.app.ads

import android.app.Activity
import android.content.Context
import android.util.Log
import androidx.compose.foundation.layout.fillMaxWidth
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

/** Anchored adaptive banner. Renders nothing for Pro users. */
@Composable
fun BannerAd(modifier: Modifier = Modifier) {
    val premium by HandyApp.instance.billing.isPremium.collectAsState()
    if (premium) return
    val ctx = LocalContext.current
    AndroidView(
        modifier = modifier.fillMaxWidth(),
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

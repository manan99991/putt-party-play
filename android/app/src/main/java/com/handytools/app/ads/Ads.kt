package com.handytools.app.ads

// Tenzy is subscription-only — AdMob was removed entirely (the account kept getting declined and
// ads weren't serving, so we dropped ad revenue in favour of Tenzy Pro). These are inert shims so
// the former call sites keep compiling; none of them render an ad or load any ad SDK. Tenzy Pro now
// means unlimited tools and no daily limits.

import android.app.Activity
import android.content.Context
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier

/** Provided by MainActivity so any screen can open the paywall (the former "Remove ads" tap). */
val LocalRemoveAds = staticCompositionLocalOf<(() -> Unit)?> { null }

/** Renders nothing — kept so screens that still call `BannerAd()` compile; there is no ad strip. */
@Composable
fun BannerAd(modifier: Modifier = Modifier, onRemoveAds: (() -> Unit)? = LocalRemoveAds.current) {
    Spacer(Modifier.fillMaxWidth().navigationBarsPadding())
}

/** No-op interstitials. Kept so former call sites compile; nothing is ever shown. */
object Interstitials {
    fun preload(ctx: Context) {}
    fun showIfReady(activity: Activity) {}
}

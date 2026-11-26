package com.handytools.app.billing

import android.app.Activity
import android.content.Context
import android.util.Log
import com.handytools.app.BuildConfig
import com.android.billingclient.api.AcknowledgePurchaseParams
import com.android.billingclient.api.BillingClient
import com.android.billingclient.api.BillingClientStateListener
import com.android.billingclient.api.BillingFlowParams
import com.android.billingclient.api.BillingResult
import com.android.billingclient.api.ProductDetails
import com.android.billingclient.api.Purchase
import com.android.billingclient.api.PurchasesUpdatedListener
import com.android.billingclient.api.QueryProductDetailsParams
import com.android.billingclient.api.QueryPurchasesParams
import com.android.billingclient.api.acknowledgePurchase
import com.android.billingclient.api.queryProductDetails
import com.android.billingclient.api.queryPurchasesAsync
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch

/**
 * Google Play Billing: Tenzy Pro monthly or yearly, the same as the iPhone (Manan's pricing, 22 Nov; 26 Nov on Android).
 *
 *     • tenzy_pro_month    base plan monthly-p1m (P1M)  — $2.99,  7-day free trial
 *     • tenzy_pro_yearly   base plan yearly-p1y  (P1Y)  — $29.99, 7-day free trial (people already on $19.99 keep it)
 *   Set by the pipeline, not by hand: `fastlane subscriptions` (android/fastlane/Fastfile).
 *
 * Premium = ads off + everything unlimited. Entitlement is cached in [isPremium] and re-verified
 * on every app start.
 */
class BillingManager(private val ctx: Context) : PurchasesUpdatedListener {

    companion object {
        const val YEARLY_ID = "tenzy_pro_yearly"
        const val MONTHLY_ID = "tenzy_pro_month"
        private val PRODUCT_IDS = listOf(YEARLY_ID, MONTHLY_ID)
        private const val TAG = "Billing"
    }

    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.IO)
    private val client = BillingClient.newBuilder(ctx)
        .setListener(this)
        .enablePendingPurchases(
            com.android.billingclient.api.PendingPurchasesParams.newBuilder().enableOneTimeProducts().build()
        )
        .build()

    // INTERNAL_UNLOCK (internal-testing builds only) forces Pro on; never persisted to the cache.
    private val _isPremium = MutableStateFlow(BuildConfig.INTERNAL_UNLOCK || PremiumCache.read(ctx))
    val isPremium: StateFlow<Boolean> = _isPremium

    private val _yearly = MutableStateFlow<ProductDetails?>(null)
    val yearly: StateFlow<ProductDetails?> = _yearly
    private val _monthly = MutableStateFlow<ProductDetails?>(null)
    val monthly: StateFlow<ProductDetails?> = _monthly

    /** The offer to sell: the free trial while the person can still have it (Play only lists offers they qualify
     *  for), otherwise the plain plan. */
    private fun offerOf(pd: ProductDetails?): ProductDetails.SubscriptionOfferDetails? {
        val offers = pd?.subscriptionOfferDetails ?: return null
        return offers.firstOrNull { o -> o.pricingPhases.pricingPhaseList.any { it.priceAmountMicros == 0L } }
            ?: offers.firstOrNull { it.offerId == null } ?: offers.firstOrNull()
    }
    private fun pricePhase(pd: ProductDetails?) = offerOf(pd)?.pricingPhases?.pricingPhaseList?.lastOrNull { it.priceAmountMicros > 0L }

    /** The live price in the person's currency, e.g. "$29.99" — null until Play responds. */
    val yearlyPrice: String? get() = pricePhase(_yearly.value)?.formattedPrice
    val monthlyPrice: String? get() = pricePhase(_monthly.value)?.formattedPrice
    /** What to show before Play answers: the US prices, the same as the iPhone. */
    val yearlyPriceShown: String get() = yearlyPrice ?: "$29.99"
    val monthlyPriceShown: String get() = monthlyPrice ?: "$2.99"

    /** "Save 16%": yearly against twelve months, from the live prices (null when it doesn't save). */
    val yearlySaving: Int? get() {
        val y = pricePhase(_yearly.value)?.priceAmountMicros ?: return null
        val m = pricePhase(_monthly.value)?.priceAmountMicros ?: return null
        if (m <= 0L) return null
        val pct = ((1.0 - y.toDouble() / (m.toDouble() * 12)) * 100).toInt()
        return pct.takeIf { it > 0 }
    }

    /** Days of free trial a plan really offers this person right now (null when none). */
    fun trialDays(yearlyPlan: Boolean): Int? {
        val ph = offerOf(if (yearlyPlan) _yearly.value else _monthly.value)?.pricingPhases?.pricingPhaseList
            ?.firstOrNull { it.priceAmountMicros == 0L } ?: return null
        return com.handytools.app.billing.trialDays(ph.billingPeriod)
    }

    /** "7 days" in the phone's language. */
    fun daysWords(n: Int): String = android.icu.text.MeasureFormat.getInstance(java.util.Locale.getDefault(), android.icu.text.MeasureFormat.FormatWidth.WIDE)
        .format(android.icu.util.Measure(n, android.icu.util.MeasureUnit.DAY))

    /** "7-day free trial" only when Play's live yearly offer really has a free phase; otherwise null. */
    val trialLabel: String? get() = trialDays(true)?.let { "$it-day free trial" }

    fun start() {
        if (client.isReady) return
        client.startConnection(object : BillingClientStateListener {
            override fun onBillingSetupFinished(result: BillingResult) {
                if (result.responseCode == BillingClient.BillingResponseCode.OK) {
                    scope.launch { loadProducts(); refreshEntitlement() }
                } else Log.w(TAG, "setup failed ${result.debugMessage}")
            }
            override fun onBillingServiceDisconnected() { /* client retries automatically on next call */ }
        })
    }

    private suspend fun loadProducts() {
        val params = QueryProductDetailsParams.newBuilder().setProductList(
            PRODUCT_IDS.map {
                QueryProductDetailsParams.Product.newBuilder()
                    .setProductId(it).setProductType(BillingClient.ProductType.SUBS).build()
            }
        ).build()
        val res = client.queryProductDetails(params)
        val list = res.productDetailsList ?: emptyList()
        _yearly.value = list.firstOrNull { it.productId == YEARLY_ID }
        _monthly.value = list.firstOrNull { it.productId == MONTHLY_ID }
    }

    suspend fun refreshEntitlement() {
        val res = client.queryPurchasesAsync(
            QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.SUBS).build()
        )
        val active = res.purchasesList.any { p ->
            p.products.any { it in PRODUCT_IDS } && p.purchaseState == Purchase.PurchaseState.PURCHASED
        }
        res.purchasesList.forEach { ackIfNeeded(it) }
        setPremium(active)
    }

    /** Launch the purchase flow for the chosen plan (yearly unless the person picked monthly). */
    fun launchPurchase(activity: Activity, yearlyPlan: Boolean = true) {
        val pd = (if (yearlyPlan) _yearly.value else _monthly.value) ?: run {
            start()
            android.widget.Toast.makeText(ctx, "Couldn't reach Google Play. Check your connection and tap again.", android.widget.Toast.LENGTH_LONG).show()
            return
        }
        val offerToken = offerOf(pd)?.offerToken ?: return
        val params = BillingFlowParams.newBuilder()
            .setProductDetailsParamsList(
                listOf(
                    BillingFlowParams.ProductDetailsParams.newBuilder()
                        .setProductDetails(pd).setOfferToken(offerToken).build()
                )
            ).build()
        client.launchBillingFlow(activity, params)
    }

    override fun onPurchasesUpdated(result: BillingResult, purchases: MutableList<Purchase>?) {
        if (result.responseCode != BillingClient.BillingResponseCode.OK || purchases == null) return
        scope.launch {
            purchases.forEach { ackIfNeeded(it) }
            refreshEntitlement()
        }
    }

    private suspend fun ackIfNeeded(p: Purchase) {
        if (p.purchaseState == Purchase.PurchaseState.PURCHASED && !p.isAcknowledged) {
            client.acknowledgePurchase(
                AcknowledgePurchaseParams.newBuilder().setPurchaseToken(p.purchaseToken).build()
            )
        }
    }

    private fun setPremium(v: Boolean) {
        _isPremium.value = v || BuildConfig.INTERNAL_UNLOCK
        PremiumCache.write(ctx, v)
    }

    /** CI screenshot only: flip the in-memory entitlement for the `homepro` capture.
     *  Never written to PremiumCache, so it never persists past the process. */
    fun setPreviewPremium(v: Boolean) { _isPremium.value = v }
}

/** Tiny cache so the first frame after launch doesn't flash a banner at paying users. */
object PremiumCache {
    private const val PREF = "premium"
    fun read(ctx: Context) = ctx.getSharedPreferences(PREF, 0).getBoolean("active", false)
    fun write(ctx: Context, v: Boolean) = ctx.getSharedPreferences(PREF, 0).edit().putBoolean("active", v).apply()
}

/** Days in a Play billing period like "P7D", "P1W" or "P1M" (a month counts as 30). Pure, unit-tested. */
fun trialDays(period: String): Int? {
    val m = Regex("P(\\d+)([DWM])").matchEntire(period) ?: return null
    val n = m.groupValues[1].toInt()
    return when (m.groupValues[2]) { "D" -> n; "W" -> n * 7; else -> n * 30 }
}

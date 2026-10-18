package com.handytools.app.billing

import android.app.Activity
import android.content.Context
import android.util.Log
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
 * Google Play Billing, two auto-renewing subscriptions: Monthly and Yearly.
 *
 * Play Console setup (one time):
 *   Monetize > Products > Subscriptions
 *     • Product ID: tenzy_pro_yearly    base plan yearly-p1y  (P1Y)  — $19.99
 *     • Product ID: tenzy_pro_monthly   base plan monthly-p1m (P1M)  — $2.99
 *   (Product IDs must match the constants below.) Optional 7-day free trial on yearly.
 *
 * Premium = ads off + everything unlimited. Entitlement is cached in [isPremium] and re-verified
 * on every app start.
 */
class BillingManager(private val ctx: Context) : PurchasesUpdatedListener {

    companion object {
        const val YEARLY_ID = "tenzy_pro_yearly"
        const val MONTHLY_ID = "tenzy_pro_monthly"
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

    private val _isPremium = MutableStateFlow(PremiumCache.read(ctx))
    val isPremium: StateFlow<Boolean> = _isPremium

    private val _yearly = MutableStateFlow<ProductDetails?>(null)
    val yearly: StateFlow<ProductDetails?> = _yearly
    private val _monthly = MutableStateFlow<ProductDetails?>(null)
    val monthly: StateFlow<ProductDetails?> = _monthly

    private fun priceOf(pd: ProductDetails?): String? =
        pd?.subscriptionOfferDetails?.firstOrNull()?.pricingPhases?.pricingPhaseList?.lastOrNull()?.formattedPrice

    /** e.g. "$19.99" — null until Play responds. */
    val yearlyPrice: String? get() = priceOf(_yearly.value)
    val monthlyPrice: String? get() = priceOf(_monthly.value)

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
            (p.products.contains(YEARLY_ID) || p.products.contains(MONTHLY_ID)) &&
                p.purchaseState == Purchase.PurchaseState.PURCHASED
        }
        res.purchasesList.forEach { ackIfNeeded(it) }
        setPremium(active)
    }

    /** Launch the purchase flow for the chosen plan. */
    fun launchPurchase(activity: Activity, yearly: Boolean) {
        val pd = (if (yearly) _yearly.value else _monthly.value) ?: run { start(); return }
        val offerToken = pd.subscriptionOfferDetails?.firstOrNull()?.offerToken ?: return
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
        _isPremium.value = v
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

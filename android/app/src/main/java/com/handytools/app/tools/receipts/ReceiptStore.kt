package com.handytools.app.tools.receipts

import android.content.Context
import java.io.File
import java.util.Calendar
import org.json.JSONArray
import org.json.JSONObject

data class Receipt(
    val id: Long,
    val merchant: String,
    val total: String,
    val purchaseMs: Long,
    val warrantyMonths: Int,
    val imagePath: String,
) {
    val warrantyEndMs: Long
        get() = Calendar.getInstance().apply { timeInMillis = purchaseMs; add(Calendar.MONTH, warrantyMonths) }.timeInMillis
}

/** Receipts persisted as a small JSON file in the app's private storage — no database, no network. */
object ReceiptStore {
    private fun file(ctx: Context) = File(ctx.filesDir, "receipts.json")

    fun load(ctx: Context): List<Receipt> {
        val f = file(ctx)
        if (!f.exists()) return emptyList()
        return try {
            val arr = JSONArray(f.readText())
            (0 until arr.length()).map { i ->
                val o = arr.getJSONObject(i)
                Receipt(
                    o.getLong("id"), o.getString("merchant"), o.getString("total"),
                    o.getLong("purchaseMs"), o.getInt("warrantyMonths"), o.getString("imagePath"),
                )
            }.sortedBy { it.warrantyEndMs }
        } catch (e: Exception) { emptyList() }
    }

    fun save(ctx: Context, list: List<Receipt>) {
        val arr = JSONArray()
        list.forEach { r ->
            arr.put(JSONObject().apply {
                put("id", r.id); put("merchant", r.merchant); put("total", r.total)
                put("purchaseMs", r.purchaseMs); put("warrantyMonths", r.warrantyMonths); put("imagePath", r.imagePath)
            })
        }
        try { file(ctx).writeText(arr.toString()) } catch (_: Exception) {}
    }
}

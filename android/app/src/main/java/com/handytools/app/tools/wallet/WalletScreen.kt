package com.handytools.app.tools.wallet

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.CreditCard
import androidx.compose.material.icons.outlined.QrCode2
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Checkbox
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.google.zxing.BarcodeFormat
import com.google.zxing.MultiFormatWriter
import com.handytools.app.Limits
import com.handytools.app.ads.BannerAd
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HTextButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.ToolHeader
import com.handytools.app.HandyApp
import org.json.JSONArray
import org.json.JSONObject

data class Card(val name: String, val code: String, val qr: Boolean)

/** Loyalty/membership barcodes, stored on the phone. Tap a card to show it big for scanning. */
@Composable
fun WalletScreen() {
    val ctx = LocalContext.current
    var cards by remember { mutableStateOf(WalletStore.load(ctx)) }
    var adding by remember { mutableStateOf(false) }
    var showing by remember { mutableStateOf<Card?>(null) }
    val premium by HandyApp.instance.billing.isPremium.collectAsState()
    val atLimit = !premium && cards.size >= Limits.FREE_WALLET_CARDS

    Column(Modifier.fillMaxSize().statusBarsPadding().padding(20.dp)) {
        ToolHeader("Card Wallet", "Every loyalty barcode, ready to scan.")
        Spacer(Modifier.size(12.dp))
        LazyColumn(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(8.dp)) {
            items(cards) { c ->
                Row(
                    Modifier.fillMaxWidth().background(MaterialTheme.colorScheme.surface, RoundedCornerShape(12.dp))
                        .clickable { showing = c }.padding(14.dp),
                    verticalAlignment = Alignment.CenterVertically
                ) {
                    Icon(if (c.qr) Icons.Outlined.QrCode2 else Icons.Outlined.CreditCard, null, tint = HandyColors.Accent)
                    Spacer(Modifier.size(12.dp))
                    Column {
                        Text(c.name, style = MaterialTheme.typography.titleMedium)
                        Text(c.code, style = MaterialTheme.typography.bodySmall, color = Handy.palette.textSecondary, maxLines = 1)
                    }
                }
            }
        }
        if (atLimit) Text("Free keeps ${Limits.FREE_WALLET_CARDS} cards. Go Pro for unlimited.",
            style = MaterialTheme.typography.bodySmall, color = HandyColors.Accent, modifier = Modifier.padding(vertical = 8.dp))
        HPrimaryButton("Add a card", enabled = !atLimit, modifier = Modifier.fillMaxWidth()) { adding = true }
        Spacer(Modifier.size(8.dp))
        BannerAd()
    }

    if (adding) AddCardDialog(onDismiss = { adding = false }) { c ->
        cards = cards + c; WalletStore.save(ctx, cards); adding = false
    }
    showing?.let { c -> CardDialog(c) { showing = null } }
}

@Composable
private fun AddCardDialog(onDismiss: () -> Unit, onSave: (Card) -> Unit) {
    var name by remember { mutableStateOf("") }
    var code by remember { mutableStateOf("") }
    var qr by remember { mutableStateOf(false) }
    AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text("Add card") },
        text = {
            Column {
                OutlinedTextField(name, { name = it }, label = { Text("Card name") }, singleLine = true)
                Spacer(Modifier.size(8.dp))
                OutlinedTextField(code, { code = it }, label = { Text("Card number / code") }, singleLine = true)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Checkbox(qr, { qr = it }); Text("This is a QR code")
                }
            }
        },
        confirmButton = { HPrimaryButton("Save") { if (code.isNotBlank()) onSave(Card(if (name.isBlank()) "Card" else name, code.trim(), qr)) } },
        dismissButton = { HTextButton("Cancel", onClick = onDismiss) }
    )
}

@Composable
private fun CardDialog(c: Card, onDismiss: () -> Unit) {
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = { HPrimaryButton("Done", onClick = onDismiss) },
        title = { Text(c.name) },
        text = {
            Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                val bmp = remember(c.code, c.qr) { Barcodes.make(c.code, c.qr) }
                bmp?.let {
                    Box(Modifier.background(Color.White).padding(12.dp)) {
                        Image(it.asImageBitmap(), null, Modifier.heightIn(max = if (c.qr) 240.dp else 140.dp))
                    }
                }
                Spacer(Modifier.size(8.dp))
                Text(c.code, color = Handy.palette.textSecondary)
            }
        }
    )
}

object Barcodes {
    fun make(text: String, qr: Boolean): Bitmap? = runCatching {
        val format = if (qr) BarcodeFormat.QR_CODE else BarcodeFormat.CODE_128
        val w = if (qr) 600 else 800; val h = if (qr) 600 else 300
        val matrix = MultiFormatWriter().encode(text, format, w, h)
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        for (x in 0 until w) for (y in 0 until h) bmp.setPixel(x, y, if (matrix.get(x, y)) Color.BLACK else Color.WHITE)
        bmp
    }.getOrNull()
}

object WalletStore {
    private fun prefs(ctx: Context) = ctx.getSharedPreferences("wallet", 0)
    fun load(ctx: Context): List<Card> = runCatching {
        val arr = JSONArray(prefs(ctx).getString("cards", "[]"))
        (0 until arr.length()).map { val o = arr.getJSONObject(it); Card(o.getString("name"), o.getString("code"), o.getBoolean("qr")) }
    }.getOrDefault(emptyList())
    fun save(ctx: Context, cards: List<Card>) {
        val arr = JSONArray()
        cards.forEach { arr.put(JSONObject().put("name", it.name).put("code", it.code).put("qr", it.qr)) }
        prefs(ctx).edit().putString("cards", arr.toString()).apply()
    }
}

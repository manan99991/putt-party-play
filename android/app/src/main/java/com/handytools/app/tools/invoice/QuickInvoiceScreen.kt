package com.handytools.app.tools.invoice

import android.content.Context
import android.graphics.Color as AndroidColor
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handytools.app.ads.BannerAd
import com.handytools.app.tools.Share
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.HandyHaptics
import com.handytools.app.ui.ToolHeader
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private class ItemState {
    var desc by mutableStateOf("")
    var qty by mutableStateOf("1")
    var price by mutableStateOf("")
}

/**
 * Quick Invoice. Fill in who it's from, who it's for and a few line items, and export a clean,
 * printable PDF invoice you can email or save. Totals (and optional tax) are worked out for you.
 * Everything is generated on the phone — nothing is uploaded.
 */
@Composable
fun QuickInvoiceScreen() {
    val ctx = LocalContext.current
    val today = remember { SimpleDateFormat("d MMM yyyy", Locale.getDefault()).format(Date()) }

    var from by remember { mutableStateOf("") }
    var billTo by remember { mutableStateOf("") }
    var number by remember { mutableStateOf("0001") }
    var date by remember { mutableStateOf(today) }
    var currency by remember { mutableStateOf("$") }
    var taxPct by remember { mutableStateOf("") }
    var notes by remember { mutableStateOf("") }
    val items = remember { mutableStateListOf(ItemState()) }

    fun lineTotal(it: ItemState) = (it.qty.toDoubleOrNull() ?: 0.0) * (it.price.toDoubleOrNull() ?: 0.0)
    val subtotal = items.sumOf { lineTotal(it) }
    val tax = subtotal * ((taxPct.toDoubleOrNull() ?: 0.0) / 100.0)
    val grand = subtotal + tax
    fun money(v: Double) = "$currency${"%,.2f".format(v)}"

    val canExport = from.isNotBlank() && billTo.isNotBlank() && items.any { it.desc.isNotBlank() && lineTotal(it) > 0 }

    fun export() {
        val snapshot = items.filter { it.desc.isNotBlank() }
            .map { Triple(it.desc.trim(), it.qty.toDoubleOrNull() ?: 0.0, it.price.toDoubleOrNull() ?: 0.0) }
        val file = buildInvoicePdf(
            ctx, from.trim(), billTo.trim(), number.trim(), date.trim(), currency,
            snapshot, taxPct.toDoubleOrNull() ?: 0.0, notes.trim(),
        )
        Share.file(ctx, file, "application/pdf")
        HandyHaptics.success(ctx)
    }

    Column(
        Modifier.fillMaxWidth().statusBarsPadding().padding(20.dp).verticalScroll(rememberScrollState())
    ) {
        ToolHeader("Quick Invoice", "Fill in the details and export a clean PDF invoice to email or print.")
        Spacer(Modifier.size(16.dp))

        OutlinedTextField(from, { from = it }, modifier = Modifier.fillMaxWidth(), label = { Text("From (your name or business)") })
        Spacer(Modifier.size(10.dp))
        OutlinedTextField(billTo, { billTo = it }, modifier = Modifier.fillMaxWidth(), label = { Text("Bill to") })
        Spacer(Modifier.size(10.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            OutlinedTextField(number, { number = it }, modifier = Modifier.weight(1f), label = { Text("Invoice #") })
            OutlinedTextField(date, { date = it }, modifier = Modifier.weight(1f), label = { Text("Date") })
        }
        Spacer(Modifier.size(10.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            OutlinedTextField(currency, { currency = it.take(3) }, modifier = Modifier.width(90.dp), label = { Text("Symbol") })
            OutlinedTextField(taxPct, { taxPct = it }, modifier = Modifier.weight(1f), label = { Text("Tax %") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number))
        }

        Spacer(Modifier.size(18.dp))
        Text("Items", fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onBackground)
        items.forEachIndexed { i, item ->
            Spacer(Modifier.size(10.dp))
            OutlinedTextField(item.desc, { item.desc = it }, modifier = Modifier.fillMaxWidth(), label = { Text("Description") })
            Spacer(Modifier.size(6.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                OutlinedTextField(item.qty, { item.qty = it }, modifier = Modifier.weight(1f), label = { Text("Qty") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number))
                OutlinedTextField(item.price, { item.price = it }, modifier = Modifier.weight(1f), label = { Text("Unit price") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal))
                if (items.size > 1) {
                    Column(Modifier.width(60.dp)) {
                        Spacer(Modifier.size(8.dp))
                        HSecondaryButton("✕", modifier = Modifier.fillMaxWidth()) { items.removeAt(i) }
                    }
                }
            }
            Text("Line total  ${money(lineTotal(item))}", color = Handy.palette.textSecondary, fontSize = 12.sp)
        }
        Spacer(Modifier.size(10.dp))
        HSecondaryButton("+ Add item", modifier = Modifier.fillMaxWidth()) { items.add(ItemState()) }

        Spacer(Modifier.size(16.dp))
        OutlinedTextField(notes, { notes = it }, modifier = Modifier.fillMaxWidth(), label = { Text("Notes (optional)") }, minLines = 2)

        Spacer(Modifier.size(16.dp))
        Column(Modifier.fillMaxWidth()) {
            SummaryRow("Subtotal", money(subtotal))
            if ((taxPct.toDoubleOrNull() ?: 0.0) > 0) SummaryRow("Tax (${taxPct}%)", money(tax))
            SummaryRow("Total", money(grand), bold = true)
        }

        Spacer(Modifier.size(16.dp))
        HPrimaryButton("Export PDF invoice", modifier = Modifier.fillMaxWidth(), enabled = canExport) { export() }

        Spacer(Modifier.size(16.dp))
        BannerAd()
    }
}

@Composable
private fun SummaryRow(label: String, value: String, bold: Boolean = false) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, fontWeight = if (bold) FontWeight.Bold else FontWeight.Normal, color = MaterialTheme.colorScheme.onBackground, fontSize = if (bold) 16.sp else 14.sp)
        Text(value, fontWeight = if (bold) FontWeight.Bold else FontWeight.Normal, color = MaterialTheme.colorScheme.onBackground, fontSize = if (bold) 16.sp else 14.sp)
    }
    Spacer(Modifier.size(4.dp))
}

/** A4 at 72dpi (595x842pt). One page; long item lists continue onto further pages. */
private fun buildInvoicePdf(
    ctx: Context, from: String, billTo: String, number: String, date: String, currency: String,
    items: List<Triple<String, Double, Double>>, taxPct: Double, notes: String,
): File {
    val w = 595; val h = 842; val margin = 40f
    val doc = PdfDocument()
    fun money(v: Double) = "$currency${"%,.2f".format(v)}"

    val title = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = AndroidColor.BLACK; textSize = 28f; isFakeBoldText = true }
    val label = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = AndroidColor.rgb(110, 110, 110); textSize = 10f }
    val body = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = AndroidColor.BLACK; textSize = 12f }
    val bodyBold = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = AndroidColor.BLACK; textSize = 12f; isFakeBoldText = true }
    val rule = Paint().apply { color = AndroidColor.rgb(210, 210, 210); strokeWidth = 1f }

    val colQtyR = w - margin - 180f   // right edge of qty column
    val colUnitR = w - margin - 90f   // right edge of unit column
    val colAmtR = w - margin          // right edge of amount column
    fun right(c: android.graphics.Canvas, s: String, xRight: Float, y: Float, p: Paint) {
        c.drawText(s, xRight - p.measureText(s), y, p)
    }

    var pageNo = 1
    var info = PdfDocument.PageInfo.Builder(w, h, pageNo).create()
    var page = doc.startPage(info)
    var c = page.canvas
    var y = margin + 20f

    c.drawText("INVOICE", margin, y, title); y += 28f
    c.drawText("#$number   ·   $date", margin, y, label); y += 24f

    c.drawText("FROM", margin, y, label)
    c.drawText("BILL TO", w / 2f, y, label); y += 14f
    c.drawText(from, margin, y, body)
    c.drawText(billTo, w / 2f, y, body); y += 28f

    c.drawLine(margin, y, w - margin, y, rule); y += 16f
    c.drawText("Description", margin, y, bodyBold)
    right(c, "Qty", colQtyR, y, bodyBold)
    right(c, "Unit", colUnitR, y, bodyBold)
    right(c, "Amount", colAmtR, y, bodyBold); y += 8f
    c.drawLine(margin, y, w - margin, y, rule); y += 18f

    var subtotal = 0.0
    for ((desc, qty, price) in items) {
        if (y > h - margin - 120f) {
            doc.finishPage(page)
            pageNo += 1
            info = PdfDocument.PageInfo.Builder(w, h, pageNo).create()
            page = doc.startPage(info); c = page.canvas; y = margin + 20f
        }
        val amt = qty * price
        subtotal += amt
        // description may wrap; keep it simple with a single truncated line
        val maxDesc = colQtyR - margin - 70f
        var d = desc
        while (body.measureText(d) > maxDesc && d.length > 4) d = d.dropLast(2)
        if (d != desc) d = d.dropLast(1) + "…"
        c.drawText(d, margin, y, body)
        right(c, trimNum(qty), colQtyR, y, body)
        right(c, money(price), colUnitR, y, body)
        right(c, money(amt), colAmtR, y, body)
        y += 18f
    }

    y += 8f
    c.drawLine(colUnitR - 40f, y, w - margin, y, rule); y += 18f
    val tax = subtotal * (taxPct / 100.0)
    right(c, "Subtotal", colUnitR, y, body); right(c, money(subtotal), colAmtR, y, body); y += 16f
    if (taxPct > 0) { right(c, "Tax (${trimNum(taxPct)}%)", colUnitR, y, body); right(c, money(tax), colAmtR, y, body); y += 16f }
    right(c, "Total", colUnitR, y, bodyBold); right(c, money(subtotal + tax), colAmtR, y, bodyBold); y += 30f

    if (notes.isNotBlank()) {
        c.drawText("Notes", margin, y, label); y += 14f
        for (line in wrap(notes, body, w - 2 * margin)) { c.drawText(line, margin, y, body); y += 15f }
    }

    doc.finishPage(page)
    val out = File(ctx.cacheDir, "invoice_${number.ifBlank { System.currentTimeMillis().toString() }}.pdf")
    FileOutputStream(out).use { doc.writeTo(it) }
    doc.close()
    return out
}

private fun trimNum(v: Double): String = if (v == v.toLong().toDouble()) v.toLong().toString() else v.toString()

private fun wrap(text: String, paint: Paint, maxWidth: Float): List<String> {
    val out = ArrayList<String>()
    for (para in text.split("\n")) {
        var cur = StringBuilder()
        for (word in para.split(" ")) {
            val trial = if (cur.isEmpty()) word else "$cur $word"
            if (paint.measureText(trial) > maxWidth && cur.isNotEmpty()) { out.add(cur.toString()); cur = StringBuilder(word) }
            else cur = StringBuilder(trial)
        }
        out.add(cur.toString())
    }
    return out
}

package com.handytools.app.tools.invoice

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Color as AndroidColor
import android.graphics.Paint
import android.graphics.pdf.PdfDocument
import android.graphics.pdf.PdfRenderer
import android.os.ParcelFileDescriptor
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handytools.app.HandyApp
import com.handytools.app.I18n
import com.handytools.app.tools.Share
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.HandyHaptics
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.PowerToolPage
import java.io.File
import java.io.FileOutputStream
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

private class ItemState(what: String = "", qty: String = "1", price: String = "") {
    var what by mutableStateOf(what)
    var qty by mutableStateOf(qty)
    var price by mutableStateOf(price)
}

private val DUE_DAYS = listOf(0 to "On receipt", 7 to "7 days", 14 to "14 days", 30 to "30 days")

/**
 * Invoices & Quotes (Business tab; same as the iPhone). Unpaid invoices at the top until marked paid; your details
 * typed once and remembered; totals worked out as you type; Make PDF shows the finished page before you send it.
 * 3 a month free, unlimited with Pro. Everything is made on the phone — nothing is uploaded.
 */
@Composable
fun QuickInvoiceScreen(onUpgrade: () -> Unit = {}) {
    val ctx = LocalContext.current
    val premium = HandyApp.instance.billing.isPremium.value || com.handytools.app.BuildConfig.INTERNAL_UNLOCK
    var docs by remember { mutableStateOf(InvoiceStore.load(ctx)) }
    var made by remember { mutableStateOf(InvoiceStore.madeThisMonth(ctx)) }

    var kind by remember { mutableStateOf(InvoiceLogic.Kind.INVOICE) }
    var from by remember { mutableStateOf(InvoiceStore.from(ctx)) }
    var billTo by remember { mutableStateOf("") }
    var dueDays by remember { mutableStateOf(14) }
    var currency by remember { mutableStateOf("$") }
    var taxPct by remember { mutableStateOf("") }
    var notes by remember { mutableStateOf("") }
    val items = remember { mutableStateListOf(ItemState()) }
    var ready by remember { mutableStateOf<Pair<InvoiceLogic.Doc, File>?>(null) }

    fun draft(): InvoiceLogic.Doc {
        val now = System.currentTimeMillis()
        val days = if (kind == InvoiceLogic.Kind.QUOTE) 30 else dueDays
        return InvoiceLogic.Doc(
            kind = kind, number = InvoiceLogic.nextNumber(kind, docs), date = now, due = now + days * 86_400_000L,
            from = from.trim(), to = billTo.trim(),
            lines = items.filter { it.what.isNotBlank() }.map { InvoiceLogic.Line(it.what.trim(), InvoiceLogic.number(it.qty), InvoiceLogic.number(it.price)) },
            taxPercent = InvoiceLogic.number(taxPct), notes = notes.trim(), currency = currency,
        )
    }
    val d = draft()
    val canMake = d.from.isNotEmpty() && d.to.isNotEmpty() && d.lines.any { it.amount > 0 }
    val left = InvoiceLogic.left(made, premium)
    fun money(v: Double, cur: String = currency) = "$cur${"%,.2f".format(v)}"

    fun show(doc: InvoiceLogic.Doc) { ready = doc to buildInvoicePdf(ctx, doc) }

    PowerToolPage("invoice") {
        val unpaid = InvoiceLogic.unpaid(docs)
        if (unpaid.isNotEmpty()) {
            Text(I18n.t("Waiting to be paid"), fontWeight = FontWeight.SemiBold, fontSize = 17.sp, color = MaterialTheme.colorScheme.onBackground)
            Spacer(Modifier.size(6.dp))
            unpaid.forEach { u ->
                val late = u.overdue(System.currentTimeMillis())
                Row(
                    Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).clickable { show(u) }.padding(vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text(u.who.ifEmpty { u.number }, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onBackground, maxLines = 1)
                        val dueText = u.due?.let { SimpleDateFormat("d MMM", Locale.getDefault()).format(Date(it)) } ?: ""
                        Text("${u.number} · ${I18n.t(if (late) "Overdue since" else "Due")} $dueText", fontSize = 12.sp,
                            color = if (late) Color(0xFFE53935) else Handy.palette.textSecondary)
                    }
                    Text(money(u.total, u.currency), fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onBackground)
                    Spacer(Modifier.width(8.dp))
                    HSecondaryButton("Paid", modifier = Modifier.testTag("invoice-paid-${u.number}")) {
                        InvoiceStore.setPaid(ctx, u.id, true); docs = InvoiceStore.load(ctx); HandyHaptics.success(ctx)
                    }
                }
            }
            Spacer(Modifier.size(16.dp))
        }

        val r = ready
        if (r != null) {
            val (doc, file) = r
            Text(I18n.t(if (doc.kind == InvoiceLogic.Kind.QUOTE) "Quote %s is ready" else "Invoice %s is ready").replace("%s", doc.number),
                fontWeight = FontWeight.Bold, fontSize = 18.sp, color = MaterialTheme.colorScheme.onBackground)
            Spacer(Modifier.size(8.dp))
            // The finished page, before it's sent.
            val preview = remember(file) { pdfPreview(file) }
            preview?.let { bmp ->
                Image(bmp.asImageBitmap(), I18n.t("Preview"), contentScale = ContentScale.FillWidth,
                    modifier = Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).border(1.dp, Handy.palette.border, RoundedCornerShape(12.dp)).testTag("invoice-preview"))
            }
            Spacer(Modifier.size(12.dp))
            HPrimaryButton("Send", modifier = Modifier.fillMaxWidth().testTag("invoice-send")) { Share.file(ctx, file, "application/pdf") }
            Spacer(Modifier.size(8.dp))
            HSecondaryButton("Make another", modifier = Modifier.fillMaxWidth().testTag("invoice-another")) { ready = null }
            return@PowerToolPage
        }

        Row(horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
            Chip("Invoice", kind == InvoiceLogic.Kind.INVOICE) { kind = InvoiceLogic.Kind.INVOICE }
            Chip("Quote", kind == InvoiceLogic.Kind.QUOTE) { kind = InvoiceLogic.Kind.QUOTE }
            Spacer(Modifier.weight(1f))
            Text(d.number, fontSize = 12.sp, color = Handy.palette.textSecondary)
        }
        Spacer(Modifier.size(10.dp))
        OutlinedTextField(from, { from = it; InvoiceStore.setFrom(ctx, it) }, modifier = Modifier.fillMaxWidth(), minLines = 2,
            label = { Text(I18n.t("From — your name or business, phone, email")) })
        Spacer(Modifier.size(10.dp))
        OutlinedTextField(billTo, { billTo = it }, modifier = Modifier.fillMaxWidth(), minLines = 2,
            label = { Text(I18n.t(if (kind == InvoiceLogic.Kind.QUOTE) "For — customer name and address" else "Bill to — customer name and address")) })

        Spacer(Modifier.size(16.dp))
        Text(I18n.t("What for"), fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onBackground)
        items.forEachIndexed { i, item ->
            Spacer(Modifier.size(8.dp))
            OutlinedTextField(item.what, { item.what = it }, modifier = Modifier.fillMaxWidth(), label = { Text(I18n.t("Work done or item sold")) })
            Spacer(Modifier.size(6.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp), verticalAlignment = Alignment.CenterVertically) {
                OutlinedTextField(item.qty, { item.qty = it }, modifier = Modifier.width(76.dp), label = { Text(I18n.t("Qty")) },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal))
                OutlinedTextField(item.price, { item.price = it }, modifier = Modifier.weight(1f), label = { Text(I18n.t("Price each")) },
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal))
                if (items.size > 1) HSecondaryButton("✕", modifier = Modifier.width(56.dp)) { items.removeAt(i) }
            }
        }
        Spacer(Modifier.size(8.dp))
        HSecondaryButton("Add a line", modifier = Modifier.fillMaxWidth()) { items.add(ItemState()) }

        Spacer(Modifier.size(12.dp))
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(currency, { currency = it.take(3) }, modifier = Modifier.width(80.dp), label = { Text(I18n.t("Symbol")) })
            OutlinedTextField(taxPct, { taxPct = it }, modifier = Modifier.weight(1f), label = { Text(I18n.t("Tax %")) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal))
        }
        Text(I18n.t("Use the tax rate that applies to you — check with your accountant if you're not sure."), fontSize = 12.sp, color = Handy.palette.textSecondary)
        if (kind == InvoiceLogic.Kind.INVOICE) {
            Spacer(Modifier.size(10.dp))
            Text(I18n.t("Due"), fontSize = 13.sp, color = Handy.palette.textSecondary)
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) { DUE_DAYS.forEach { (n, label) -> Chip(label, dueDays == n) { dueDays = n } } }
        } else {
            Text(I18n.t("Valid for 30 days"), fontSize = 13.sp, color = Handy.palette.textSecondary)
        }
        Spacer(Modifier.size(10.dp))
        OutlinedTextField(notes, { notes = it }, modifier = Modifier.fillMaxWidth(), minLines = 2, label = { Text(I18n.t("Notes — payment details, thank-you (optional)")) })

        Spacer(Modifier.size(14.dp))
        Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(MaterialTheme.colorScheme.surface).padding(12.dp)) {
            SummaryRow("Subtotal", money(d.subtotal))
            if (d.taxPercent > 0) SummaryRow("${I18n.t("Tax")} (${InvoiceLogic.qty(d.taxPercent)}%)", money(d.tax))
            SummaryRow("Total", money(d.total), bold = true)
        }
        Spacer(Modifier.size(14.dp))
        if (left == 0) {
            Text(I18n.t("You've made 3 this month"), fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onBackground)
            Text(I18n.t("Tenzy Pro makes as many invoices and quotes as you need."), fontSize = 13.sp, color = Handy.palette.textSecondary)
            Spacer(Modifier.size(8.dp))
            HPrimaryButton("See Tenzy Pro", modifier = Modifier.fillMaxWidth()) { onUpgrade() }
        } else {
            HPrimaryButton("Make PDF", modifier = Modifier.fillMaxWidth().testTag("invoice-make"), enabled = canMake) {
                val doc = draft()
                InvoiceStore.add(ctx, doc); docs = InvoiceStore.load(ctx); made = InvoiceStore.madeThisMonth(ctx)
                show(doc); HandyHaptics.success(ctx)
                billTo = ""; notes = ""; items.clear(); items.add(ItemState())
            }
            if (left != null) Text(I18n.t("%d of 3 free this month left").replace("%d", left.toString()), fontSize = 12.sp, color = Handy.palette.textSecondary)
            if (!canMake) Text(I18n.t("Add who it's from, who it's for, and at least one line with a price."), fontSize = 12.sp, color = Handy.palette.textSecondary)
        }
        Spacer(Modifier.size(6.dp))
        Text(I18n.t("Stays on your phone. Nothing is uploaded."), fontSize = 12.sp, color = Handy.palette.textSecondary)
    }
}

@Composable
private fun Chip(label: String, on: Boolean, onClick: () -> Unit) {
    Text(
        I18n.t(label), fontSize = 13.sp, fontWeight = FontWeight.Medium,
        color = if (on) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
        modifier = Modifier.heightIn(min = 36.dp).clip(RoundedCornerShape(50))
            .background(if (on) MaterialTheme.colorScheme.primary.copy(alpha = 0.14f) else MaterialTheme.colorScheme.surface)
            .border(1.dp, if (on) MaterialTheme.colorScheme.primary else Handy.palette.border, RoundedCornerShape(50))
            .clickable(onClick = onClick).padding(horizontal = 14.dp, vertical = 8.dp),
    )
}

@Composable
private fun SummaryRow(label: String, value: String, bold: Boolean = false) {
    Row(Modifier.fillMaxWidth().padding(vertical = 2.dp), horizontalArrangement = Arrangement.SpaceBetween) {
        Text(I18n.t(label), fontWeight = if (bold) FontWeight.Bold else FontWeight.Normal, color = MaterialTheme.colorScheme.onBackground, fontSize = if (bold) 16.sp else 14.sp)
        Text(value, fontWeight = if (bold) FontWeight.Bold else FontWeight.Normal, color = MaterialTheme.colorScheme.onBackground, fontSize = if (bold) 20.sp else 14.sp)
    }
}

/** The first page as a picture, for the preview before sending. */
private fun pdfPreview(file: File): Bitmap? = runCatching {
    ParcelFileDescriptor.open(file, ParcelFileDescriptor.MODE_READ_ONLY).use { fd ->
        PdfRenderer(fd).use { r ->
            r.openPage(0).use { p ->
                val bmp = Bitmap.createBitmap(p.width * 2, p.height * 2, Bitmap.Config.ARGB_8888)
                bmp.eraseColor(AndroidColor.WHITE)
                p.render(bmp, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                bmp
            }
        }
    }
}.getOrNull()

/** US Letter where people use it, A4 elsewhere; long lists continue on more pages with the column heads repeated. */
private fun buildInvoicePdf(ctx: Context, d: InvoiceLogic.Doc): File {
    val letter = Locale.getDefault().country in setOf("US", "CA", "MX", "PH", "CL", "CO", "VE")
    val w = if (letter) 612 else 595; val h = if (letter) 792 else 842; val margin = 48f
    val doc = PdfDocument()
    fun money(v: Double) = "${d.currency}${"%,.2f".format(v)}"
    val df = SimpleDateFormat("d MMM yyyy", Locale.getDefault())
    val quote = d.kind == InvoiceLogic.Kind.QUOTE

    val title = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = AndroidColor.rgb(20, 20, 20); textSize = 26f; isFakeBoldText = true }
    val label = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = AndroidColor.rgb(107, 107, 107); textSize = 9.5f; isFakeBoldText = true }
    val meta = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = AndroidColor.rgb(107, 107, 107); textSize = 11f }
    val body = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = AndroidColor.rgb(20, 20, 20); textSize = 11.5f }
    val bold = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = AndroidColor.rgb(20, 20, 20); textSize = 14f; isFakeBoldText = true }
    val rule = Paint().apply { color = AndroidColor.rgb(214, 214, 214); strokeWidth = 0.75f }
    val accent = Paint().apply { color = AndroidColor.rgb(13, 148, 136) }

    val colAmt = w - margin; val colUnit = colAmt - 96f; val colQty = colUnit - 92f
    fun right(c: android.graphics.Canvas, s: String, x: Float, y: Float, p: Paint) = c.drawText(s, x - p.measureText(s), y, p)

    var pageNo = 1
    var page = doc.startPage(PdfDocument.PageInfo.Builder(w, h, pageNo).create())
    var c = page.canvas
    var y = margin
    fun heads() {
        c.drawText(I18n.t("Description"), margin, y, label); right(c, I18n.t("Qty"), colQty, y, label)
        right(c, I18n.t("Price"), colUnit, y, label); right(c, I18n.t("Amount"), colAmt, y, label)
        y += 8f; c.drawLine(margin, y, w - margin, y, rule); y += 18f
    }

    c.drawRect(margin, y, margin + 36f, y + 4f, accent); y += 34f
    c.drawText(I18n.t(if (quote) "QUOTE" else "INVOICE"), margin, y, title); y += 20f
    val dueLabel = d.due?.let { "  ·  " + I18n.t(if (quote) "Valid until" else "Due") + " " + df.format(Date(it)) } ?: ""
    c.drawText("${d.number}  ·  ${df.format(Date(d.date))}$dueLabel", margin, y, meta); y += 30f

    c.drawText(I18n.t("FROM"), margin, y, label); c.drawText(I18n.t(if (quote) "FOR" else "BILL TO"), w / 2f, y, label); y += 15f
    val fromLines = d.from.lines(); val toLines = d.to.lines()
    for (i in 0 until maxOf(fromLines.size, toLines.size)) {
        fromLines.getOrNull(i)?.let { c.drawText(it, margin, y, body) }
        toLines.getOrNull(i)?.let { c.drawText(it, w / 2f, y, body) }
        y += 15f
    }
    y += 20f
    heads()

    for (l in d.lines) {
        if (y > h - margin - 60f) {
            doc.finishPage(page); pageNo += 1
            page = doc.startPage(PdfDocument.PageInfo.Builder(w, h, pageNo).create()); c = page.canvas; y = margin + 10f
            heads()
        }
        val maxDesc = colQty - margin - 52f
        var desc = l.what
        while (body.measureText(desc) > maxDesc && desc.length > 4) desc = desc.dropLast(2)
        if (desc != l.what) desc = desc.dropLast(1) + "…"
        c.drawText(desc, margin, y, body)
        right(c, InvoiceLogic.qty(l.qty), colQty, y, body); right(c, money(l.price), colUnit, y, body); right(c, money(l.amount), colAmt, y, body)
        y += 20f
    }

    if (y > h - margin - 110f) { doc.finishPage(page); pageNo += 1; page = doc.startPage(PdfDocument.PageInfo.Builder(w, h, pageNo).create()); c = page.canvas; y = margin + 10f }
    y += 4f; c.drawLine(colQty - 40f, y, w - margin, y, rule); y += 18f
    right(c, I18n.t("Subtotal"), colUnit, y, meta); right(c, money(d.subtotal), colAmt, y, body); y += 17f
    if (d.taxPercent > 0) { right(c, "${I18n.t("Tax")} (${InvoiceLogic.qty(d.taxPercent)}%)", colUnit, y, meta); right(c, money(d.tax), colAmt, y, body); y += 17f }
    right(c, I18n.t("Total"), colUnit, y, bold); right(c, money(d.total), colAmt, y, bold); y += 34f

    if (d.notes.isNotBlank()) {
        c.drawText(I18n.t("NOTES"), margin, y, label); y += 15f
        for (line in d.notes.lines()) { c.drawText(line, margin, y, body); y += 15f }
    }

    doc.finishPage(page)
    val out = File(ctx.cacheDir, (if (quote) "Quote " else "Invoice ") + d.number + ".pdf")
    FileOutputStream(out).use { doc.writeTo(it) }
    doc.close()
    return out
}

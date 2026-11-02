package com.handytools.app.tools.power

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import com.handytools.app.ui.ChipRow
import com.handytools.app.ui.HCard
import com.handytools.app.ui.HChip
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyColors
import com.handytools.app.ui.NoteText
import com.handytools.app.ui.PowerToolPage
import com.handytools.app.ui.SectionLabel

private data class PUnit(val label: String, val type: Int, val base: Double) // type 0=weight(g) 1=volume(ml) 2=count
private val UNITS = listOf(
    PUnit("g", 0, 1.0), PUnit("kg", 0, 1000.0), PUnit("oz", 0, 28.3495), PUnit("lb", 0, 453.592),
    PUnit("ml", 1, 1.0), PUnit("L", 1, 1000.0), PUnit("fl oz", 1, 29.5735),
    PUnit("each", 2, 1.0),
)

private class PriceItem {
    var name by mutableStateOf("")
    var price by mutableStateOf("")
    var qty by mutableStateOf("")
    var unit by mutableStateOf(0)
}

/** price per base unit (per g / per ml / per each), or null if the inputs aren't usable yet. */
private fun unitPrice(it: PriceItem): Double? {
    val p = it.price.replace(",", "").toDoubleOrNull() ?: return null
    val q = it.qty.replace(",", "").toDoubleOrNull() ?: return null
    if (p <= 0 || q <= 0) return null
    val u = UNITS[it.unit]
    return p / (q * u.base)
}

private fun displayUnit(it: PriceItem, upb: Double): String = when (UNITS[it.unit].type) {
    0 -> "$%.2f / 100 g".format(upb * 100)
    1 -> "$%.2f / L".format(upb * 1000)
    else -> "$%.2f each".format(upb)
}

/**
 * Price Check — the real cost of each option, so the "bigger" pack isn't a trick. Enter the price and
 * size of two or more products and it works out the price per 100 g / per litre / per unit and points
 * at the best value. All on your phone.
 */
@Composable
fun PriceCheckToolScreen() {
    val items = remember { mutableStateListOf(PriceItem(), PriceItem()) }

    PowerToolPage("pricecheck") {
        // Work out the winner among items that share a measure (weight vs weight, etc).
        val valued = items.mapNotNull { item -> unitPrice(item)?.let { item to it } }
        val byType = valued.groupBy { UNITS[it.first.unit].type }
        val bestGroup = byType.values.maxByOrNull { it.size }
        val best = bestGroup?.minByOrNull { it.second }
        val mixed = byType.size > 1

        if (best != null && (bestGroup?.size ?: 0) >= 2) {
            val next = bestGroup!!.filter { it !== best }.minByOrNull { it.second }
            val savePct = next?.let { ((it.second - best.second) / it.second * 100).toInt() }
            HCard(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(16.dp)) {
                    Text("BEST VALUE", style = MaterialTheme.typography.labelSmall, color = HandyColors.Accent)
                    Spacer(Modifier.height(4.dp))
                    Text(best.first.name.ifBlank { "Option ${items.indexOf(best.first) + 1}" }, style = MaterialTheme.typography.titleMedium, fontWeight = FontWeight.Bold)
                    Spacer(Modifier.height(2.dp))
                    Text(displayUnit(best.first, best.second) + (if (savePct != null && savePct > 0) " · ${savePct}% cheaper" else ""),
                        style = MaterialTheme.typography.bodyMedium, color = Handy.palette.textSecondary)
                }
            }
            Spacer(Modifier.height(6.dp))
        }
        if (mixed) { NoteText("You're mixing weight, volume and count — compare like with like for a fair result."); Spacer(Modifier.height(6.dp)) }

        items.forEachIndexed { idx, item ->
            val upb = unitPrice(item)
            val isBest = best != null && item === best.first && (bestGroup?.size ?: 0) >= 2
            HCard(Modifier.fillMaxWidth()) {
                Column(Modifier.padding(14.dp)) {
                    OutlinedTextField(item.name, { item.name = it }, modifier = Modifier.fillMaxWidth(), label = { Text("Name (optional)") }, singleLine = true)
                    Spacer(Modifier.height(8.dp))
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                        OutlinedTextField(item.price, { item.price = it.filter { c -> c.isDigit() || c == '.' } }, modifier = Modifier.weight(1f), label = { Text("Price $") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), singleLine = true)
                        OutlinedTextField(item.qty, { item.qty = it.filter { c -> c.isDigit() || c == '.' } }, modifier = Modifier.weight(1f), label = { Text("Size") }, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Decimal), singleLine = true)
                    }
                    Spacer(Modifier.height(8.dp))
                    ChipRow { UNITS.forEachIndexed { ui, u -> HChip(u.label, item.unit == ui) { item.unit = ui } } }
                    if (upb != null) {
                        Spacer(Modifier.height(8.dp))
                        Text(displayUnit(item, upb), style = MaterialTheme.typography.bodyLarge, fontWeight = FontWeight.SemiBold,
                            color = if (isBest) HandyColors.Accent else MaterialTheme.colorScheme.onSurface)
                    }
                }
            }
            if (items.size > 2) {
                Spacer(Modifier.height(4.dp))
                HSecondaryButton("Remove option ${idx + 1}", Modifier.fillMaxWidth()) { items.remove(item) }
            }
            Spacer(Modifier.height(10.dp))
        }

        if (items.size < 4) HPrimaryButton("Add another option") { items.add(PriceItem()) }
        NoteText("Enter each product's price and size, then its unit. Tenzy normalises them to the same measure so you can see which is genuinely cheaper — the bigger pack often isn't.")
    }
}

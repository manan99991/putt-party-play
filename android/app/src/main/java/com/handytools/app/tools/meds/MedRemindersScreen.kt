package com.handytools.app.tools.meds

import android.Manifest
import android.app.DatePickerDialog
import android.app.TimePickerDialog
import android.content.ClipboardManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import android.text.format.DateFormat
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
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
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handytools.app.I18n
import com.handytools.app.Permissions
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HandyHaptics
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.HSecondaryButton
import com.handytools.app.ui.PowerToolPage
import java.util.Calendar

/**
 * Medicine Reminders (Android, same as the iPhone): today's doses with a Taken tap, your medicines in plain words, a
 * refill alert from an optional pill count, and Family & caregiver (a second nudge for a missed dose, an update to send
 * someone, and sending the list to another phone — iPhone or Android). Alerts come with Taken and Snooze buttons.
 */
@Composable
fun MedRemindersScreen() {
    val ctx = LocalContext.current
    val is24 = DateFormat.is24HourFormat(ctx)
    var data by remember { mutableStateOf(MedStore.load(ctx)) }
    val (meds, log) = data
    fun reload() { data = MedStore.load(ctx) }
    var editing by remember { mutableStateOf<Med?>(null) }
    var allowed by remember { mutableStateOf(Permissions.canPostNotifications(ctx)) }
    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { ok -> allowed = ok }
    LaunchedEffect(Unit) { MedAlarms.sync(ctx) }

    val e = editing
    if (e != null) {
        MedEditor(e, is24, onSave = { m ->
            val list = if (meds.any { it.id == m.id }) meds.map { if (it.id == m.id) m else it } else meds + m
            MedStore.save(ctx, list, log); reload(); editing = null
            if (!allowed && Build.VERSION.SDK_INT >= 33) ask.launch(Manifest.permission.POST_NOTIFICATIONS)
        }, onDelete = { m ->
            MedStore.save(ctx, meds.filterNot { it.id == m.id }, log.filterNot { it.medId == m.id }); reload(); editing = null
        }, onCancel = { editing = null })
        return
    }

    PowerToolPage("medreminder") {
        Text(I18n.t("A reminder tool, not medical advice — always follow your doctor's or pharmacist's instructions. Stays on this phone."),
            fontSize = 12.sp, color = Handy.palette.textSecondary)
        Spacer(Modifier.size(12.dp))

        if (meds.isNotEmpty() && !allowed) {
            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).background(Color(0x33E53935)).padding(12.dp)) {
                Text(I18n.t("Alerts are off, so reminders can't reach you."), fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onBackground)
                Spacer(Modifier.size(8.dp))
                HPrimaryButton("Turn on alerts") {
                    if (Build.VERSION.SDK_INT >= 33) ask.launch(Manifest.permission.POST_NOTIFICATIONS)
                    else ctx.startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, ctx.packageName))
                }
            }
            Spacer(Modifier.size(12.dp))
        }

        if (meds.isEmpty()) {
            Text(I18n.t("Add your first medicine — name, dose and when. Tenzy reminds you, and you tap Taken right from the alert."),
                color = MaterialTheme.colorScheme.onBackground)
            Spacer(Modifier.size(12.dp))
            HPrimaryButton("Add a medicine", modifier = Modifier.testTag("med-add")) { editing = Med() }
            return@PowerToolPage
        }

        // Today
        val now = System.currentTimeMillis()
        val today = MedLogic.today(meds, now)
        Text(I18n.t("Today"), fontWeight = FontWeight.SemiBold, fontSize = 17.sp, color = MaterialTheme.colorScheme.onBackground)
        if (today.isEmpty()) Text(I18n.t("Nothing due today."), fontSize = 13.sp, color = Handy.palette.textSecondary)
        today.forEach { (m, at) ->
            val taken = MedStore.isTaken(log, m, at)
            val late = !taken && at < now - 3_600_000
            Row(
                Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).clickable {
                    MedStore.setTaken(ctx, m.id, at, !taken); reload(); if (!taken) HandyHaptics.success(ctx)
                }.testTag("med-dose").padding(vertical = 10.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(if (taken) "✓" else "○", fontSize = 20.sp, color = if (taken) MaterialTheme.colorScheme.primary else Handy.palette.textSecondary,
                    modifier = Modifier.width(32.dp))
                Column(Modifier.weight(1f)) {
                    Text(m.name, fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onBackground)
                    Text(listOf(m.dose, m.note).filter { it.isNotBlank() }.joinToString(" · "), fontSize = 12.sp, color = Handy.palette.textSecondary)
                }
                Column(horizontalAlignment = Alignment.End) {
                    Text(timeLabel(at, is24), color = MaterialTheme.colorScheme.onBackground)
                    if (late) Text(I18n.t("Missed?"), fontSize = 12.sp, color = Color(0xFFE53935))
                }
            }
        }
        val (wTaken, wDue, _) = MedStore.week(meds, log)
        if (wDue > 0) Text(I18n.t("This week") + ": $wTaken / $wDue", fontSize = 13.sp, color = Handy.palette.textSecondary)

        // Your medicines
        Spacer(Modifier.size(18.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(I18n.t("Your medicines"), fontWeight = FontWeight.SemiBold, fontSize = 17.sp, color = MaterialTheme.colorScheme.onBackground,
                modifier = Modifier.weight(1f))
            HSecondaryButton("Add", modifier = Modifier.width(96.dp).testTag("med-add")) { editing = Med() }
        }
        meds.forEach { m ->
            Column(Modifier.fillMaxWidth().clip(RoundedCornerShape(12.dp)).clickable { editing = m }.padding(vertical = 8.dp)) {
                Text(m.name + if (m.paused) "  · " + I18n.t("Paused") else "", fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onBackground)
                Text(MedLogic.summary(m, is24), fontSize = 12.sp, color = Handy.palette.textSecondary)
            }
        }

        Spacer(Modifier.size(18.dp))
        Caregiver(meds, log, is24, onImport = { added -> MedStore.save(ctx, meds + added, log); reload() })

        Spacer(Modifier.size(12.dp))
        HSecondaryButton("Test run") {
            meds.firstOrNull { !it.paused }?.let { MedAlarms.postDose(ctx, it, System.currentTimeMillis()) }
        }
        Text(I18n.t("Sends you a dose alert now, exactly as it will come."), fontSize = 12.sp, color = Handy.palette.textSecondary)
        Text(I18n.t("Android lets only alarm-clock apps ring at the exact minute, so an alert can arrive a few minutes after its time when the phone is resting."),
            fontSize = 12.sp, color = Handy.palette.textSecondary)
    }
}

private fun timeLabel(at: Long, is24: Boolean): String {
    val c = Calendar.getInstance().apply { timeInMillis = at }
    return TimeOfDay(c.get(Calendar.HOUR_OF_DAY), c.get(Calendar.MINUTE)).label(is24)
}

@Composable
private fun Caregiver(meds: List<Med>, log: List<DoseLog>, is24: Boolean, onImport: (List<Med>) -> Unit) {
    val ctx = LocalContext.current
    val prefs = remember { ctx.getSharedPreferences("medcare", 0) }
    var follow by remember { mutableStateOf(prefs.getInt("followup", 0)) }
    var name by remember { mutableStateOf(prefs.getString("name", "") ?: "") }
    var phone by remember { mutableStateOf(prefs.getString("phone", "") ?: "") }
    var note by remember { mutableStateOf<String?>(null) }

    Text(I18n.t("Family & caregiver"), fontWeight = FontWeight.SemiBold, fontSize = 17.sp, color = MaterialTheme.colorScheme.onBackground)
    Text(I18n.t("Nudge me again if I haven't tapped Taken"), fontSize = 13.sp, color = Handy.palette.textSecondary)
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        listOf(0 to "Off", 15 to "15 min", 30 to "30 min", 60 to "1 hour").forEach { (n, label) ->
            Chip(label, follow == n) { follow = n; prefs.edit().putInt("followup", n).apply(); MedAlarms.sync(ctx) }
        }
    }
    Spacer(Modifier.size(10.dp))
    OutlinedTextField(name, { name = it; prefs.edit().putString("name", it).apply() }, modifier = Modifier.fillMaxWidth(),
        label = { Text(I18n.t("Someone who helps — a son, a daughter, a nurse")) }, singleLine = true)
    OutlinedTextField(phone, { phone = it; prefs.edit().putString("phone", it).apply() }, modifier = Modifier.fillMaxWidth(),
        label = { Text(I18n.t("Their phone number")) }, singleLine = true, keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Phone))
    Spacer(Modifier.size(8.dp))
    if (phone.any { it.isDigit() }) {
        HPrimaryButton("Text an update") {
            val (t, d, missed) = MedStore.week(meds, log)
            val today = MedLogic.today(meds, System.currentTimeMillis()).map { (m, at) -> Triple(m.name, timeLabel(at, is24), MedStore.isTaken(log, m, at)) }
            val body = MedLogic.update(name, meds, t, d, missed, today)
            runCatching { ctx.startActivity(Intent(Intent.ACTION_SENDTO, Uri.parse("smsto:" + phone.filter { it.isDigit() || it == '+' })).putExtra("sms_body", body)) }
        }
        Text(I18n.t("Tenzy writes it; you see it and tap send. It never texts anyone by itself."), fontSize = 12.sp, color = Handy.palette.textSecondary)
        Spacer(Modifier.size(8.dp))
    }
    HSecondaryButton("Send the list to another phone") {
        runCatching { ctx.startActivity(Intent.createChooser(Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, MedCodec.shareMessage(meds)), null)) }
    }
    Spacer(Modifier.size(8.dp))
    HSecondaryButton("Paste a list someone sent me") {
        val text = (ctx.getSystemService(ClipboardManager::class.java)?.primaryClip?.getItemAt(0)?.coerceToText(ctx))?.toString().orEmpty()
        val found = MedCodec.imported(text)
        if (found == null) note = I18n.t("Copy their whole message first, then tap Paste.")
        else { onImport(found); note = I18n.t("Added") + ": " + found.joinToString(", ") { it.name } }
    }
    note?.let { Text(it, fontSize = 13.sp, color = MaterialTheme.colorScheme.primary) }
}

@Composable
private fun Chip(label: String, on: Boolean, onClick: () -> Unit) {
    Text(
        I18n.t(label), fontSize = 13.sp, fontWeight = FontWeight.Medium,
        color = if (on) MaterialTheme.colorScheme.primary else MaterialTheme.colorScheme.onSurface,
        modifier = Modifier.heightIn(min = 36.dp).clip(RoundedCornerShape(50))
            .background(if (on) MaterialTheme.colorScheme.primary.copy(alpha = 0.14f) else MaterialTheme.colorScheme.surface)
            .border(1.dp, if (on) MaterialTheme.colorScheme.primary else Handy.palette.border, RoundedCornerShape(50))
            .clickable(onClick = onClick).padding(horizontal = 12.dp, vertical = 8.dp),
    )
}

@Composable
private fun MedEditor(start: Med, is24: Boolean, onSave: (Med) -> Unit, onDelete: (Med) -> Unit, onCancel: () -> Unit) {
    val ctx = LocalContext.current
    var m by remember { mutableStateOf(start) }
    androidx.activity.compose.BackHandler(onBack = onCancel)
    var supply by remember { mutableStateOf(start.supply?.toString() ?: "") }
    var perDose by remember { mutableStateOf(start.perDose?.toString() ?: "1") }
    var refillAt by remember { mutableStateOf(start.refillAt?.toString() ?: "7") }
    val isNew = start.name.isEmpty()

    PowerToolPage("medreminder") {
        OutlinedTextField(m.name, { m = m.copy(name = it) }, modifier = Modifier.fillMaxWidth().testTag("med-name"), singleLine = true,
            label = { Text(I18n.t("Medicine name")) })
        OutlinedTextField(m.dose, { m = m.copy(dose = it) }, modifier = Modifier.fillMaxWidth(), singleLine = true,
            label = { Text(I18n.t("Dose — e.g. 1 tablet, 5 ml")) })
        OutlinedTextField(m.note, { m = m.copy(note = it) }, modifier = Modifier.fillMaxWidth(), singleLine = true,
            label = { Text(I18n.t("Note — e.g. with food (optional)")) })

        Spacer(Modifier.size(14.dp))
        Text(I18n.t("When"), fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onBackground)
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            Chip("Every day", m.pattern == Pattern.DAILY) { m = m.copy(pattern = Pattern.DAILY) }
            Chip("Some days", m.pattern == Pattern.WEEKDAYS) { m = m.copy(pattern = Pattern.WEEKDAYS) }
            Chip("Every few hours", m.pattern == Pattern.EVERY_HOURS) { m = m.copy(pattern = Pattern.EVERY_HOURS) }
        }
        Spacer(Modifier.size(8.dp))
        if (m.pattern == Pattern.WEEKDAYS) {
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                listOf(2 to "M", 3 to "T", 4 to "W", 5 to "T", 6 to "F", 7 to "S", 1 to "S").forEach { (d, l) ->
                    Chip(l, d in m.weekdays) { m = m.copy(weekdays = if (d in m.weekdays) m.weekdays - d else m.weekdays + d) }
                }
            }
            Spacer(Modifier.size(8.dp))
        }
        if (m.pattern == Pattern.EVERY_HOURS) {
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                listOf(4, 6, 8, 12).forEach { h -> Chip("Every $h h", m.everyHours == h) { m = m.copy(everyHours = h) } }
            }
            Text(I18n.t("From") + " ${TimeOfDay(m.firstHour, 0).label(is24)} " + I18n.t("to") + " ${TimeOfDay(m.lastHour, 0).label(is24)}",
                color = MaterialTheme.colorScheme.primary,
                modifier = Modifier.clickable {
                    TimePickerDialog(ctx, { _, h, _ ->
                        TimePickerDialog(ctx, { _, h2, _ -> m = m.copy(firstHour = h, lastHour = maxOf(h, h2)) }, m.lastHour, 0, is24).show()
                    }, m.firstHour, 0, is24).show()
                }.padding(vertical = 10.dp))
            Text(MedLogic.clockTimes(m).joinToString(", ") { it.label(is24) }, fontSize = 12.sp, color = Handy.palette.textSecondary)
        } else {
            m.times.sorted().forEach { t ->
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(t.label(is24), fontSize = 18.sp, color = MaterialTheme.colorScheme.onBackground, modifier = Modifier.weight(1f).clickable {
                        TimePickerDialog(ctx, { _, h, min -> m = m.copy(times = m.times - t + TimeOfDay(h, min)) }, t.hour, t.minute, is24).show()
                    }.padding(vertical = 10.dp))
                    if (m.times.size > 1) Text("✕", color = Handy.palette.textSecondary, modifier = Modifier.clickable { m = m.copy(times = m.times - t) }.padding(12.dp))
                }
            }
            HSecondaryButton("Add a time") {
                TimePickerDialog(ctx, { _, h, min -> m = m.copy(times = (m.times + TimeOfDay(h, min)).distinct()) }, 20, 0, is24).show()
            }
        }

        Spacer(Modifier.size(14.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(I18n.t("Stop on a date"), color = MaterialTheme.colorScheme.onBackground, modifier = Modifier.weight(1f))
            Switch(checked = m.end != null, onCheckedChange = { on ->
                if (!on) m = m.copy(end = null) else {
                    val c = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, 7) }
                    DatePickerDialog(ctx, { _, y, mo, d -> m = m.copy(end = Calendar.getInstance().apply { set(y, mo, d, 0, 0, 0) }.timeInMillis) },
                        c.get(Calendar.YEAR), c.get(Calendar.MONTH), c.get(Calendar.DAY_OF_MONTH)).show()
                }
            })
        }
        m.end?.let { Text(java.text.DateFormat.getDateInstance().format(java.util.Date(it)), fontSize = 13.sp, color = Handy.palette.textSecondary) }

        Spacer(Modifier.size(14.dp))
        Text(I18n.t("Refill"), fontWeight = FontWeight.SemiBold, color = MaterialTheme.colorScheme.onBackground)
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            OutlinedTextField(supply, { supply = it.filter(Char::isDigit) }, modifier = Modifier.weight(1f), label = { Text(I18n.t("Pills left")) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), singleLine = true)
            OutlinedTextField(perDose, { perDose = it.filter(Char::isDigit) }, modifier = Modifier.weight(1f), label = { Text(I18n.t("Per dose")) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), singleLine = true)
            OutlinedTextField(refillAt, { refillAt = it.filter(Char::isDigit) }, modifier = Modifier.weight(1f), label = { Text(I18n.t("Alert at")) },
                keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), singleLine = true)
        }
        Text(I18n.t("You get one alert when the count reaches your number. Tenzy never orders or suggests doses — ask your pharmacist about refills."),
            fontSize = 12.sp, color = Handy.palette.textSecondary)

        Spacer(Modifier.size(18.dp))
        val ok = m.name.isNotBlank() && (m.pattern != Pattern.WEEKDAYS || m.weekdays.isNotEmpty())
        HPrimaryButton("Save", modifier = Modifier.testTag("med-save"), enabled = ok) {
            onSave(m.copy(name = m.name.trim(), supply = supply.toIntOrNull(), perDose = perDose.toIntOrNull()?.takeIf { supply.isNotEmpty() },
                refillAt = refillAt.toIntOrNull()?.takeIf { supply.isNotEmpty() }))
        }
        Spacer(Modifier.size(8.dp))
        if (!isNew) {
            HSecondaryButton(if (m.paused) "Resume reminders" else "Pause reminders") { onSave(m.copy(paused = !m.paused)) }
            Spacer(Modifier.size(8.dp))
            HSecondaryButton("Delete this medicine") { onDelete(m) }
            Spacer(Modifier.size(8.dp))
        }
        HSecondaryButton("Cancel") { onCancel() }
    }
}

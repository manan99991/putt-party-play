package com.handytools.app.tools.power

import android.content.ClipData
import android.content.ClipboardManager
import android.content.ContentValues
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.net.Uri
import android.nfc.NdefRecord
import android.nfc.Tag
import android.nfc.tech.Ndef
import android.os.Build
import android.provider.ContactsContract
import android.provider.MediaStore
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import com.google.zxing.BarcodeFormat
import com.google.zxing.BinaryBitmap
import com.google.zxing.EncodeHintType
import com.google.zxing.MultiFormatReader
import com.google.zxing.RGBLuminanceSource
import com.google.zxing.common.HybridBinarizer
import com.google.zxing.qrcode.QRCodeWriter
import kotlinx.coroutines.tasks.await
import java.io.File
import java.io.FileOutputStream

/**
 * Pure, Compose-free logic for the Codes studio: build QR payloads (text / URL / Wi-Fi / phone /
 * email / vCard), render them to a bitmap with zxing, decode any QR/1D/2D code from an image with
 * ML Kit (zxing fallback), classify the payload so the UI can act on it, and read NDEF records off
 * an NFC tag. Everything runs on-device; nothing is uploaded. Meant to run off the main thread.
 *
 * All types are nested in this object on purpose, so they never collide with the sibling
 * ShareEngine's top-level QR types in the same package.
 */
object CodesEngine {

    enum class Kind { URL, WIFI, CONTACT, EMAIL, PHONE, SMS, GEO, TEXT }

    data class Decoded(val raw: String, val kind: Kind, val isQr: Boolean)
    data class Wifi(val ssid: String, val password: String, val security: String, val hidden: Boolean)
    data class Contact(val name: String, val phone: String, val email: String, val org: String)

    // ------------------------------------------------------------------ generate

    /** Render [text] as a QR bitmap with a quiet margin. Null if the text is too long for a QR. */
    fun qr(text: String, size: Int = 720): Bitmap? = try {
        if (text.isEmpty()) null else {
            val hints = mapOf(EncodeHintType.MARGIN to 1)
            val m = QRCodeWriter().encode(text, BarcodeFormat.QR_CODE, size, size, hints)
            val w = m.width; val h = m.height
            val px = IntArray(w * h)
            for (y in 0 until h) {
                val o = y * w
                for (x in 0 until w) px[o + x] = if (m.get(x, y)) android.graphics.Color.BLACK else android.graphics.Color.WHITE
            }
            Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888).apply { setPixels(px, 0, w, 0, 0, w, h) }
        }
    } catch (_: Exception) { null }

    // ------------------------------------------------------------------ payload builders

    private fun esc(s: String) = s.replace("\\", "\\\\").replace(";", "\\;").replace(",", "\\,").replace(":", "\\:").replace("\"", "\\\"")

    /** security: "WPA", "WEP" or "nopass". Builds WIFI:T:WPA;S:ssid;P:pass;H:true;; */
    fun wifiPayload(ssid: String, password: String, security: String, hidden: Boolean): String {
        val t = if (password.isBlank()) "nopass" else security
        return buildString {
            append("WIFI:T:").append(t).append(';')
            append("S:").append(esc(ssid)).append(';')
            if (password.isNotBlank()) append("P:").append(esc(password)).append(';')
            if (hidden) append("H:true;")
            append(';')
        }
    }

    fun vcardPayload(name: String, phone: String, email: String, org: String): String = buildString {
        append("BEGIN:VCARD\nVERSION:3.0\n")
        if (name.isNotBlank()) append("FN:").append(name.trim()).append('\n')
        if (org.isNotBlank()) append("ORG:").append(org.trim()).append('\n')
        if (phone.isNotBlank()) append("TEL:").append(phone.trim()).append('\n')
        if (email.isNotBlank()) append("EMAIL:").append(email.trim()).append('\n')
        append("END:VCARD")
    }

    fun telPayload(phone: String): String = "tel:" + phone.trim()

    fun mailtoPayload(email: String, subject: String, body: String): String {
        val q = ArrayList<String>()
        if (subject.isNotBlank()) q.add("subject=" + Uri.encode(subject.trim()))
        if (body.isNotBlank()) q.add("body=" + Uri.encode(body.trim()))
        return "mailto:" + email.trim() + (if (q.isEmpty()) "" else "?" + q.joinToString("&"))
    }

    // ------------------------------------------------------------------ classify + parse

    fun classify(raw: String, isQr: Boolean): Decoded {
        val t = raw.trim()
        val lower = t.lowercase()
        val kind = when {
            lower.startsWith("wifi:") -> Kind.WIFI
            lower.startsWith("begin:vcard") || lower.startsWith("mecard:") -> Kind.CONTACT
            lower.startsWith("mailto:") || (t.contains('@') && !t.contains(' ') && t.contains('.') && !lower.startsWith("http")) -> Kind.EMAIL
            lower.startsWith("tel:") -> Kind.PHONE
            lower.startsWith("smsto:") || lower.startsWith("sms:") -> Kind.SMS
            lower.startsWith("geo:") -> Kind.GEO
            Regex("^(https?://|www\\.)", RegexOption.IGNORE_CASE).containsMatchIn(t) -> Kind.URL
            else -> Kind.TEXT
        }
        return Decoded(t, kind, isQr)
    }

    /** Parses WIFI:T:WPA;S:name;P:pass;H:true;; (handles \; \: \\ escapes). */
    fun parseWifi(raw: String): Wifi? {
        val body = raw.trim().let { if (it.length >= 5) it.substring(5) else "" } // drop "WIFI:"
        val fields = HashMap<String, String>()
        val sb = StringBuilder(); var i = 0
        while (i < body.length) {
            val c = body[i]
            if (c == '\\' && i + 1 < body.length) { sb.append(body[i + 1]); i += 2; continue }
            if (c == ';') {
                val f = sb.toString(); sb.setLength(0)
                if (f.isNotEmpty()) {
                    val k = f.substringBefore(':', ""); val v = f.substringAfter(':', "")
                    if (k.isNotEmpty()) fields[k.uppercase()] = v
                }
            } else sb.append(c)
            i++
        }
        val ssid = fields["S"] ?: return null
        if (ssid.isBlank()) return null
        val sec = (fields["T"] ?: "").uppercase().ifBlank { if ((fields["P"] ?: "").isBlank()) "NOPASS" else "WPA" }
        return Wifi(ssid, fields["P"] ?: "", sec, (fields["H"] ?: "").equals("true", true))
    }

    fun parseContact(raw: String): Contact {
        var name = ""; var phone = ""; var email = ""; var org = ""
        val t = raw.trim()
        if (t.startsWith("MECARD:", true)) {
            t.substring(7).split(";").forEach { f ->
                val k = f.substringBefore(':', "").uppercase(); val v = f.substringAfter(':', "")
                when (k) {
                    "N" -> name = v.replace(",", " ").trim()
                    "TEL" -> if (phone.isEmpty()) phone = v
                    "EMAIL" -> if (email.isEmpty()) email = v
                    "ORG" -> org = v
                }
            }
        } else {
            t.lines().forEach { line ->
                val key = line.substringBefore(':').substringBefore(';').uppercase()
                val value = line.substringAfter(':', "").trim()
                when (key) {
                    "FN" -> name = value
                    "N" -> if (name.isEmpty()) name = value.split(";").filter { it.isNotBlank() }.reversed().joinToString(" ")
                    "ORG" -> org = value
                    "TEL" -> if (phone.isEmpty()) phone = value
                    "EMAIL" -> if (email.isEmpty()) email = value
                }
            }
        }
        return Contact(name, phone, email, org)
    }

    // ------------------------------------------------------------------ decode from image

    /** ML Kit first (handles rotated/perspective codes), zxing as a fallback. */
    suspend fun decodeUri(ctx: Context, uri: Uri): Decoded? {
        try {
            val img = InputImage.fromFilePath(ctx, uri)
            val scanner = BarcodeScanning.getClient()
            val codes = try { scanner.process(img).await() } finally { scanner.close() }
            val first = codes.firstOrNull { !it.rawValue.isNullOrBlank() }
            if (first != null) return classify(first.rawValue ?: "", first.format == Barcode.FORMAT_QR_CODE)
        } catch (_: Exception) {}
        return try {
            val bmp = DocEngine.loadBitmap(ctx, uri, 1600) ?: return null
            val w = bmp.width; val h = bmp.height
            val px = IntArray(w * h)
            bmp.getPixels(px, 0, w, 0, 0, w, h)
            val result = MultiFormatReader().decode(BinaryBitmap(HybridBinarizer(RGBLuminanceSource(w, h, px))))
            classify(result.text, result.barcodeFormat == BarcodeFormat.QR_CODE)
        } catch (_: Exception) { null }
    }

    // ------------------------------------------------------------------ clipboard / save / share

    fun copy(ctx: Context, label: String, text: String) {
        (ctx.getSystemService(Context.CLIPBOARD_SERVICE) as ClipboardManager).setPrimaryClip(ClipData.newPlainText(label, text))
    }

    /** Save a PNG into the gallery (Pictures/Tenzy on API 29+). */
    fun savePngToGallery(ctx: Context, bmp: Bitmap, name: String): Boolean = try {
        val values = ContentValues().apply {
            put(MediaStore.Images.Media.DISPLAY_NAME, name)
            put(MediaStore.Images.Media.MIME_TYPE, "image/png")
            if (Build.VERSION.SDK_INT >= 29) put(MediaStore.Images.Media.RELATIVE_PATH, "Pictures/Tenzy")
        }
        val uri = ctx.contentResolver.insert(MediaStore.Images.Media.EXTERNAL_CONTENT_URI, values)
        if (uri == null) false
        else { ctx.contentResolver.openOutputStream(uri)?.use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }; true }
    } catch (_: Exception) { false }

    /** Write a PNG into cacheDir so it can be handed to the share sheet via the app FileProvider. */
    fun cachePng(ctx: Context, bmp: Bitmap, prefix: String): File? = try {
        val f = File(ctx.cacheDir, "$prefix-${System.currentTimeMillis()}.png")
        FileOutputStream(f).use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
        f
    } catch (_: Exception) { null }

    fun insertContactIntent(c: Contact): Intent {
        val i = Intent(ContactsContract.Intents.Insert.ACTION).setType(ContactsContract.RawContacts.CONTENT_TYPE)
        if (c.name.isNotBlank()) i.putExtra(ContactsContract.Intents.Insert.NAME, c.name)
        if (c.org.isNotBlank()) i.putExtra(ContactsContract.Intents.Insert.COMPANY, c.org)
        if (c.phone.isNotBlank()) i.putExtra(ContactsContract.Intents.Insert.PHONE, c.phone)
        if (c.email.isNotBlank()) i.putExtra(ContactsContract.Intents.Insert.EMAIL, c.email)
        return i
    }

    // ------------------------------------------------------------------ NFC

    data class NfcRecord(val label: String, val value: String)
    data class NfcTagInfo(val id: String, val tech: List<String>, val records: List<NfcRecord>)

    private val URI_PREFIX = arrayOf(
        "", "http://www.", "https://www.", "http://", "https://", "tel:", "mailto:",
        "ftp://anonymous:anonymous@", "ftp://ftp.", "ftps://", "sftp://", "smb://", "nfs://", "ftp://",
        "dav://", "news:", "telnet://", "imap:", "rtsp://", "urn:", "pop:", "sip:", "sips:", "tftp:",
        "btspp://", "btl2cap://", "btgoep://", "tcpobex://", "irdaobex://", "file://", "urn:epc:id:",
        "urn:epc:tag:", "urn:epc:pat:", "urn:epc:raw:", "urn:epc:", "urn:nfc:"
    )

    /** Connect to the tag and pull out its NDEF text/URI records. Runs off the main thread. */
    fun readTag(tag: Tag): NfcTagInfo {
        val id = tag.id?.joinToString(":") { "%02X".format(it) } ?: "—"
        val tech = tag.techList?.map { it.substringAfterLast('.') } ?: emptyList()
        val records = ArrayList<NfcRecord>()
        val ndef = Ndef.get(tag)
        if (ndef != null) {
            val msg = runCatching {
                ndef.cachedNdefMessage ?: run { ndef.connect(); ndef.ndefMessage }
            }.getOrNull()
            runCatching { if (ndef.isConnected) ndef.close() }
            msg?.records?.forEach { records.add(decodeRecord(it)) }
            if (records.isEmpty() && msg == null) records.add(NfcRecord("NDEF", "Empty or unreadable tag"))
        } else if (records.isEmpty()) {
            records.add(NfcRecord("Tag", "No NDEF data — this tag isn't text/URI formatted"))
        }
        return NfcTagInfo(id, tech, records)
    }

    private fun decodeRecord(r: NdefRecord): NfcRecord {
        return try {
            when {
                r.tnf == NdefRecord.TNF_WELL_KNOWN && r.type.contentEquals(NdefRecord.RTD_TEXT) -> {
                    val p = r.payload
                    if (p.isEmpty()) NfcRecord("Text", "")
                    else {
                        val status = p[0].toInt() and 0xFF
                        val langLen = status and 0x3F
                        val enc = if (status and 0x80 == 0) Charsets.UTF_8 else Charsets.UTF_16
                        NfcRecord("Text", String(p, 1 + langLen, p.size - 1 - langLen, enc))
                    }
                }
                r.tnf == NdefRecord.TNF_WELL_KNOWN && r.type.contentEquals(NdefRecord.RTD_URI) -> {
                    val p = r.payload
                    val prefix = if (p.isNotEmpty()) URI_PREFIX.getOrElse(p[0].toInt() and 0xFF) { "" } else ""
                    NfcRecord("URI", prefix + String(p, 1, (p.size - 1).coerceAtLeast(0), Charsets.UTF_8))
                }
                r.tnf == NdefRecord.TNF_ABSOLUTE_URI -> NfcRecord("URI", String(r.payload, Charsets.UTF_8))
                r.tnf == NdefRecord.TNF_MIME_MEDIA -> NfcRecord(r.toMimeType() ?: "Data", String(r.payload, Charsets.UTF_8))
                else -> {
                    val uri = runCatching { r.toUri()?.toString() }.getOrNull()
                    if (!uri.isNullOrBlank()) NfcRecord("URI", uri)
                    else NfcRecord("Raw", r.payload.joinToString(" ") { "%02X".format(it) })
                }
            }
        } catch (_: Exception) {
            NfcRecord("Raw", r.payload.joinToString(" ") { "%02X".format(it) })
        }
    }
}

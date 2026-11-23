package com.handytools.app.tools.pdf

import android.content.Context
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.testTag
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.handytools.app.I18n
import com.handytools.app.ui.Handy
import com.handytools.app.ui.HPrimaryButton
import com.handytools.app.ui.PowerToolPage
import com.tom_roush.pdfbox.pdmodel.PDDocument
import com.tom_roush.pdfbox.pdmodel.encryption.AccessPermission
import com.tom_roush.pdfbox.pdmodel.encryption.InvalidPasswordException
import com.tom_roush.pdfbox.pdmodel.encryption.StandardProtectionPolicy
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.security.SecureRandom

/** Lock a PDF with a password (AES-256, the strongest PDF lock), or take the lock off one you know the password to. */
object PdfProtect {
    /** How strong a password is, in words. Pure. */
    fun strength(p: String): String {
        val kinds = listOf(p.any { it.isLowerCase() }, p.any { it.isUpperCase() }, p.any { it.isDigit() }, p.any { !it.isLetterOrDigit() }).count { it }
        return when {
            p.length < 6 -> "Too short — use at least 6 characters"
            p.length >= 12 && kinds >= 3 -> "Strong"
            p.length >= 8 && kinds >= 2 -> "Good"
            else -> "Weak — mix letters, numbers and symbols"
        }
    }

    fun isLocked(ctx: Context, f: File): Boolean = runCatching { PdfCore.init(ctx); PDDocument.load(f).use { it.isEncrypted } }
        .getOrElse { it is InvalidPasswordException }

    fun lock(ctx: Context, src: File, password: String, out: File): Boolean = runCatching {
        PdfCore.init(ctx)
        PDDocument.load(src).use { d ->
            val owner = ByteArray(24).also { SecureRandom().nextBytes(it) }.joinToString("") { "%02x".format(it) }
            d.protect(StandardProtectionPolicy(owner, password, AccessPermission()).apply { encryptionKeyLength = 256 })
            d.save(out)
        }
        true
    }.getOrDefault(false)

    /** Null = wrong password; false = another problem. */
    fun unlock(ctx: Context, src: File, password: String, out: File): Boolean? = try {
        PdfCore.init(ctx)
        PDDocument.load(src, password).use { d -> d.isAllSecurityToBeRemoved = true; d.save(out) }
        true
    } catch (_: InvalidPasswordException) { null } catch (_: Throwable) { false }
}

@Composable
fun PdfProtectScreen() {
    val ctx = LocalContext.current
    val scope = rememberCoroutineScope()
    var src by remember { mutableStateOf<File?>(null) }
    var name by remember { mutableStateOf("Document") }
    var locked by remember { mutableStateOf(false) }
    var pw by remember { mutableStateOf("") }
    var pw2 by remember { mutableStateOf("") }
    var result by remember { mutableStateOf<File?>(null) }
    var note by remember { mutableStateOf<String?>(null) }
    var working by remember { mutableStateOf(false) }

    PowerToolPage("pdfprotect") {
        val r = result; val s = src
        when {
            r != null -> ResultCard(r, "application/pdf", if (locked) remember(r) { PdfCore.render(r, 0, 900) } else null,
                if (locked) I18n.t("The lock is off. Anyone can open this copy.") else I18n.t("Locked. It opens only with your password — keep it somewhere safe; it can't be recovered.")) {
                result = null; src = null; pw = ""; pw2 = ""
            }
            s == null -> PdfPicker("Choose a PDF to lock with a password — or one that's locked, to take the lock off.") { uri ->
                scope.launch {
                    val f = withContext(Dispatchers.IO) { PdfCore.copy(ctx, uri) }
                    if (f == null) { note = I18n.t("That PDF couldn't be opened."); return@launch }
                    name = PdfCore.name(ctx, uri); locked = withContext(Dispatchers.IO) { PdfProtect.isLocked(ctx, f) }; src = f; note = null
                }
            }
            else -> {
                Text(name + ".pdf", color = MaterialTheme.colorScheme.onBackground)
                Text(I18n.t(if (locked) "This PDF is locked. Type its password to save an unlocked copy." else "Choose a password. Anyone opening the PDF will need it."),
                    fontSize = 13.sp, color = Handy.palette.textSecondary)
                Spacer(Modifier.size(10.dp))
                OutlinedTextField(pw, { pw = it }, modifier = Modifier.fillMaxWidth().testTag("pdf-pw"), singleLine = true, label = { Text(I18n.t("Password")) },
                    visualTransformation = PasswordVisualTransformation(), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password))
                if (!locked) {
                    OutlinedTextField(pw2, { pw2 = it }, modifier = Modifier.fillMaxWidth(), singleLine = true, label = { Text(I18n.t("Type it again")) },
                        visualTransformation = PasswordVisualTransformation(), keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Password))
                    if (pw.isNotEmpty()) Text(I18n.t(PdfProtect.strength(pw)), fontSize = 13.sp, color = Handy.palette.textSecondary)
                    if (pw2.isNotEmpty() && pw2 != pw) Text(I18n.t("The two passwords don't match."), fontSize = 13.sp, color = androidx.compose.ui.graphics.Color(0xFFE53935))
                }
                note?.let { Text(it, fontSize = 13.sp, color = androidx.compose.ui.graphics.Color(0xFFE53935)) }
                Spacer(Modifier.size(12.dp))
                val ok = if (locked) pw.isNotEmpty() else pw.length >= 6 && pw == pw2
                HPrimaryButton(if (working) "Working…" else if (locked) "Take the lock off" else "Lock the PDF", enabled = ok && !working,
                    modifier = Modifier.testTag("pdf-protect-go")) {
                    working = true
                    scope.launch {
                        val out = PdfCore.out(ctx, if (locked) "$name (unlocked).pdf" else "$name (locked).pdf")
                        if (locked) when (withContext(Dispatchers.IO) { PdfProtect.unlock(ctx, s, pw, out) }) {
                            true -> result = out
                            null -> note = I18n.t("That password isn't right. Try again.")
                            false -> note = I18n.t("Couldn't open it with that password. The file may be damaged.")
                        } else if (withContext(Dispatchers.IO) { PdfProtect.lock(ctx, s, pw, out) }) result = out
                        else note = I18n.t("Couldn't lock it. Try again.")
                        working = false
                    }
                }
            }
        }
    }
}

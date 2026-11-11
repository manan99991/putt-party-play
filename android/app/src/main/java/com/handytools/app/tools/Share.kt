package com.handytools.app.tools

import android.content.Context
import android.content.Intent
import androidx.core.content.FileProvider
import java.io.File

/** Shared helpers to hand a file or text to the Android share sheet. */
object Share {
    private fun uri(ctx: Context, file: File) =
        FileProvider.getUriForFile(ctx, ctx.packageName + ".fileprovider", file)

    fun file(ctx: Context, file: File, mime: String) {
        val i = Intent(Intent.ACTION_SEND).setType(mime)
            .putExtra(Intent.EXTRA_STREAM, uri(ctx, file))
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        ctx.startActivity(Intent.createChooser(i, "Share").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    fun files(ctx: Context, files: List<File>, mime: String) {
        if (files.size == 1) { file(ctx, files[0], mime); return }
        val uris = ArrayList(files.map { uri(ctx, it) })
        val i = Intent(Intent.ACTION_SEND_MULTIPLE).setType(mime)
            .putParcelableArrayListExtra(Intent.EXTRA_STREAM, uris)
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        ctx.startActivity(Intent.createChooser(i, "Share").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    fun text(ctx: Context, text: String) {
        val i = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, text)
        ctx.startActivity(Intent.createChooser(i, "Share").addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    /**
     * Opens email, the SMS app or WhatsApp already filled in with the text and files, so sending is one tap.
     * Returns false when that app isn't there (no email app, WhatsApp not installed); the caller then falls back to
     * the normal share menu so the person is never stuck.
     */
    fun sendTo(ctx: Context, kind: String, recipients: List<String>, subject: String, text: String?, files: List<File>, mime: String): Boolean {
        val i = Intent(if (files.size > 1) Intent.ACTION_SEND_MULTIPLE else Intent.ACTION_SEND).setType(if (files.isEmpty()) "text/plain" else mime)
        if (files.size > 1) i.putParcelableArrayListExtra(Intent.EXTRA_STREAM, ArrayList(files.map { uri(ctx, it) }))
        else if (files.size == 1) i.putExtra(Intent.EXTRA_STREAM, uri(ctx, files[0]))
        if (!text.isNullOrEmpty()) i.putExtra(Intent.EXTRA_TEXT, text)
        i.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK)
        when (kind) {
            "mail" -> {
                i.putExtra(Intent.EXTRA_EMAIL, recipients.toTypedArray()).putExtra(Intent.EXTRA_SUBJECT, subject)
                i.selector = Intent(Intent.ACTION_SENDTO, android.net.Uri.parse("mailto:"))   // email apps only
            }
            "message" -> {
                val sms = android.provider.Telephony.Sms.getDefaultSmsPackage(ctx) ?: return false
                i.setPackage(sms).putExtra("address", recipients.joinToString(";"))
                if (!text.isNullOrEmpty()) i.putExtra("sms_body", text)
            }
            "whatsapp" -> i.setPackage("com.whatsapp")
            else -> return false
        }
        return try { ctx.startActivity(i); true } catch (_: Exception) { false }
    }
}

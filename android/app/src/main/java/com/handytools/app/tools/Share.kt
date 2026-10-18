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
}

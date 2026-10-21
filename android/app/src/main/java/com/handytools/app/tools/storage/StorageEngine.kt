package com.handytools.app.tools.storage

import android.content.Context
import android.net.Uri
import android.os.Environment
import android.os.StatFs
import android.provider.MediaStore

data class StorageItem(val name: String, val bytes: Long)
data class StorageFolder(val name: String, val count: Int, val bytes: Long)

data class StorageReport(
    val totalBytes: Long,
    val freeBytes: Long,
    val usedBytes: Long,
    val photoCount: Int,
    val photoBytes: Long,
    val videoCount: Int,
    val videoBytes: Long,
    val folders: List<StorageFolder>,
    val largest: List<StorageItem>
)

/** Reads device free/total space and sizes up photos + videos on-device. Nothing is uploaded. */
object StorageEngine {

    fun scan(ctx: Context): StorageReport {
        val stat = StatFs(Environment.getDataDirectory().absolutePath)
        val total = stat.totalBytes
        val free = stat.availableBytes
        val used = (total - free).coerceAtLeast(0)

        var photoCount = 0; var photoBytes = 0L
        var videoCount = 0; var videoBytes = 0L
        val folderBytes = hashMapOf<String, Long>()
        val folderCount = hashMapOf<String, Int>()
        val all = ArrayList<StorageItem>(2048)

        fun tally(uri: Uri, onEach: (Long) -> Unit) {
            val proj = arrayOf(
                MediaStore.MediaColumns.DISPLAY_NAME,
                MediaStore.MediaColumns.SIZE,
                MediaStore.MediaColumns.BUCKET_DISPLAY_NAME
            )
            ctx.contentResolver.query(uri, proj, null, null, null)?.use { c ->
                val iN = c.getColumnIndex(MediaStore.MediaColumns.DISPLAY_NAME)
                val iS = c.getColumnIndex(MediaStore.MediaColumns.SIZE)
                val iB = c.getColumnIndex(MediaStore.MediaColumns.BUCKET_DISPLAY_NAME)
                while (c.moveToNext()) {
                    val size = if (iS >= 0) c.getLong(iS) else 0L
                    val name = if (iN >= 0) c.getString(iN) else null
                    val bucket = if (iB >= 0) c.getString(iB) else null
                    onEach(size)
                    val b = bucket ?: "Other"
                    folderBytes[b] = (folderBytes[b] ?: 0L) + size
                    folderCount[b] = (folderCount[b] ?: 0) + 1
                    all.add(StorageItem(name ?: "file", size))
                }
            }
        }

        tally(MediaStore.Images.Media.EXTERNAL_CONTENT_URI) { photoCount++; photoBytes += it }
        tally(MediaStore.Video.Media.EXTERNAL_CONTENT_URI) { videoCount++; videoBytes += it }

        val folders = folderBytes.entries
            .map { StorageFolder(it.key, folderCount[it.key] ?: 0, it.value) }
            .sortedByDescending { it.bytes }
            .take(6)

        val largest = all.sortedByDescending { it.bytes }.take(8)

        return StorageReport(total, free, used, photoCount, photoBytes, videoCount, videoBytes, folders, largest)
    }

    fun human(bytes: Long): String {
        if (bytes <= 0) return "0 MB"
        val kb = bytes / 1024.0
        if (kb < 1024) return "%.0f KB".format(kb)
        val mb = kb / 1024.0
        if (mb < 1024) return "%.1f MB".format(mb)
        return "%.2f GB".format(mb / 1024.0)
    }
}

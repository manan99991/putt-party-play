package com.handytools.app.tools.sendany

import android.content.ContentResolver
import android.net.Uri
import java.io.BufferedReader
import java.io.InputStreamReader
import java.net.Inet4Address
import java.net.NetworkInterface
import java.net.ServerSocket
import java.net.Socket
import kotlin.concurrent.thread

/**
 * A tiny, dependency-free HTTP server that serves ONE picked file to another device on the same
 * Wi-Fi. It runs only while the tool is open (stopped on leave) — there is no background service and
 * no upload to any cloud. Raw sockets only; nothing leaves the local network.
 */
class LocalFileServer(
    private val resolver: ContentResolver,
    private val fileUri: Uri,
    private val fileName: String,
    private val mime: String,
    private val size: Long,
) {
    private var server: ServerSocket? = null
    @Volatile private var running = false
    var port: Int = 0; private set

    private val safeName = fileName.replace("\"", "").replace("\n", " ").replace("\r", " ")

    fun start(): Int {
        val s = ServerSocket(0)
        server = s
        port = s.localPort
        running = true
        thread(isDaemon = true) { acceptLoop(s) }
        return port
    }

    fun stop() {
        running = false
        try { server?.close() } catch (_: Exception) {}
    }

    private fun acceptLoop(s: ServerSocket) {
        while (running) {
            val sock = try { s.accept() } catch (e: Exception) { break }
            thread(isDaemon = true) { handle(sock) }
        }
    }

    private fun handle(sock: Socket) {
        try {
            val reader = BufferedReader(InputStreamReader(sock.getInputStream()))
            val line = reader.readLine() ?: return
            val path = line.split(" ").getOrNull(1) ?: "/"
            val out = sock.getOutputStream()
            if (path.startsWith("/file")) {
                val header = StringBuilder("HTTP/1.1 200 OK\r\n")
                header.append("Content-Type: ").append(mime.ifBlank { "application/octet-stream" }).append("\r\n")
                if (size > 0) header.append("Content-Length: ").append(size).append("\r\n")
                header.append("Content-Disposition: attachment; filename=\"").append(safeName).append("\"\r\n")
                header.append("Connection: close\r\n\r\n")
                out.write(header.toString().toByteArray())
                resolver.openInputStream(fileUri)?.use { it.copyTo(out) }
                out.flush()
            } else {
                val body = """<!doctype html><html><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"></head>
<body style="font-family:system-ui,sans-serif;text-align:center;padding:48px 24px;background:#f6f7f9;color:#111">
<h2 style="margin:0 0 6px">$safeName</h2>
<p style="color:#667">${prettySize(size)}</p>
<a href="/file" download style="display:inline-block;margin-top:18px;padding:14px 24px;background:#1F5EFF;color:#fff;border-radius:12px;text-decoration:none;font-weight:600">Download</a>
<p style="color:#99a;margin-top:28px;font-size:13px">Shared from Tenzy over your local Wi-Fi.</p>
</body></html>"""
                val bytes = body.toByteArray()
                val header = "HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: ${bytes.size}\r\nConnection: close\r\n\r\n"
                out.write(header.toByteArray())
                out.write(bytes)
                out.flush()
            }
        } catch (_: Exception) {
        } finally {
            try { sock.close() } catch (_: Exception) {}
        }
    }

    companion object {
        /** First site-local IPv4 of an up, non-loopback interface (the Wi-Fi address other devices use). */
        fun localIpv4(): String? {
            try {
                for (ni in NetworkInterface.getNetworkInterfaces()) {
                    if (!ni.isUp || ni.isLoopback) continue
                    for (addr in ni.inetAddresses) {
                        if (addr is Inet4Address && !addr.isLoopbackAddress && addr.isSiteLocalAddress) return addr.hostAddress
                    }
                }
            } catch (_: Exception) {}
            return null
        }

        fun prettySize(bytes: Long): String {
            if (bytes <= 0) return ""
            val kb = bytes / 1024.0
            return when {
                kb < 1024 -> "%.0f KB".format(kb)
                kb < 1024 * 1024 -> "%.1f MB".format(kb / 1024)
                else -> "%.1f GB".format(kb / 1024 / 1024)
            }
        }
    }
}

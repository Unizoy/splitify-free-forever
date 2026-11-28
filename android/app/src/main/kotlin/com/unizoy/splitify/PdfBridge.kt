package com.unizoy.splitify

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Color
import android.graphics.pdf.PdfRenderer
import android.os.Handler
import android.os.Looper
import android.os.ParcelFileDescriptor
import androidx.core.content.FileProvider
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File
import java.util.concurrent.Executors

/** FileProvider of its own (other plugins register theirs), for handing a PDF to a viewer app. */
class PdfFileProvider : FileProvider()

/**
 * Expense attachments (W2-Y, S-433): Android's own PdfRenderer shows PDF pages inside the app and an ACTION_VIEW
 * intent opens one in another app, so no PDF library is bundled. Channel `splitify/pdf`:
 *   pageCount {path} -> Int · render {path, page, width} -> PNG bytes · open {path, name} -> Boolean
 * Rendering runs on one background thread; results come back on the main thread.
 */
class PdfBridge(private val activity: Activity, messenger: BinaryMessenger) {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    init {
        MethodChannel(messenger, "splitify/pdf").setMethodCallHandler { call, result ->
            val path = call.argument<String>("path")
            if (path == null) {
                result.error("BAD_ARGS", "path", null)
                return@setMethodCallHandler
            }
            when (call.method) {
                "pageCount" -> background(result) { withRenderer(path) { it.pageCount } }
                "render" -> {
                    val page = call.argument<Int>("page") ?: 0
                    val width = (call.argument<Int>("width") ?: 1080).coerceIn(64, 2400)
                    background(result) { withRenderer(path) { render(it, page, width) } }
                }
                "open" -> result.success(open(File(path), call.argument<String>("name")))
                else -> result.notImplemented()
            }
        }
    }

    private fun background(result: MethodChannel.Result, body: () -> Any) {
        worker.execute {
            try {
                val value = body()
                main.post { result.success(value) }
            } catch (e: Exception) {
                main.post { result.error("PDF", e.javaClass.simpleName, null) }
            }
        }
    }

    /** The renderer owns (and closes) the descriptor; a file that is not a PDF closes it here. */
    private fun <T> withRenderer(path: String, body: (PdfRenderer) -> T): T {
        val fd = ParcelFileDescriptor.open(File(path), ParcelFileDescriptor.MODE_READ_ONLY)
        val renderer = try {
            PdfRenderer(fd)
        } catch (e: Exception) {
            fd.close()
            throw e
        }
        return renderer.use(body)
    }

    private fun render(renderer: PdfRenderer, index: Int, width: Int): ByteArray {
        renderer.openPage(index.coerceIn(0, renderer.pageCount - 1)).use { page ->
            val height = (width.toLong() * page.height / page.width.coerceAtLeast(1)).toInt().coerceIn(1, 4000)
            val bitmap = Bitmap.createBitmap(width, height, Bitmap.Config.ARGB_8888)
            try {
                bitmap.eraseColor(Color.WHITE)
                page.render(bitmap, null, null, PdfRenderer.Page.RENDER_MODE_FOR_DISPLAY)
                return ByteArrayOutputStream().use { out ->
                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
                    out.toByteArray()
                }
            } finally {
                bitmap.recycle()
            }
        }
    }

    /** Copies the PDF into cache/pdf/ under its own name and asks another app to show it. */
    private fun open(source: File, name: String?): Boolean = try {
        val dir = File(activity.cacheDir, "pdf").apply { mkdirs() }
        dir.listFiles()?.forEach { it.delete() }
        val safe = (name ?: "document.pdf").replace(Regex("[^A-Za-z0-9._ -]"), "_").take(80)
            .let { if (it.lowercase().endsWith(".pdf")) it else "$it.pdf" }
        val copy = File(dir, safe)
        source.copyTo(copy, overwrite = true)
        val uri = FileProvider.getUriForFile(activity, "${activity.packageName}.files", copy)
        val intent = Intent(Intent.ACTION_VIEW)
            .setDataAndType(uri, "application/pdf")
            .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        activity.startActivity(intent)
        true
    } catch (_: ActivityNotFoundException) {
        false
    } catch (_: Exception) {
        false
    }
}

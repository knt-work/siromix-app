package com.example.siromix

import android.app.Activity
import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.util.concurrent.Executors

/** User-selected documents only; no broad storage permissions or cloud access. */
class BackupBridge(private val activity: Activity, engine: FlutterEngine) {
    private val worker = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())
    private var pending: MethodChannel.Result? = null
    private var payload: String? = null
    private var closed = false
    private val limit = 20 * 1024 * 1024

    init {
        MethodChannel(engine.dartExecutor.binaryMessenger, "siromix/backup")
            .setMethodCallHandler { call, result ->
                if (call.method != "save" && call.method != "open") {
                    result.notImplemented()
                } else if (pending != null) {
                    result.error("BUSY", "A document operation is pending", null)
                } else {
                    val save = call.method == "save"
                    val content = if (save) call.argument<String>("payload") else null
                    if (save && (content == null || content.toByteArray(Charsets.UTF_8).size > limit)) {
                        result.error("INVALID_DATA", "Backup is missing or too large", null)
                    } else {
                        val intent = Intent(if (save) Intent.ACTION_CREATE_DOCUMENT else Intent.ACTION_OPEN_DOCUMENT).apply {
                            addCategory(Intent.CATEGORY_OPENABLE)
                            type = if (save) "application/json" else "*/*"
                            if (save) putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "SiroMix-backup.json")
                        }
                        pending = result
                        payload = content
                        try {
                            activity.startActivityForResult(intent, if (save) 7401 else 7402)
                        } catch (_: Exception) {
                            pending = null
                            payload = null
                            result.error("PICKER_FAILED", "Cannot open document picker", null)
                        }
                    }
                }
            }
    }

    fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        if (requestCode != 7401 && requestCode != 7402) return
        val result = pending ?: return
        val save = requestCode == 7401
        val uri = data?.data
        val content = payload
        payload = null
        if (resultCode != Activity.RESULT_OK || uri == null) {
            pending = null
            result.success(if (save) false else null)
            return
        }
        worker.execute {
            try {
                val value: Any = if (save) {
                    activity.contentResolver.openOutputStream(uri, "wt").use { stream ->
                        requireNotNull(stream).write(requireNotNull(content).toByteArray(Charsets.UTF_8))
                        stream.flush()
                    }
                    true
                } else {
                    activity.contentResolver.openInputStream(uri).use { stream ->
                        requireNotNull(stream)
                        val output = ByteArrayOutputStream()
                        val buffer = ByteArray(8192)
                        while (true) {
                            val count = stream.read(buffer)
                            if (count < 0) break
                            require(output.size() + count <= limit) { "Backup too large" }
                            output.write(buffer, 0, count)
                        }
                        output.toString("UTF-8")
                    }
                }
                main.post {
                    if (!closed && pending === result) { pending = null; result.success(value) }
                }
            } catch (_: Exception) {
                main.post {
                    if (!closed && pending === result) {
                        pending = null
                        result.error("DOCUMENT_IO_FAILED", "Cannot read or write backup", null)
                    }
                }
            }
        }
    }

    fun close() {
        closed = true
        pending?.error("CANCELLED", "Activity closed", null)
        pending = null
        payload = null
        worker.shutdown()
    }
}

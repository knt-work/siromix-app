package com.example.siromix

import android.content.Intent
import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var backupBridge: BackupBridge? = null
    private val storageWorker = Executors.newSingleThreadExecutor()
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        backupBridge = BackupBridge(this, flutterEngine)
        val prefs = getSharedPreferences("siromix", MODE_PRIVATE)
        val mainHandler = Handler(Looper.getMainLooper())
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "siromix/storage")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "appInfo" -> {
                        val info = packageManager.getPackageInfo(packageName, 0)
                        result.success(mapOf("version" to (info.versionName ?: ""), "build" to (if (android.os.Build.VERSION.SDK_INT >= 28) info.longVersionCode else info.versionCode.toLong()).toString()))
                    }
                    "read" -> result.success(prefs.getString("exam_data_v1", null))
                    "write" -> {
                        val value = call.arguments as? String
                        if (value == null) {
                            result.error("INVALID_DATA", "Expected a JSON string", null)
                        } else storageWorker.execute {
                            try {
                                val ok = prefs.edit().putString("exam_data_v1", value).commit()
                                mainHandler.post {
                                    if (ok) result.success(null)
                                    else result.error("WRITE_FAILED", "Local storage write failed", null)
                                }
                            } catch (e: Exception) {
                                mainHandler.post { result.error("WRITE_FAILED", e.message, null) }
                            }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        backupBridge?.onActivityResult(requestCode, resultCode, data)
    }
    override fun onDestroy() {
        backupBridge?.close()
        storageWorker.shutdown()
        super.onDestroy()
    }
}

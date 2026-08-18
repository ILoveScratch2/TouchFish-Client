package ci.us.ilovescratch.touchfish.astra.v3.touchfish_client

import android.content.ContentValues
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    private val channelName = "touchfish/background_notification"
    private var channel: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        BackgroundNotificationService.setAppForeground(true)
        channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
        channel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "startBackgroundService" -> {
                    BackgroundNotificationService.start(this)
                    result.success(true)
                }
                "stopBackgroundService" -> {
                    BackgroundNotificationService.stop(this)
                    result.success(true)
                }
                "saveFileToDownloads" -> {
                    try {
                        val srcPath = call.argument<String>("srcPath")
                        val displayName = call.argument<String>("displayName")
                        if (srcPath == null || displayName == null) {
                            result.error("BAD_ARG", "srcPath and displayName required", null)
                            return@setMethodCallHandler
                        }
                        val savedPath = saveFileToDownloads(srcPath, displayName)
                        result.success(savedPath)
                    } catch (e: Exception) {
                        result.error("SAVE_FAILED", e.message, e.stackTraceToString())
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    /**
     * 将 srcPath 指向的文件复制到公共 Downloads 目录（应用文件之外）。
     *
     * - Android 10+（API 29+）：使用 MediaStore.Downloads，无需任何存储权限，
     *   文件保存在 /storage/emulated/0/Download 且卸载应用后仍保留。
     * - Android 9 及以下：直接写 raw 路径，配合 WRITE_EXTERNAL_STORAGE 权限。
     *
     * @return 保存后的完整路径（可供 open_file 直接打开触发安装器）
     */
    private fun saveFileToDownloads(srcPath: String, displayName: String): String {
        val src = File(srcPath)
        require(src.exists()) { "source file does not exist: $srcPath" }

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            val values = ContentValues().apply {
                put(MediaStore.Downloads.DISPLAY_NAME, displayName)
                put(MediaStore.Downloads.MIME_TYPE, "application/vnd.android.package-archive")
                put(MediaStore.Downloads.IS_PENDING, 1)
            }
            val resolver = contentResolver
            val collection = MediaStore.Downloads.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
            val uri = resolver.insert(collection, values)
                ?: throw IllegalStateException("MediaStore insert failed")
            try {
                resolver.openOutputStream(uri)?.use { out ->
                    src.inputStream().use { it.copyTo(out) }
                } ?: throw IllegalStateException("openOutputStream returned null")
                values.clear()
                values.put(MediaStore.Downloads.IS_PENDING, 0)
                resolver.update(uri, values, null, null)
            } catch (e: Exception) {
                resolver.delete(uri, null, null)
                throw e
            }
            // 返回公共路径（open_file 可用 raw 路径打开）
            return "/storage/emulated/0/Download/$displayName"
        }

        // Android 9 及以下：直接写公共 Download 目录
        val dir = File("/storage/emulated/0/Download/TouchFish")
        if (!dir.exists()) dir.mkdirs()
        val dest = File(dir, displayName)
        src.copyTo(dest, overwrite = true)
        return dest.absolutePath
    }

    override fun onStop() {
        super.onStop()
        BackgroundNotificationService.setAppForeground(false)
    }

    override fun onStart() {
        super.onStart()
        BackgroundNotificationService.setAppForeground(true)
    }

    override fun onDestroy() {
        channel?.setMethodCallHandler(null)
        channel = null
        BackgroundNotificationService.setAppForeground(false)
        super.onDestroy()
    }
}
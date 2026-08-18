package ci.us.ilovescratch.touchfish.astra.v3.touchfish_client

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

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
                else -> result.notImplemented()
            }
        }
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
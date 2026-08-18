package ci.us.ilovescratch.touchfish.astra.v3.touchfish_client

import android.app.*
import android.content.*
import android.content.pm.ServiceInfo
import android.os.*
import android.util.Log
import java.net.*
import java.util.concurrent.atomic.AtomicBoolean

/**
 * TouchFish background notification service.
 * Runs as a foreground service, auto-starts on boot,
 * polls for messages even when main process is killed.
 */
class BackgroundNotificationService : Service() {
    companion object {
        private const val TAG = "TFBackgroundNotif"
        private const val CHANNEL_ID = "touchfish_background"
        private const val SERVICE_NOTIF_ID = 1001
        private const val PREFS_FILE = "FlutterSharedPreferences"
        private const val KEY_UID = "flutter.auth_uid"
        private const val KEY_PASSWORD = "flutter.auth_password"
        private const val KEY_LEVEL = "flutter.notificationLevel"
        private const val KEY_SYSTEM = "flutter.systemNotifications"
        private const val KEY_SERVER = "flutter.server_base_url"
        private const val KEY_PORT = "flutter.server_api_port"
        private const val KEY_LAST_FETCH = "flutter.notif_last_fetch_time"
        private const val POLL_MS = 30_000L

        const val ACTION_START = "ci.us.ilovescratch.touchfish.astra.v3.touchfish_client.START_BACKGROUND"
        const val ACTION_STOP = "ci.us.ilovescratch.touchfish.astra.v3.touchfish_client.STOP_BACKGROUND"

        private val running = AtomicBoolean(false)
        @Volatile private var appForeground = false
        fun isRunning(): Boolean = running.get()
        fun setAppForeground(value: Boolean) { appForeground = value }
        fun isAppForeground(): Boolean = appForeground

        fun start(context: Context) {
            if (running.get()) return
            val i = Intent(context, BackgroundNotificationService::class.java).setAction(ACTION_START)
            // Android 8.0+ 禁止纯后台 startService；使用 startForegroundService，
            // onStartCommand 中会在 5 秒内调用 startForeground。开机自启（BOOT_COMPLETED）
            // 与前台应用场景均满足前台服务启动豁免。
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(i)
            } else {
                context.startService(i)
            }
        }

        fun stop(context: Context) {
            val i = Intent(context, BackgroundNotificationService::class.java).setAction(ACTION_STOP)
            context.stopService(i)
        }
    }

    private lateinit var prefs: SharedPreferences
    private val handler = Handler(Looper.getMainLooper())
    private val pollRunnable = object : Runnable {
        override fun run() {
            poll()
            handler.postDelayed(this, POLL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        prefs = getSharedPreferences(PREFS_FILE, Context.MODE_PRIVATE)
        createChannel()
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        when (intent?.action) {
            ACTION_STOP -> { stopSelf(); return START_NOT_STICKY }
            else -> {
                running.set(true)
                startForegroundCompat()
                handler.removeCallbacks(pollRunnable)
                handler.postDelayed(pollRunnable, 1_000L)
                return START_STICKY
            }
        }
    }

    @Suppress("DEPRECATION")
    private fun startForegroundCompat() {
        val n = Notification.Builder(this, CHANNEL_ID)
            .setContentTitle("TouchFish")
            .setSmallIcon(R.drawable.ic_notification)
            .setOngoing(true)
            .setPriority(Notification.PRIORITY_MIN)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(SERVICE_NOTIF_ID, n, ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC)
        } else {
            startForeground(SERVICE_NOTIF_ID, n)
        }
    }

    private fun createChannel() {
        val ch = NotificationChannel(CHANNEL_ID, "TouchFish Background", NotificationManager.IMPORTANCE_MIN)
        ch.description = "TouchFish background message notifications"
        ch.setShowBadge(false)
        getSystemService(NotificationManager::class.java).createNotificationChannel(ch)
    }

    private fun poll() {
        if (!prefs.getBoolean(KEY_SYSTEM, true)) return
        val uid = prefs.getLong(KEY_UID, -1)
        val pwd = prefs.getString(KEY_PASSWORD, null)
        if (uid <= 0 || pwd.isNullOrEmpty()) return
        val server = prefs.getString(KEY_SERVER, null) ?: return
        val port = prefs.getInt(KEY_PORT, 8080)
        val level = prefs.getString(KEY_LEVEL, "2") ?: "2"
        val since = prefs.getLong(KEY_LAST_FETCH, 0L)

        Thread {
            try {
                val base = server.replace(Regex("^https?://"), "").trimEnd('/')
                val scheme = if (server.startsWith("https")) "https" else "http"
                val url = URL("$scheme://$base:$port/notification/query_after")
                val conn = url.openConnection() as HttpURLConnection
                try {
                    conn.requestMethod = "POST"
                    conn.connectTimeout = 8000
                    conn.readTimeout = 8000
                    conn.doOutput = true
                    conn.setRequestProperty("Content-Type", "application/json")
                    conn.outputStream.use { it.write(
                        "{\"sender\":\"$uid\",\"password\":\"$pwd\",\"after\":$since}".toByteArray()
                    ) }
                    if (conn.responseCode !in 200..299) return@Thread
                    val body = conn.inputStream.bufferedReader().use { it.readText() }
                    val found = mutableListOf<String>()
                    for (line in body.split("}").filter { it.contains("\"event\":\"message.") }) {
                        found.add(line + "}")
                    }
                    if (found.isNotEmpty()) {
                        showForLevel(found, level)
                        prefs.edit().putLong(KEY_LAST_FETCH, System.currentTimeMillis()).apply()
                    }
                } finally { conn.disconnect() }
            } catch (e: Exception) {
                Log.w(TAG, "poll error: ${e.message}")
            }
        }.start()
    }

    private fun showForLevel(messages: List<String>, level: String) {
        // Skip when app is foreground - Flutter handles in-app banners
        if (isAppForeground()) return
        val mgr = getSystemService(NotificationManager::class.java)
        when (level) {
            "1" -> {
                // 一级通知：聚合统计联系人数与消息数，如「3 个联系人发来了 5 条消息」。
                val senders = messages.map { extractSender(it) }.toSet()
                mgr.notify(
                    9001,
                    simpleNotif("TouchFish", "${senders.size} 个联系人发来了 ${messages.size} 条消息").build()
                )
            }
            "2" -> {
                val seen = HashSet<String>()
                for (m in messages.reversed()) {
                    val sender = extractSender(m)
                    if (seen.add(sender)) {
                        mgr.notify(stableId("s$sender"), simpleNotif("New message", "From $sender").build())
                    }
                }
            }
            else -> messages.forEach { m ->
                mgr.notify(stableId(m), simpleNotif("TouchFish", "New message").build())
            }
        }
    }

    private fun extractSender(msg: String): String {
        val m = Regex("\"sender\":\"([^\"]+)\"").find(msg)
        return m?.groupValues?.get(1) ?: "U0"
    }

    private fun stableId(key: String): Int = key.hashCode() and 0x7fffffff

    private fun simpleNotif(title: String, text: String): Notification.Builder =
        Notification.Builder(this, CHANNEL_ID)
            .setContentTitle(title)
            .setContentText(text)
            .setSmallIcon(R.drawable.ic_notification)
            .setPriority(Notification.PRIORITY_HIGH)
            .setAutoCancel(true)

    override fun onDestroy() {
        super.onDestroy()
        running.set(false)
        handler.removeCallbacks(pollRunnable)
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
package ci.us.ilovescratch.touchfish.astra.v3.touchfish_client

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.ServiceInfo
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.util.Log
import androidx.core.app.NotificationCompat
import androidx.core.app.RemoteInput
import org.json.JSONArray
import org.json.JSONObject
import java.util.concurrent.atomic.AtomicBoolean

class BackgroundNotificationService : Service() {
    companion object {
        private const val TAG = "TFBackgroundNotif"
        private const val SERVICE_CHANNEL_ID = "touchfish_background"
        private const val MESSAGE_CHANNEL_ID = "touchfish_messages"
        private const val SERVICE_NOTIFICATION_ID = 1001
        private const val FLUTTER_PREFS = "FlutterSharedPreferences"
        private const val STATE_PREFS = "touchfish_background_state"
        private const val KEY_LEVEL = "flutter.notificationLevel"
        private const val KEY_SYSTEM = "flutter.systemNotifications"
        private const val KEY_LAST_FETCH_MS = "last_fetch_ms"
        private const val POLL_MS = 30_000L

        const val ACTION_START = "ci.us.ilovescratch.touchfish.astra.v3.touchfish_client.START_BACKGROUND"
        const val ACTION_STOP = "ci.us.ilovescratch.touchfish.astra.v3.touchfish_client.STOP_BACKGROUND"
        const val REPLY_INPUT_KEY = "touchfish_inline_reply"
        const val EXTRA_ROOM_ID = "room_id"
        const val EXTRA_NOTIFICATION_ID = "notification_id"

        private val running = AtomicBoolean(false)
        @Volatile private var appForeground = false

        fun setAppForeground(value: Boolean) {
            appForeground = value
        }

        fun isAppForeground(): Boolean = appForeground

        fun start(context: Context) {
            if (running.get() || NativeNotificationConfig.load(context) == null) return
            val intent = Intent(context, BackgroundNotificationService::class.java)
                .setAction(ACTION_START)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                context.startForegroundService(intent)
            } else {
                context.startService(intent)
            }
        }

        fun stop(context: Context) {
            context.stopService(
                Intent(context, BackgroundNotificationService::class.java)
                    .setAction(ACTION_STOP),
            )
        }

        fun buildReplyFailedNotification(
            context: Context,
            roomId: String,
            notificationId: Int,
        ): Notification {
            ensureChannels(context)
            return messageNotificationBuilder(
                context,
                title = "回复发送失败",
                text = "点按进入会话后重试",
                roomId = roomId,
                notificationId = notificationId,
            ).build()
        }

        private fun messageNotificationBuilder(
            context: Context,
            title: String,
            text: String,
            roomId: String,
            notificationId: Int,
        ): NotificationCompat.Builder {
            val openIntent = Intent(context, MainActivity::class.java).apply {
                action = Intent.ACTION_VIEW
                data = Uri.parse("touchfish:///chat/$roomId")
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            }
            val openPendingIntent = PendingIntent.getActivity(
                context,
                notificationId,
                openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
            )
            val replyIntent = Intent(context, NotificationReplyReceiver::class.java).apply {
                putExtra(EXTRA_ROOM_ID, roomId)
                putExtra(EXTRA_NOTIFICATION_ID, notificationId)
            }
            val replyPendingIntent = PendingIntent.getBroadcast(
                context,
                notificationId,
                replyIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE,
            )
            val remoteInput = RemoteInput.Builder(REPLY_INPUT_KEY)
                .setLabel("输入回复")
                .build()
            val replyAction = NotificationCompat.Action.Builder(
                0,
                "回复",
                replyPendingIntent,
            )
                .addRemoteInput(remoteInput)
                .setAllowGeneratedReplies(true)
                .setSemanticAction(NotificationCompat.Action.SEMANTIC_ACTION_REPLY)
                .build()

            return NotificationCompat.Builder(context, MESSAGE_CHANNEL_ID)
                .setContentTitle(title)
                .setContentText(text)
                .setSmallIcon(R.drawable.ic_notification)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setContentIntent(openPendingIntent)
                .setAutoCancel(true)
                .addAction(replyAction)
        }

        private fun ensureChannels(context: Context) {
            if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(
                NotificationChannel(
                    SERVICE_CHANNEL_ID,
                    "TouchFish Background",
                    NotificationManager.IMPORTANCE_MIN,
                ).apply {
                    description = "Keeps TouchFish connected in the background"
                    setShowBadge(false)
                },
            )
            manager.createNotificationChannel(
                NotificationChannel(
                    MESSAGE_CHANNEL_ID,
                    "TouchFish messages",
                    NotificationManager.IMPORTANCE_HIGH,
                ).apply {
                    description = "Messages from TouchFish conversations"
                },
            )
        }

        private fun stableId(value: String): Int = value.hashCode() and 0x7fffffff
    }

    private data class MessageNotification(
        val identity: String,
        val roomId: String,
        val title: String,
        val content: String,
        val timestamp: Double,
    )

    private lateinit var flutterPrefs: SharedPreferences
    private lateinit var statePrefs: SharedPreferences
    private val polling = AtomicBoolean(false)
    private val handler = Handler(Looper.getMainLooper())
    private val pollRunnable = object : Runnable {
        override fun run() {
            poll()
            handler.postDelayed(this, POLL_MS)
        }
    }

    override fun onCreate() {
        super.onCreate()
        flutterPrefs = getSharedPreferences(FLUTTER_PREFS, Context.MODE_PRIVATE)
        statePrefs = getSharedPreferences(STATE_PREFS, Context.MODE_PRIVATE)
        ensureChannels(this)
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        if (intent?.action == ACTION_STOP) {
            running.set(false)
            stopSelf()
            return START_NOT_STICKY
        }
        if (NativeNotificationConfig.load(this) == null) {
            running.set(false)
            stopSelf()
            return START_NOT_STICKY
        }
        running.set(true)
        startForegroundCompat()
        handler.removeCallbacks(pollRunnable)
        handler.postDelayed(pollRunnable, 1_000L)
        return START_STICKY
    }

    private fun startForegroundCompat() {
        val notification = NotificationCompat.Builder(this, SERVICE_CHANNEL_ID)
            .setContentTitle("TouchFish")
            .setSmallIcon(R.drawable.ic_notification)
            .setOngoing(true)
            .setPriority(NotificationCompat.PRIORITY_MIN)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            startForeground(
                SERVICE_NOTIFICATION_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC,
            )
        } else {
            startForeground(SERVICE_NOTIFICATION_ID, notification)
        }
    }

    private fun poll() {
        if (isAppForeground() ||
            !flutterPrefs.getBoolean(KEY_SYSTEM, true) ||
            !polling.compareAndSet(false, true)
        ) return
        val storedMs = statePrefs.getLong(KEY_LAST_FETCH_MS, 0L)
        val nowMs = System.currentTimeMillis()
        val sinceSeconds = (if (storedMs > 0) storedMs else nowMs - POLL_MS) / 1000.0

        Thread {
            try {
                val notifications = TouchFishApiClient(applicationContext)
                    .queryNotificationsAfter(sinceSeconds) ?: return@Thread
                val parsed = parseMessages(notifications)
                if (parsed.isNotEmpty()) {
                    showForLevel(parsed, flutterPrefs.getString(KEY_LEVEL, "2") ?: "2")
                }
                val newestSeconds = newestTimestamp(notifications)
                val checkpointMs = newestSeconds?.times(1000)?.toLong() ?: nowMs
                statePrefs.edit().putLong(KEY_LAST_FETCH_MS, maxOf(storedMs, checkpointMs)).apply()
            } catch (error: Exception) {
                Log.w(TAG, "poll error", error)
            } finally {
                polling.set(false)
            }
        }.start()
    }

    private fun parseMessages(items: JSONArray): List<MessageNotification> {
        val result = mutableListOf<MessageNotification>()
        for (index in 0 until items.length()) {
            val item = items.optJSONObject(index) ?: continue
            val outerInfo = item.optJSONObject("info") ?: JSONObject()
            val info = outerInfo.optJSONObject("info") ?: outerInfo
            val event = info.optString("event")
            if (event != "message.plain" && event != "message.file") continue
            val sender = info.optString("sender", outerInfo.optString("sender"))
            val groupId = info.optLong("group_id", -1)
            val explicitRoom = info.optString("room_id")
            val roomId = when {
                explicitRoom.isNotEmpty() -> explicitRoom
                groupId > 0 -> "G$groupId"
                sender.startsWith("G") && sender.contains("U") -> sender.substringBeforeLast("U")
                sender.startsWith("U") -> sender
                else -> ""
            }
            if (roomId.isEmpty()) continue
            val timestamp = item.optDouble(
                "time_stamp",
                outerInfo.optDouble("time_stamp", System.currentTimeMillis() / 1000.0),
            )
            val mid = info.optLong("mid", -1)
            result.add(
                MessageNotification(
                    identity = if (mid > 0) "$roomId:$mid" else "$roomId:$timestamp:${info.optString("content")}",
                    roomId = roomId,
                    title = info.optString("title", if (roomId.startsWith("G")) "群聊消息" else "新消息"),
                    content = info.optString("content", "新消息"),
                    timestamp = timestamp,
                ),
            )
        }
        return result
    }

    private fun newestTimestamp(items: JSONArray): Double? {
        var newest: Double? = null
        for (index in 0 until items.length()) {
            val item = items.optJSONObject(index) ?: continue
            val outerInfo = item.optJSONObject("info") ?: JSONObject()
            val timestamp = item.optDouble(
                "time_stamp",
                outerInfo.optDouble("time_stamp", Double.NaN),
            )
            if (!timestamp.isNaN() && (newest == null || timestamp > newest)) {
                newest = timestamp
            }
        }
        return newest
    }

    private fun showForLevel(messages: List<MessageNotification>, level: String) {
        val manager = getSystemService(NotificationManager::class.java)
        when (level) {
            "1" -> {
                val roomCount = messages.map { it.roomId }.toSet().size
                manager.notify(
                    9001,
                    NotificationCompat.Builder(this, MESSAGE_CHANNEL_ID)
                        .setContentTitle("TouchFish")
                        .setContentText("$roomCount 个会话发来了 ${messages.size} 条消息")
                        .setSmallIcon(R.drawable.ic_notification)
                        .setPriority(NotificationCompat.PRIORITY_HIGH)
                        .setAutoCancel(true)
                        .build(),
                )
            }
            "2" -> messages
                .groupBy { it.roomId }
                .mapValues { (_, values) -> values.maxBy { it.timestamp } }
                .values
                .forEach { message -> showMessage(manager, message, stableId("room:${message.roomId}")) }
            else -> messages.forEach { message ->
                showMessage(manager, message, stableId(message.identity))
            }
        }
    }

    private fun showMessage(
        manager: NotificationManager,
        message: MessageNotification,
        notificationId: Int,
    ) {
        manager.notify(
            notificationId,
            messageNotificationBuilder(
                this,
                message.title,
                message.content,
                message.roomId,
                notificationId,
            ).build(),
        )
    }

    override fun onDestroy() {
        running.set(false)
        handler.removeCallbacks(pollRunnable)
        super.onDestroy()
    }

    override fun onBind(intent: Intent?): IBinder? = null
}

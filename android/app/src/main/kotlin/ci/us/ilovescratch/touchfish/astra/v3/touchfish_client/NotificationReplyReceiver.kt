package ci.us.ilovescratch.touchfish.astra.v3.touchfish_client

import android.app.NotificationManager
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.RemoteInput

class NotificationReplyReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val text = RemoteInput.getResultsFromIntent(intent)
            ?.getCharSequence(BackgroundNotificationService.REPLY_INPUT_KEY)
            ?.toString()
            ?.trim()
        val roomId = intent.getStringExtra(BackgroundNotificationService.EXTRA_ROOM_ID)
        val notificationId = intent.getIntExtra(
            BackgroundNotificationService.EXTRA_NOTIFICATION_ID,
            -1,
        )
        if (text.isNullOrEmpty() || roomId.isNullOrEmpty() || notificationId < 0) return

        val pendingResult = goAsync()
        Thread {
            try {
                val sent = TouchFishApiClient(context.applicationContext).sendMessage(
                    roomId,
                    text,
                    "c${System.nanoTime()}",
                )
                val manager = context.getSystemService(NotificationManager::class.java)
                if (sent) {
                    manager.cancel(notificationId)
                } else {
                    manager.notify(
                        notificationId,
                        BackgroundNotificationService.buildReplyFailedNotification(
                            context,
                            roomId,
                            notificationId,
                        ),
                    )
                }
            } finally {
                pendingResult.finish()
            }
        }.start()
    }
}

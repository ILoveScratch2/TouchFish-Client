package ci.us.ilovescratch.touchfish.astra.v3.touchfish_client

import android.content.Context

data class NativeNotificationConfig(
    val uid: Long,
    val password: String,
    val baseUrl: String,
) {
    companion object {
        private const val PREFS = "touchfish_native_notifications"
        private const val UID = "uid"
        private const val PASSWORD = "password"
        private const val BASE_URL = "base_url"

        fun load(context: Context): NativeNotificationConfig? {
            val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val uid = prefs.getLong(UID, -1)
            val password = prefs.getString(PASSWORD, null)
            val baseUrl = prefs.getString(BASE_URL, null)
            if (uid <= 0 || password.isNullOrEmpty() || baseUrl.isNullOrEmpty()) return null
            return NativeNotificationConfig(uid, password, baseUrl.trimEnd('/'))
        }

        fun save(context: Context, uid: Long, password: String, baseUrl: String) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putLong(UID, uid)
                .putString(PASSWORD, password)
                .putString(BASE_URL, baseUrl.trimEnd('/'))
                .apply()
        }

        fun clear(context: Context) {
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
            context.getSharedPreferences("touchfish_background_state", Context.MODE_PRIVATE)
                .edit()
                .clear()
                .apply()
        }
    }
}

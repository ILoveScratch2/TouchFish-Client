package ci.us.ilovescratch.touchfish.astra.v3.touchfish_client

import android.content.Context
import android.util.Base64
import org.json.JSONArray
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import java.security.KeyFactory
import java.security.SecureRandom
import java.security.spec.MGF1ParameterSpec
import java.security.spec.X509EncodedKeySpec
import javax.crypto.Cipher
import javax.crypto.spec.IvParameterSpec
import javax.crypto.spec.OAEPParameterSpec
import javax.crypto.spec.PSource
import javax.crypto.spec.SecretKeySpec

class TouchFishApiClient(private val context: Context) {
    private val random = SecureRandom()

    fun sendMessage(recipient: String, content: String, clientMid: String): Boolean {
        val response = secretPost(
            "/message/send",
            JSONObject().apply {
                put("recipient", recipient)
                put("content", content)
                put("content_type", "plain")
                put("client_mid", clientMid)
                put("file_hash", JSONObject.NULL)
                put("quote", -1)
                put("forwarded", -1)
            },
        ) ?: return false
        return try {
            JSONObject(response)
            true
        } catch (_: Exception) {
            false
        }
    }

    fun queryNotificationsAfter(timestampSeconds: Double): JSONArray? {
        val response = secretPost(
            "/notification/query_after",
            JSONObject().put("time_stamp", timestampSeconds),
        ) ?: return null
        return try {
            JSONArray(response)
        } catch (_: Exception) {
            null
        }
    }

    private fun secretPost(path: String, body: JSONObject): String? {
        val config = NativeNotificationConfig.load(context) ?: return null
        val publicKey = fetchPublicKey(config.baseUrl) ?: return null
        body.put("uid", config.uid)
        body.put("password", config.password)

        val aesKey = ByteArray(32).also(random::nextBytes)
        val iv = ByteArray(16).also(random::nextBytes)
        val encryptedContent = aesEncrypt(body.toString().toByteArray(Charsets.UTF_8), aesKey, iv)
        val encryptedKey = rsaEncrypt(aesKey, publicKey)
        val requestBody = JSONObject().apply {
            put("iv", Base64.encodeToString(iv, Base64.NO_WRAP))
            put("key", Base64.encodeToString(encryptedKey, Base64.NO_WRAP))
            put("content", Base64.encodeToString(encryptedContent, Base64.NO_WRAP))
        }.toString()

        val connection = (URL("${config.baseUrl}$path").openConnection() as HttpURLConnection)
        return try {
            connection.requestMethod = "POST"
            connection.connectTimeout = 10_000
            connection.readTimeout = 15_000
            connection.doOutput = true
            connection.setRequestProperty("Content-Type", "application/json")
            connection.outputStream.use { it.write(requestBody.toByteArray(Charsets.UTF_8)) }
            if (connection.responseCode != HttpURLConnection.HTTP_OK) return null
            val encryptedResponse = connection.inputStream.bufferedReader().use { it.readText() }
            decryptResponse(encryptedResponse, aesKey)
        } catch (_: Exception) {
            null
        } finally {
            connection.disconnect()
        }
    }

    private fun fetchPublicKey(baseUrl: String): java.security.PublicKey? {
        val connection = (URL("$baseUrl/get_rsa_pub").openConnection() as HttpURLConnection)
        return try {
            connection.requestMethod = "GET"
            connection.connectTimeout = 10_000
            connection.readTimeout = 10_000
            if (connection.responseCode !in 200..299) return null
            val pem = connection.inputStream.bufferedReader().use { it.readText() }
            val encoded = pem
                .replace("-----BEGIN PUBLIC KEY-----", "")
                .replace("-----END PUBLIC KEY-----", "")
                .replace(Regex("\\s"), "")
            KeyFactory.getInstance("RSA").generatePublic(
                X509EncodedKeySpec(Base64.decode(encoded, Base64.DEFAULT)),
            )
        } catch (_: Exception) {
            null
        } finally {
            connection.disconnect()
        }
    }

    private fun rsaEncrypt(data: ByteArray, publicKey: java.security.PublicKey): ByteArray {
        val cipher = Cipher.getInstance("RSA/ECB/OAEPPadding")
        val params = OAEPParameterSpec(
            "SHA-256",
            "MGF1",
            MGF1ParameterSpec.SHA256,
            PSource.PSpecified.DEFAULT,
        )
        cipher.init(Cipher.ENCRYPT_MODE, publicKey, params)
        return cipher.doFinal(data)
    }

    private fun aesEncrypt(data: ByteArray, key: ByteArray, iv: ByteArray): ByteArray {
        val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
        cipher.init(Cipher.ENCRYPT_MODE, SecretKeySpec(key, "AES"), IvParameterSpec(iv))
        return cipher.doFinal(data)
    }

    private fun decryptResponse(response: String, key: ByteArray): String {
        val json = JSONObject(response)
        val iv = Base64.decode(json.getString("iv"), Base64.DEFAULT)
        val content = Base64.decode(json.getString("content"), Base64.DEFAULT)
        val cipher = Cipher.getInstance("AES/CBC/PKCS5Padding")
        cipher.init(Cipher.DECRYPT_MODE, SecretKeySpec(key, "AES"), IvParameterSpec(iv))
        return String(cipher.doFinal(content), Charsets.UTF_8)
    }
}

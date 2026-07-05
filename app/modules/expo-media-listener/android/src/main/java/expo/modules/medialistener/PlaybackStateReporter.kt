package expo.modules.medialistener

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONArray
import org.json.JSONObject

object PlaybackStateReporter {
  private const val TAG = "PlaybackStateReporter"
  private const val WEBHOOK_URL = "https://api-lyrink.rakaiseto.com/api/data"
  private val JSON_MEDIA_TYPE = "application/json; charset=utf-8".toMediaType()

  private val client = OkHttpClient.Builder()
    .connectTimeout(10, java.util.concurrent.TimeUnit.SECONDS)
    .writeTimeout(10, java.util.concurrent.TimeUnit.SECONDS)
    .build()

  private var prefs: SharedPreferences? = null

  fun init(context: Context) {
    prefs = context.getSharedPreferences("lyrink_prefs", Context.MODE_PRIVATE)
  }

  fun report(metadata: MediaMetadata) {
    try {
      val codes = getPairingCodes()

      val json = JSONObject().apply {
        put("title", metadata.title ?: JSONObject.NULL)
        put("artist", metadata.artist ?: JSONObject.NULL)
        put("album", metadata.album ?: JSONObject.NULL)
        put("timestamp", System.currentTimeMillis())
        put("albumArtBase64", metadata.albumArtBase64 ?: JSONObject.NULL)
        put("position", metadata.playbackPosition)
        put("duration", metadata.duration)
        put("isPlaying", metadata.isPlaying)
        put("state", metadata.playbackState ?: JSONObject.NULL)
        put("pairingCodes", JSONArray(codes))
      }

      val body = json.toString().toRequestBody(JSON_MEDIA_TYPE)
      val request = Request.Builder()
        .url(WEBHOOK_URL)
        .post(body)
        .build()

      client.newCall(request).enqueue(object : okhttp3.Callback {
        override fun onFailure(call: okhttp3.Call, e: java.io.IOException) {
          Log.e(TAG, "Failed to send playback state", e)
        }

        override fun onResponse(call: okhttp3.Call, response: okhttp3.Response) {
          response.use {
            Log.d(TAG, "State reported: ${response.code}")
          }
        }
      })
    } catch (e: Exception) {
      Log.e(TAG, "Failed to build or send playback state", e)
    }
  }

  private fun getPairingCodes(): List<String> {
    val p = prefs ?: return emptyList()
    val json = p.getString("pairing_codes", "[]") ?: "[]"
    val arr = JSONArray(json)
    val codes = mutableListOf<String>()
    for (i in 0 until arr.length()) {
      codes.add(arr.getString(i))
    }
    return codes
  }
}

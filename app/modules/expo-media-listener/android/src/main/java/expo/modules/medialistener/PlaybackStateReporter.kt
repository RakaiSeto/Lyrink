package expo.modules.medialistener

import android.content.Context
import android.content.SharedPreferences
import android.util.Log
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.Response
import okhttp3.WebSocket
import okhttp3.WebSocketListener
import org.json.JSONArray
import org.json.JSONObject
import java.util.UUID
import java.util.concurrent.TimeUnit
import java.util.concurrent.locks.ReentrantLock
import kotlin.concurrent.withLock

object PlaybackStateReporter {
  private const val TAG = "PlaybackStateReporter"
  private const val WS_URL = "wss://api-lyrink.rakaiseto.com/ws"
  private const val RECONNECT_DELAY_MS = 3000L
  private const val MAX_RECONNECT_DELAY_MS = 60_000L

  private val client = OkHttpClient.Builder()
    .connectTimeout(10, TimeUnit.SECONDS)
    .readTimeout(0, TimeUnit.SECONDS) // no read timeout for WS
    .pingInterval(30, TimeUnit.SECONDS) // client-initiated keepalive
    .build()

  private val lock = ReentrantLock()
  private val connectedCondition = lock.newCondition()

  private var prefs: SharedPreferences? = null
  private var deviceId: String = ""
  private var webSocket: WebSocket? = null
  private var latestState: MediaMetadata? = null
  private var lastReportedMetadata: MediaMetadata? = null
  private var reconnectScheduled = false
  private var reconnectAttempt = 0
  var onControlReceived: ((action: String, position: Long) -> Unit)? = null

  fun init(context: Context) {
    prefs = context.getSharedPreferences("lyrink_prefs", Context.MODE_PRIVATE)
    getOrCreateDeviceId()
    connect()
  }

  fun disconnect() {
    lock.withLock {
      reconnectScheduled = true
      webSocket?.close(1000, "service stopped")
      webSocket = null
      latestState = null
      lastReportedMetadata = null
    }
    Log.d(TAG, "Disconnected")
  }

  private fun getOrCreateDeviceId(): String {
    if (deviceId.isNotEmpty()) return deviceId
    val p = prefs ?: return ""
    val existing = p.getString("device_id", null)
    if (existing != null) {
      deviceId = existing
      return deviceId
    }
    deviceId = UUID.randomUUID().toString()
    p.edit().putString("device_id", deviceId).apply()
    return deviceId
  }

  private fun getPairingCode(): String {
    val p = prefs ?: return ""
    val json = p.getString("pairing_codes", "[]") ?: "[]"
    val arr = JSONArray(json)
    return if (arr.length() > 0) arr.getString(0) else ""
  }

  private fun connect() {
    val request = Request.Builder().url(WS_URL).build()
    webSocket = client.newWebSocket(request, object : WebSocketListener() {
      override fun onOpen(webSocket: WebSocket, response: Response) {
        Log.d(TAG, "WebSocket connected")
        MediaEventEmitter.emitConnectionStatus(true)
        lock.withLock {
          this@PlaybackStateReporter.webSocket = webSocket
          reconnectScheduled = false
          reconnectAttempt = 0
          sendPairMessage(webSocket)
          // Send latest state on reconnect — covers both send-failure buffer and clean reconnect
          val stateToSend = latestState ?: lastReportedMetadata
          if (stateToSend != null) {
            sendDataMessage(webSocket, stateToSend)
            latestState = null
          }
          connectedCondition.signalAll()
        }
      }

      override fun onMessage(webSocket: WebSocket, text: String) {
        Log.d(TAG, "WS message: $text")
        try {
          val json = JSONObject(text)
          if (json.optString("type") == "control") {
            val action = json.optString("action", "")
            val position = json.optLong("position", 0L)
            Log.d(TAG, "Control: action=$action position=$position")
            onControlReceived?.invoke(action, position)
          }
        } catch (e: Exception) {
          Log.e(TAG, "Failed to parse control message", e)
        }
      }

      override fun onClosing(webSocket: WebSocket, code: Int, reason: String) {
        webSocket.close(1000, null)
      }

      override fun onClosed(webSocket: WebSocket, code: Int, reason: String) {
        Log.d(TAG, "WebSocket closed: $code $reason")
        MediaEventEmitter.emitConnectionStatus(false)
        scheduleReconnect()
      }

      override fun onFailure(webSocket: WebSocket, t: Throwable, response: Response?) {
        Log.e(TAG, "WebSocket failure", t)
        MediaEventEmitter.emitConnectionStatus(false)
        scheduleReconnect()
      }
    })
  }

  private fun scheduleReconnect() {
    lock.withLock {
      if (reconnectScheduled) return
      reconnectScheduled = true
      webSocket = null
    }
    val delay = minOf(
      RECONNECT_DELAY_MS * (1 shl reconnectAttempt.coerceAtMost(4)),
      MAX_RECONNECT_DELAY_MS
    )
    reconnectAttempt++
    Thread {
      try {
        Thread.sleep(delay)
      } catch (_: InterruptedException) {
        return@Thread
      }
      lock.withLock { reconnectScheduled = false }
      Log.d(TAG, "Reconnecting (attempt $reconnectAttempt, delay ${delay}ms)...")
      connect()
    }.also { it.isDaemon = true; it.start() }
  }

  private fun sendPairMessage(ws: WebSocket) {
    val code = getPairingCode()
    if (code.isEmpty()) {
      Log.w(TAG, "No pairing code available, skipping pair message")
      return
    }
    val json = JSONObject().apply {
      put("type", "pair")
      put("code", code)
      put("deviceId", getOrCreateDeviceId())
      put("clientType", "phone")
    }
    ws.send(json.toString())
    Log.d(TAG, "Sent pair message")
  }

  private fun sendDataMessage(ws: WebSocket, metadata: MediaMetadata) {
    val json = JSONObject().apply {
      put("type", "data")
      put("title", metadata.title ?: JSONObject.NULL)
      put("artist", metadata.artist ?: JSONObject.NULL)
      put("album", metadata.album ?: JSONObject.NULL)
      put("albumArtBase64", metadata.albumArtBase64 ?: JSONObject.NULL)
      put("timestamp", metadata.capturedAtMs)
      put("position", metadata.playbackPosition)
      put("duration", metadata.duration)
      put("isPlaying", metadata.isPlaying)
      put("deviceId", getOrCreateDeviceId())
    }
    val sent = ws.send(json.toString())
    if (!sent) {
      Log.w(TAG, "WS send returned false, buffering state")
      lock.withLock { latestState = metadata }
    }
  }

  fun report(metadata: MediaMetadata) {
    try {
      lock.withLock {
        lastReportedMetadata = metadata
        val ws = webSocket
        if (ws != null) {
          sendDataMessage(ws, metadata)
        } else {
          // Disconnected — buffer latest state, will be flushed on reconnect
          latestState = metadata
          Log.d(TAG, "Disconnected, buffering state for reconnect")
        }
      }
    } catch (e: Exception) {
      Log.e(TAG, "Failed to send playback state", e)
    }
  }
}
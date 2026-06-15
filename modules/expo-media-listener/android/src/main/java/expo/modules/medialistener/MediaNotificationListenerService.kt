package expo.modules.medialistener

import android.app.Notification
import android.content.ComponentName
import android.content.Context
import android.media.session.MediaController
import android.media.session.MediaSessionManager
import android.media.session.PlaybackState
import android.os.Bundle
import android.service.notification.NotificationListenerService
import android.service.notification.StatusBarNotification
import android.util.Log
import org.json.JSONArray
import org.json.JSONObject

class MediaNotificationListenerService : NotificationListenerService() {
  companion object {
    private const val TAG = "MediaListener"
    private const val YT_MUSIC_PACKAGE = "com.google.android.apps.youtube.music"

    @Volatile
    var isListening = false
      private set

    @Volatile
    var currentMetadata: MediaMetadata? = null
      private set
  }

  private lateinit var sessionManager: MediaSessionManager
  private var ytController: MediaController? = null
  private var lastRawNotificationJson: String? = null

  private val sessionListener = MediaSessionManager.OnActiveSessionsChangedListener { controllers ->
    controllers?.let { onActiveSessionsChanged(it) }
  }

  private val controllerCallback = object : MediaController.Callback() {
    override fun onPlaybackStateChanged(state: PlaybackState?) {
      processMediaController(ytController)
    }
    override fun onSessionDestroyed() {
      ytController = null
      currentMetadata = null
    }
  }

  override fun onCreate() {
    super.onCreate()
    sessionManager = getSystemService(Context.MEDIA_SESSION_SERVICE) as MediaSessionManager
  }

  override fun onListenerConnected() {
    super.onListenerConnected()
    isListening = true
    Log.d(TAG, "Listener connected")
    MediaEventEmitter.emitListeningStatus(true)

    val componentName = ComponentName(this, javaClass)
    sessionManager.addOnActiveSessionsChangedListener(sessionListener, componentName)
    sessionManager.getActiveSessions(componentName)?.let { onActiveSessionsChanged(it) }

    for (sbn in activeNotifications) {
      processNotification(sbn, isNew = false)
    }
  }

  override fun onListenerDisconnected() {
    super.onListenerDisconnected()
    sessionManager.removeOnActiveSessionsChangedListener(sessionListener)
    releaseController()
    isListening = false
    Log.d(TAG, "Listener disconnected")
    MediaEventEmitter.emitListeningStatus(false)
  }

  override fun onNotificationPosted(sbn: StatusBarNotification) {
    processNotification(sbn, isNew = true)
  }

  override fun onNotificationRemoved(sbn: StatusBarNotification) {
    if (sbn.packageName != YT_MUSIC_PACKAGE) return

    val metadata = currentMetadata
    if (metadata != null && metadata.packageName == YT_MUSIC_PACKAGE) {
      val removedMetadata = metadata.copy(isPlaying = false)
      currentMetadata = removedMetadata
      MediaEventEmitter.emit(removedMetadata)
    }
  }

  private fun onActiveSessionsChanged(controllers: List<MediaController>) {
    releaseController()

    val newController = controllers.find { it.packageName == YT_MUSIC_PACKAGE }
    if (newController != null) {
      ytController = newController
      ytController?.registerCallback(controllerCallback)
      processMediaController(ytController)
    }
  }

  private fun releaseController() {
    ytController?.unregisterCallback(controllerCallback)
    ytController = null
  }

  private fun processMediaController(controller: MediaController?) {
    val meta = controller?.metadata ?: return
    val state = controller.playbackState

    val mm = MediaMetadata(
      title = meta.getString("android.media.metadata.TITLE"),
      artist = meta.getString("android.media.metadata.ARTIST"),
      album = meta.getString("android.media.metadata.ALBUM"),
      albumArtUri = meta.getString("android.media.metadata.ALBUM_ART_URI"),
      isPlaying = state?.state == PlaybackState.STATE_PLAYING,
      packageName = controller.packageName,
      rawNotificationJson = lastRawNotificationJson,
      duration = meta.getLong("android.media.metadata.DURATION"),
      playbackPosition = state?.position ?: 0L,
      playbackState = when (state?.state) {
        PlaybackState.STATE_PLAYING -> "playing"
        PlaybackState.STATE_PAUSED -> "paused"
        PlaybackState.STATE_STOPPED -> "stopped"
        PlaybackState.STATE_BUFFERING -> "buffering"
        PlaybackState.STATE_NONE -> "none"
        else -> "unknown"
      },
      rawPlaybackStateJson = toPlaybackStateJson(state)
    )

    emitIfChanged(mm)
  }

  private fun processNotification(sbn: StatusBarNotification, isNew: Boolean) {
    if (sbn.packageName != YT_MUSIC_PACKAGE) return

    val notification = sbn.notification ?: return
    val extras = notification.extras ?: return

    lastRawNotificationJson = toNotificationJson(sbn)

    if (ytController != null) {
      processMediaController(ytController)
      return
    }

    val title = extractText(extras, Notification.EXTRA_TITLE)
    val artist = extractText(extras, Notification.EXTRA_TEXT)
    val subText = extractText(extras, Notification.EXTRA_SUB_TEXT)

    val mediaTitle = extras.getString("android.media.metadata.TITLE")
    val mediaArtist = extras.getString("android.media.metadata.ARTIST")
    val mediaAlbum = extras.getString("android.media.metadata.ALBUM")
    val mediaAlbumArt = extras.getString("android.media.metadata.ALBUM_ART_URI")
    val mediaDuration = extras.getLong("android.media.metadata.DURATION", 0L)

    val isPlaying = detectPlayingState(notification)

    val metadata = MediaMetadata(
      rawNotificationJson = lastRawNotificationJson,
      title = mediaTitle ?: title,
      artist = mediaArtist ?: artist ?: subText,
      album = mediaAlbum,
      albumArtUri = mediaAlbumArt,
      isPlaying = isPlaying,
      packageName = YT_MUSIC_PACKAGE,
      duration = mediaDuration,
      playbackPosition = 0L,
      playbackState = if (isPlaying) "playing" else "paused",
    )

    emitIfChanged(metadata)
  }

  private fun emitIfChanged(metadata: MediaMetadata) {
    val prev = currentMetadata
    if (prev == null ||
      prev.title != metadata.title ||
      prev.artist != metadata.artist ||
      prev.isPlaying != metadata.isPlaying ||
      prev.playbackPosition != metadata.playbackPosition
    ) {
      currentMetadata = metadata
      Log.d(TAG, "Metadata: ${metadata.title} - ${metadata.artist} (${metadata.playbackState})")
      MediaEventEmitter.emit(metadata)
    }
  }

  private fun detectPlayingState(notification: Notification): Boolean {
    val actions = notification.actions ?: return false
    for (action in actions) {
      val label = action.title?.toString()?.lowercase() ?: continue
      if (label.contains("pause")) return true
    }
    for (action in actions) {
      val label = action.title?.toString()?.lowercase() ?: continue
      if (label.contains("play")) return false
    }
    return false
  }

  private fun toNotificationJson(sbn: StatusBarNotification): String {
    val json = JSONObject()
    try {
      json.put("packageName", sbn.packageName)
      json.put("postTime", sbn.postTime)
      json.put("key", sbn.key)
      json.put("isOngoing", sbn.isOngoing)
      json.put("isClearable", sbn.isClearable)

      val notification = sbn.notification
      if (notification != null) {
        val extras = notification.extras
        if (extras != null) {
          val extrasJson = JSONObject()
          for (key in extras.keySet()) {
            val value = extras.get(key)
            extrasJson.put(key, JSONObject.wrap(value))
          }
          json.put("extras", extrasJson)
        }

        val actions = notification.actions
        if (actions != null) {
          val actionsArray = JSONArray()
          for (action in actions) {
            val actionJson = JSONObject()
            actionJson.put("title", action.title?.toString())
            actionJson.put("icon", action.icon)
            if (action.actionIntent != null) {
              actionJson.put("actionIntent", action.actionIntent.toString())
            }
            actionsArray.put(actionJson)
          }
          json.put("actions", actionsArray)
        }
      }
    } catch (e: Exception) {
      Log.e(TAG, "Failed to serialize notification to JSON", e)
    }
    return json.toString()
  }

  private fun toPlaybackStateJson(state: PlaybackState?): String? {
    val ps = state ?: return null
    val json = JSONObject()
    try {
      json.put("state", ps.state)
      json.put("position", ps.position)
      json.put("playbackSpeed", ps.playbackSpeed)
      json.put("lastPositionUpdateTime", ps.lastPositionUpdateTime)
      json.put("bufferedPosition", ps.bufferedPosition)
      json.put("actions", ps.actions)
      json.put("activeQueueItemId", ps.activeQueueItemId)
      json.put("errorMessage", ps.errorMessage?.toString())
    } catch (e: Exception) {
      Log.e(TAG, "Failed to serialize PlaybackState to JSON", e)
    }
    return json.toString()
  }

  private fun extractText(extras: Bundle, key: String): String? {
    val value = extras.get(key) ?: return null
    return when (value) {
      is CharSequence -> value.toString()
      is String -> value
      else -> null
    }
  }
}

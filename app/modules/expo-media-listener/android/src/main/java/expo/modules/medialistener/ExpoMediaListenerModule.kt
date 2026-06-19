package expo.modules.medialistener

import android.content.Context
import android.content.Intent
import android.provider.Settings
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition

class ExpoMediaListenerModule : Module() {
  private val context: Context
    get() = appContext.reactContext ?: throw IllegalStateException("React context unavailable")

  override fun definition() = ModuleDefinition {
    Name("ExpoMediaListener")

    Events("onMediaMetadataChanged", "onListeningStatusChanged")

    Function("startListening") {
      val intent = Intent(context, MediaNotificationListenerService::class.java)
      context.startService(intent)
    }

    Function("stopListening") {
      val intent = Intent(context, MediaNotificationListenerService::class.java)
      context.stopService(intent)
    }

    Function("isListening") {
      MediaNotificationListenerService.isListening
    }

    Function("requestPermission") {
      val intent = Intent(Settings.ACTION_NOTIFICATION_LISTENER_SETTINGS)
      intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      context.startActivity(intent)
    }

    Function("isPermissionGranted") {
      val enabledListeners = Settings.Secure.getString(
        context.contentResolver,
        "enabled_notification_listeners"
      )
      enabledListeners?.contains(context.packageName) == true
    }

    Function("getCurrentMetadata") {
      val metadata = MediaNotificationListenerService.currentMetadata ?: return@Function null
      mapOf(
        "title" to metadata.title,
        "artist" to metadata.artist,
        "album" to metadata.album,
        "albumArtUri" to metadata.albumArtUri,
        "albumArtBase64" to metadata.albumArtBase64,
        "isPlaying" to metadata.isPlaying,
        "packageName" to metadata.packageName,
        "rawNotificationJson" to metadata.rawNotificationJson,
        "duration" to metadata.duration,
        "playbackPosition" to metadata.playbackPosition,
        "playbackState" to metadata.playbackState,
        "rawPlaybackStateJson" to metadata.rawPlaybackStateJson
      )
    }

    OnCreate {
      MediaEventEmitter.onMetadataChanged = { metadata ->
        sendEvent("onMediaMetadataChanged", mapOf(
          "title" to metadata.title,
          "artist" to metadata.artist,
          "album" to metadata.album,
          "albumArtUri" to metadata.albumArtUri,
          "albumArtBase64" to metadata.albumArtBase64,
          "isPlaying" to metadata.isPlaying,
          "packageName" to metadata.packageName,
          "rawNotificationJson" to metadata.rawNotificationJson,
          "duration" to metadata.duration,
          "playbackPosition" to metadata.playbackPosition,
          "playbackState" to metadata.playbackState,
          "rawPlaybackStateJson" to metadata.rawPlaybackStateJson
        ))
      }
      MediaEventEmitter.onListeningStatusChanged = { isListening ->
        sendEvent("onListeningStatusChanged", mapOf("isListening" to isListening))
      }
    }

    OnDestroy {
      MediaEventEmitter.onMetadataChanged = null
      MediaEventEmitter.onListeningStatusChanged = null
    }
  }
}

package expo.modules.medialistener

import android.Manifest
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import expo.modules.kotlin.modules.Module
import expo.modules.kotlin.modules.ModuleDefinition
import org.json.JSONArray

class ExpoMediaListenerModule : Module() {
  private val context: Context
    get() = appContext.reactContext ?: throw IllegalStateException("React context unavailable")

  private var metadataCallback: ((MediaMetadata) -> Unit)? = null
  private var statusCallback: ((Boolean) -> Unit)? = null
  private var connectionStatusCallback: ((Boolean) -> Unit)? = null

  override fun definition() = ModuleDefinition {
    Name("ExpoMediaListener")

    Events("onMediaMetadataChanged", "onListeningStatusChanged", "onWsConnectionStatusChanged")

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

    Function("startForegroundService") {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        if (ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.POST_NOTIFICATIONS
          ) != PackageManager.PERMISSION_GRANTED
        ) {
          val activity = appContext.currentActivity
          if (activity != null) {
            ActivityCompat.requestPermissions(
              activity,
              arrayOf(Manifest.permission.POST_NOTIFICATIONS),
              1001
            )
          }
        }
      }
      val intent = Intent(context, LyrinkForegroundService::class.java)
      ContextCompat.startForegroundService(context, intent)
    }

    Function("stopForegroundService") {
      val intent = Intent(context, LyrinkForegroundService::class.java)
      context.stopService(intent)
    }

    Function("isForegroundServiceRunning") {
      LyrinkForegroundService.isRunning
    }

    Function("isNotificationPermissionGranted") {
      if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
        ContextCompat.checkSelfPermission(
          context,
          Manifest.permission.POST_NOTIFICATIONS
        ) == PackageManager.PERMISSION_GRANTED
      } else {
        true
      }
    }

    Function("addPairingCode") { code: String ->
      val prefs = getPrefs()
      val codes = getCodes(prefs)
      if (!codes.contains(code)) {
        codes.add(code)
        prefs.edit().putString("pairing_codes", JSONArray(codes).toString()).apply()
      }
    }

    Function("removePairingCode") { code: String ->
      val prefs = getPrefs()
      val codes = getCodes(prefs)
      codes.remove(code)
      prefs.edit().putString("pairing_codes", JSONArray(codes).toString()).apply()
    }

    Function("getPairingCodes") {
      val prefs = getPrefs()
      val codes = getCodes(prefs)
      codes.toList()
    }
    Function("sendControl") { action: String ->
      MediaNotificationListenerService.sendControl(action)
    }

    OnCreate {
      metadataCallback = { metadata ->
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
      metadataCallback?.let { MediaEventEmitter.addMetadataListener(it) }

      statusCallback = { isListening ->
        sendEvent("onListeningStatusChanged", mapOf("isListening" to isListening))
      }
      statusCallback?.let { MediaEventEmitter.addStatusListener(it) }

      connectionStatusCallback = { connected ->
        sendEvent("onWsConnectionStatusChanged", mapOf("connected" to connected))
      }
      connectionStatusCallback?.let { MediaEventEmitter.addConnectionStatusListener(it) }
    }

    OnDestroy {
      metadataCallback?.let { MediaEventEmitter.removeMetadataListener(it) }
      metadataCallback = null
      statusCallback?.let { MediaEventEmitter.removeStatusListener(it) }
      statusCallback = null
      connectionStatusCallback?.let { MediaEventEmitter.removeConnectionStatusListener(it) }
      connectionStatusCallback = null
    }
  }

  private fun getPrefs(): SharedPreferences {
    return context.getSharedPreferences("lyrink_prefs", Context.MODE_PRIVATE)
  }

  private fun getCodes(prefs: SharedPreferences): MutableList<String> {
    val json = prefs.getString("pairing_codes", "[]") ?: "[]"
    val arr = JSONArray(json)
    val codes = mutableListOf<String>()
    for (i in 0 until arr.length()) {
      codes.add(arr.getString(i))
    }
    return codes
  }
}

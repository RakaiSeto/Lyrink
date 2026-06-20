package expo.modules.medialistener

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.Service
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.IBinder
import android.util.Log
import androidx.core.app.NotificationCompat

class LyrinkForegroundService : Service() {
  companion object {
    private const val TAG = "LyrinkForeground"
    private const val NOTIFICATION_ID = 1
    private const val CHANNEL_ID = "lyrink_sync_channel"

    @Volatile
    var isRunning = false
      private set
  }

  private var currentSongTitle: String? = null
  private var metadataListener: ((MediaMetadata) -> Unit)? = null

  override fun onCreate() {
    super.onCreate()
    Log.d(TAG, "Foreground service created")
    isRunning = true
    try {
      createNotificationChannel()
    } catch (e: Exception) {
      Log.e(TAG, "Failed to create notification channel", e)
    }

    metadataListener = { metadata ->
      currentSongTitle = metadata.title
      try {
        updateNotification(metadata.title)
      } catch (e: Exception) {
        Log.e(TAG, "Failed to update notification", e)
      }
    }
    metadataListener?.let { MediaEventEmitter.addMetadataListener(it) }
  }

  override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
    try {
      val notification = buildNotification(currentSongTitle)
      startForeground(NOTIFICATION_ID, notification)
      Log.d(TAG, "Foreground service started")
    } catch (e: Exception) {
      Log.e(TAG, "Failed to start foreground", e)
    }
    return START_STICKY
  }

  override fun onBind(intent: Intent?): IBinder? = null

  override fun onDestroy() {
    metadataListener?.let { MediaEventEmitter.removeMetadataListener(it) }
    metadataListener = null
    currentSongTitle = null
    isRunning = false
    try {
      stopForeground(STOP_FOREGROUND_REMOVE)
    } catch (e: Exception) {
      Log.e(TAG, "Failed to stop foreground", e)
    }
    Log.d(TAG, "Foreground service destroyed")
    super.onDestroy()
  }

  private fun createNotificationChannel() {
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel = NotificationChannel(
        CHANNEL_ID,
        "Lyrink Service",
        NotificationManager.IMPORTANCE_LOW
      ).apply {
        description = "Shows Lyrink sync status with current song"
        setShowBadge(false)
      }
      val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
      manager.createNotificationChannel(channel)
    }
  }

  private fun buildNotification(songTitle: String?): Notification {
    val contentText = if (songTitle != null) {
      "Listening to $songTitle"
    } else {
      "Waiting for music..."
    }

    return NotificationCompat.Builder(this, CHANNEL_ID)
      .setContentTitle("Lyrink is running")
      .setContentText(contentText)
      .setSmallIcon(android.R.drawable.ic_dialog_info)
      .setOngoing(true)
      .setPriority(NotificationCompat.PRIORITY_LOW)
      .build()
  }

  private fun updateNotification(songTitle: String?) {
    val notification = buildNotification(songTitle)
    val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
    manager.notify(NOTIFICATION_ID, notification)
  }
}

package expo.modules.medialistener

data class MediaMetadata(
  val title: String? = null,
  val artist: String? = null,
  val album: String? = null,
  val albumArtUri: String? = null,
  val albumArtBase64: String? = null,
  val isPlaying: Boolean = false,
  val packageName: String? = null,
  val rawNotificationJson: String? = null,
  val duration: Long = 0L,
  val playbackPosition: Long = 0L,
  val playbackState: String? = null,
  val rawPlaybackStateJson: String? = null
)

object MediaEventEmitter {
  private val metadataListeners = mutableListOf<(MediaMetadata) -> Unit>()
  private val statusListeners = mutableListOf<(Boolean) -> Unit>()

  fun addMetadataListener(listener: (MediaMetadata) -> Unit) {
    metadataListeners.add(listener)
  }

  fun removeMetadataListener(listener: (MediaMetadata) -> Unit) {
    metadataListeners.remove(listener)
  }

  fun emit(metadata: MediaMetadata) {
    metadataListeners.forEach { it(metadata) }
  }

  fun addStatusListener(listener: (Boolean) -> Unit) {
    statusListeners.add(listener)
  }

  fun removeStatusListener(listener: (Boolean) -> Unit) {
    statusListeners.remove(listener)
  }

  fun emitListeningStatus(isListening: Boolean) {
    statusListeners.forEach { it(isListening) }
  }
}

package expo.modules.medialistener

data class MediaMetadata(
  val title: String? = null,
  val artist: String? = null,
  val album: String? = null,
  val albumArtUri: String? = null,
  val isPlaying: Boolean = false,
  val packageName: String? = null,
  val rawNotificationJson: String? = null,
  val duration: Long = 0L,
  val playbackPosition: Long = 0L,
  val playbackState: String? = null,
  val rawPlaybackStateJson: String? = null
)

object MediaEventEmitter {
  var onMetadataChanged: ((MediaMetadata) -> Unit)? = null

  fun emit(metadata: MediaMetadata) {
    onMetadataChanged?.invoke(metadata)
  }

  var onListeningStatusChanged: ((Boolean) -> Unit)? = null

  fun emitListeningStatus(isListening: Boolean) {
    onListeningStatusChanged?.invoke(isListening)
  }
}

import * as Device from 'expo-device';
import { useEffect, useRef, useState } from 'react';
import { Image, Platform, Pressable, StyleSheet, View } from 'react-native';
import { SafeAreaView } from 'react-native-safe-area-context';

import { AnimatedIcon } from '@/components/animated-icon';
import { HintRow } from '@/components/hint-row';
import { ThemedText } from '@/components/themed-text';
import { ThemedView } from '@/components/themed-view';
import { WebBadge } from '@/components/web-badge';
import { BottomTabInset, MaxContentWidth, Spacing } from '@/constants/theme';
import { useMediaMetadata } from '@/hooks/use-media-metadata';

function getDevMenuHint() {
  if (Platform.OS === 'web') {
    return <ThemedText type="small">use browser devtools</ThemedText>;
  }
  if (Device.isDevice) {
    return (
      <ThemedText type="small">
        shake device or press <ThemedText type="code">m</ThemedText> in terminal
      </ThemedText>
    );
  }
  const shortcut = Platform.OS === 'android' ? 'cmd+m (or ctrl+m)' : 'cmd+d';
  return (
    <ThemedText type="small">
      press <ThemedText type="code">{shortcut}</ThemedText>
    </ThemedText>
  );
}

function formatTime(ms: number): string {
  const totalSeconds = Math.max(0, Math.floor(ms / 1000));
  const minutes = Math.floor(totalSeconds / 60);
  const seconds = totalSeconds % 60;
  return `${minutes}:${seconds.toString().padStart(2, '0')}`;
}

function NowPlayingCard() {
  const { metadata, permissionGranted, openSettings, isListening, serviceRunning, toggleService } =
    useMediaMetadata();

  const [displayPosition, setDisplayPosition] = useState(0);
  const lastNativeRef = useRef({ position: 0, timestamp: Date.now() });

  useEffect(() => {
    if (!metadata) return;
    lastNativeRef.current = {
      position: metadata.playbackPosition,
      timestamp: Date.now(),
    };
    setDisplayPosition(metadata.playbackPosition);
  }, [metadata?.playbackPosition, metadata?.isPlaying]);

  useEffect(() => {
    if (!metadata?.isPlaying || !metadata.duration) return;
    const interval = setInterval(() => {
      const { position, timestamp } = lastNativeRef.current;
      const elapsed = Date.now() - timestamp;
      const newPos = Math.min(position + elapsed, metadata.duration);
      setDisplayPosition(newPos);
    }, 500);
    return () => clearInterval(interval);
  }, [metadata?.isPlaying, metadata?.duration]);

  const progress = metadata?.duration
    ? Math.min(displayPosition / metadata.duration, 1)
    : 0;

  if (Platform.OS !== 'android') return null;

  if (!permissionGranted) {
    return (
      <ThemedView type="backgroundElement" style={styles.nowPlayingCard}>
        <ThemedText type="subtitle" style={styles.sectionTitle}>
          Now Playing
        </ThemedText>
        <ThemedText style={styles.permissionText}>
          Enable notification access to detect YouTube Music
        </ThemedText>
        <Pressable style={styles.primaryButton} onPress={openSettings}>
          <ThemedText style={styles.primaryButtonText}>
            Open Settings
          </ThemedText>
        </Pressable>
      </ThemedView>
    );
  }

  if (!isListening) {
    return (
      <ThemedView type="backgroundElement" style={styles.nowPlayingCard}>
        <ThemedText type="subtitle" style={styles.sectionTitle}>
          Now Playing
        </ThemedText>
        <ThemedText>Listening service not running...</ThemedText>
      </ThemedView>
    );
  }

  return (
    <ThemedView type="backgroundElement" style={styles.nowPlayingCard}>
      <ThemedView style={styles.serviceRow}>
        <ThemedView style={styles.serviceStatus}>
          <ThemedView style={[styles.statusDot, serviceRunning && styles.statusDotActive]} />
          <ThemedText type="small" style={styles.serviceLabel}>
            {serviceRunning ? 'Active' : 'Inactive'}
          </ThemedText>
        </ThemedView>
        <Pressable
          style={[styles.toggleButton, serviceRunning && styles.toggleButtonActive]}
          onPress={toggleService}
        >
          <ThemedText style={styles.toggleButtonText}>
            {serviceRunning ? 'Stop' : 'Start'}
          </ThemedText>
        </Pressable>
      </ThemedView>

      {metadata && metadata.title ? (
        <>
          <ThemedView style={styles.songRow}>
            {metadata.albumArtBase64 ? (
              <Image source={{ uri: `data:image/jpeg;base64,${metadata.albumArtBase64}` }} style={styles.albumArt} />
            ) : metadata.albumArtUri ? (
              <Image source={{ uri: metadata.albumArtUri }} style={styles.albumArt} />
            ) : (
              <ThemedView style={[styles.albumArt, styles.albumArtPlaceholder]}>
                <ThemedText type="title" style={styles.albumArtText}>
                  ♪
                </ThemedText>
              </ThemedView>
            )}

            <ThemedView style={styles.songInfo}>
              {metadata.album && (
                <ThemedView style={styles.albumLabel}>
                  <ThemedText type="small" style={styles.albumLabelText}>
                    ♪ {metadata.album.toUpperCase()}
                  </ThemedText>
                </ThemedView>
              )}
              <ThemedText style={styles.songTitle}>
                {metadata.title}
              </ThemedText>
              {metadata.artist && (
                <ThemedView style={styles.artistRow}>
                  <ThemedText type="small" style={styles.artistIcon}>
                    •
                  </ThemedText>
                  <ThemedText type="small">
                    {metadata.artist}
                  </ThemedText>
                </ThemedView>
              )}
              <ThemedView style={styles.statusRow}>
                <ThemedText style={[styles.statusIcon, metadata.isPlaying && styles.statusIconPlaying]}>
                  {metadata.isPlaying ? '▸' : '‖'}
                </ThemedText>
                <ThemedText type="small">
                  {metadata.isPlaying ? 'Playing' : 'Paused'}
                </ThemedText>
              </ThemedView>
            </ThemedView>
          </ThemedView>

          {metadata.playbackState && metadata.duration > 0 && (
            <View style={styles.progressSection}>
              <View style={styles.progressRow}>
                <ThemedText type="small" style={styles.progressTime}>
                  {formatTime(displayPosition)}
                </ThemedText>
                <View style={styles.progressTrack}>
                  <View
                    style={[styles.progressFill, { width: `${progress * 100}%` }]}
                  />
                </View>
                <ThemedText type="small" style={styles.progressTime}>
                  {formatTime(metadata.duration)}
                </ThemedText>
              </View>
            </View>
          )}
        </>
      ) : (
        <ThemedView style={styles.noMusicContainer}>
          <ThemedText>No music detected</ThemedText>
          {!serviceRunning && (
            <ThemedText type="small" style={styles.hintText}>
              Start the service to begin syncing
            </ThemedText>
          )}
        </ThemedView>
      )}
    </ThemedView>
  );
}

export default function HomeScreen() {
  return (
    <ThemedView style={styles.container}>
      <SafeAreaView style={styles.safeArea}>
        <NowPlayingCard />

        {Platform.OS === 'web' && <WebBadge />}
      </SafeAreaView>
    </ThemedView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    justifyContent: 'center',
    flexDirection: 'row',
  },
  safeArea: {
    flex: 1,
    paddingHorizontal: Spacing.four,
    alignItems: 'center',
    gap: Spacing.three,
    paddingBottom: BottomTabInset + Spacing.three,
    maxWidth: MaxContentWidth,
  },
  heroSection: {
    alignItems: 'center',
    justifyContent: 'center',
    flex: 1,
    paddingHorizontal: Spacing.four,
    gap: Spacing.four,
  },
  title: {
    textAlign: 'center',
  },
  code: {
    textTransform: 'uppercase',
  },
  stepContainer: {
    gap: Spacing.three,
    alignSelf: 'stretch',
    paddingHorizontal: Spacing.three,
    paddingVertical: Spacing.four,
    borderRadius: Spacing.four,
  },
  nowPlayingCard: {
    alignSelf: 'stretch',
    paddingHorizontal: Spacing.three,
    paddingVertical: Spacing.three,
    borderRadius: Spacing.four,
    gap: Spacing.three,
  },
  sectionTitle: {
    textAlign: 'center',
  },
  permissionText: {
    textAlign: 'center',
  },
  primaryButton: {
    backgroundColor: '#208AEF',
    paddingVertical: Spacing.one,
    paddingHorizontal: Spacing.three,
    borderRadius: Spacing.two,
    alignSelf: 'center',
  },
  primaryButtonText: {
    color: '#FFFFFF',
  },
  serviceRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
  },
  serviceStatus: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.one,
  },
  statusDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
    backgroundColor: '#666',
  },
  statusDotActive: {
    backgroundColor: '#34C759',
  },
  serviceLabel: {
    fontWeight: 600,
  },
  toggleButton: {
    backgroundColor: '#208AEF',
    paddingVertical: Spacing.one,
    paddingHorizontal: Spacing.three,
    borderRadius: Spacing.two,
  },
  toggleButtonActive: {
    backgroundColor: '#FF3B30',
  },
  toggleButtonText: {
    color: '#FFFFFF',
    fontWeight: 700,
    fontSize: 14,
  },
  noMusicContainer: {
    alignItems: 'center',
    paddingVertical: Spacing.three,
    gap: Spacing.one,
  },
  hintText: {
    opacity: 0.6,
  },
  songRow: {
    flexDirection: 'row',
    gap: Spacing.three,
  },
  albumArt: {
    width: 120,
    height: 120,
    borderRadius: Spacing.two,
  },
  albumArtPlaceholder: {
    backgroundColor: '#333',
    alignItems: 'center',
    justifyContent: 'center',
  },
  albumArtText: {
    color: '#FFF',
  },
  progressSection: {
    marginTop: Spacing.one,
  },
  progressRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.two,
  },
  progressTrack: {
    flex: 1,
    height: 4,
    backgroundColor: 'rgba(128, 128, 128, 0.3)',
    borderRadius: 2,
    overflow: 'hidden',
  },
  progressFill: {
    height: '100%',
    backgroundColor: '#208AEF',
    borderRadius: 2,
  },
  progressTime: {
    fontVariant: ['tabular-nums'],
    minWidth: 32,
  },
  songInfo: {
    flex: 1,
    gap: Spacing.one,
    overflow: 'hidden',
  },
  albumLabel: {
    alignSelf: 'flex-start',
    backgroundColor: '#208AEF33',
    paddingHorizontal: Spacing.two,
    paddingVertical: Spacing.half,
    borderRadius: Spacing.one,
  },
  albumLabelText: {
    fontSize: 11,
    fontWeight: 600,
    letterSpacing: 0.5,
  },
  artistRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.one,
    alignSelf: 'flex-start',
    flexShrink: 1,
    paddingHorizontal: Spacing.two,
    paddingVertical: Spacing.half,
    borderRadius: Spacing.five,
    backgroundColor: '#208AEF55',
  },
  artistIcon: {
    fontSize: 12,
    color: '#208AEF',
  },
  statusRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: Spacing.one,
    alignSelf: 'flex-start',
    flexShrink: 1,
    paddingHorizontal: Spacing.two,
    paddingVertical: Spacing.half,
    borderRadius: Spacing.five,
    backgroundColor: '#208AEF55',
  },
  statusIcon: {
    fontSize: 14,
    color: '#208AEF',
  },
  statusIconPlaying: {
    color: '#208AEF',
  },
  songTitle: {
    fontSize: 18,
    fontWeight: 700,
    lineHeight: 24,
  },
  metadataJson: {
    fontSize: 10,
    lineHeight: 14,
    fontFamily: Platform.OS === 'ios' ? 'Menlo' : 'monospace',
    padding: Spacing.two,
    backgroundColor: 'rgba(0,0,0,0.1)',
    borderRadius: Spacing.one,
    overflow: 'hidden',
  },
});

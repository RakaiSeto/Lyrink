import * as Device from 'expo-device';
import { Image, Platform, Pressable, StyleSheet } from 'react-native';
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

function NowPlayingCard() {
  const { metadata, permissionGranted, openSettings, isListening } =
    useMediaMetadata();

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
        <Pressable style={styles.permissionButton} onPress={openSettings}>
          <ThemedText style={styles.permissionButtonText}>
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

  if (!metadata || !metadata.title) {
    return (
      <ThemedView type="backgroundElement" style={styles.nowPlayingCard}>
        <ThemedText type="subtitle" style={styles.sectionTitle}>
          Now Playing
        </ThemedText>
        <ThemedText>No music detected</ThemedText>
      </ThemedView>
    );
  }

  return (
    <ThemedView type="backgroundElement" style={styles.nowPlayingCard}>
      <ThemedText type="subtitle" style={styles.sectionTitle}>
        Now Playing
      </ThemedText>

      <ThemedView style={styles.songRow}>
        {metadata.albumArtUri ? (
          <Image source={{ uri: metadata.albumArtUri }} style={styles.albumArt} />
        ) : (
          <ThemedView style={[styles.albumArt, styles.albumArtPlaceholder]}>
            <ThemedText type="title" style={styles.albumArtText}>
              ♪
            </ThemedText>
          </ThemedView>
        )}

        <ThemedView style={styles.songInfo}>
          <ThemedText style={styles.songTitle} numberOfLines={1}>
            {metadata.title}
          </ThemedText>
          {metadata.artist && (
            <ThemedText type="small" numberOfLines={1}>
              {metadata.artist}
            </ThemedText>
          )}
          {metadata.album && (
            <ThemedText type="small" numberOfLines={1}>
              {metadata.album}
            </ThemedText>
          )}
          <ThemedText type="small">
            {metadata.isPlaying ? '▶ Playing' : '⏸ Paused'}
          </ThemedText>
          {metadata.playbackState && (
            <ThemedText type="small">
              pos: {metadata.playbackPosition}ms / {metadata.duration}ms ({metadata.playbackState})
            </ThemedText>
          )}
        </ThemedView>
      </ThemedView>

      {metadata.rawPlaybackStateJson && (
        <ThemedText type="code" style={styles.metadataJson}>
          {(() => {
            try {
              return JSON.stringify(JSON.parse(metadata.rawPlaybackStateJson), null, 2);
            } catch {
              return metadata.rawPlaybackStateJson;
            }
          })()}
        </ThemedText>
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
    gap: Spacing.two,
  },
  sectionTitle: {
    textAlign: 'center',
  },
  permissionText: {
    textAlign: 'center',
  },
  permissionButton: {
    backgroundColor: '#208AEF',
    paddingVertical: Spacing.one,
    paddingHorizontal: Spacing.three,
    borderRadius: Spacing.two,
    alignSelf: 'center',
  },
  permissionButtonText: {
    color: '#FFFFFF',
  },
  songRow: {
    flexDirection: 'row',
    gap: Spacing.two,
    alignItems: 'center',
  },
  albumArt: {
    width: 64,
    height: 64,
    borderRadius: Spacing.one,
  },
  albumArtPlaceholder: {
    backgroundColor: '#333',
    alignItems: 'center',
    justifyContent: 'center',
  },
  albumArtText: {
    color: '#FFF',
  },
  songInfo: {
    flex: 1,
    gap: Spacing.one / 4,
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

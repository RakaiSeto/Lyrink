import { useEffect, useState, useCallback } from 'react';
import { Platform } from 'react-native';

import {
  addMediaMetadataListener,
  getCurrentMetadata,
  isPermissionGranted,
  requestPermission,
  startListening,
  stopListening,
} from '../../modules/expo-media-listener/src/index';

import type { MediaMetadata } from '../../modules/expo-media-listener/src/types';

export function useMediaMetadata() {
  const [metadata, setMetadata] = useState<MediaMetadata | null>(null);
  const [permissionGranted, setPermissionGranted] = useState(false);

  useEffect(() => {
    if (Platform.OS !== 'android') return;

    isPermissionGranted().then((granted) => {
      setPermissionGranted(granted);
      if (granted) {
        getCurrentMetadata().then(setMetadata);
        startListening();
      }
    });

    const removeListener = addMediaMetadataListener((data) => {
      setMetadata(data);
    });

    return () => {
      removeListener();
      stopListening();
    };
  }, []);

  const openSettings = useCallback(() => {
    requestPermission();
  }, []);

  const refresh = useCallback(async () => {
    if (Platform.OS !== 'android') return;
    const granted = await isPermissionGranted();
    setPermissionGranted(granted);
    if (granted) {
      const meta = await getCurrentMetadata();
      setMetadata(meta);
      startListening();
    }
  }, []);

  return {
    metadata,
    permissionGranted,
    isListening: Platform.OS === 'android' && permissionGranted,
    openSettings,
    refresh,
  };
}

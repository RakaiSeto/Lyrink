import { useEffect, useState, useCallback } from 'react';
import { Platform } from 'react-native';

import {
  addMediaMetadataListener,
  getCurrentMetadata,
  isPermissionGranted,
  requestPermission,
  startListening,
  stopListening,
  startForegroundService,
  stopForegroundService,
  isForegroundServiceRunning,
  sendControl,
  addWsConnectionStatusListener,
} from '../../modules/expo-media-listener/src/index';

import type { MediaMetadata } from '../../modules/expo-media-listener/src/types';

export function useMediaMetadata() {
  const [metadata, setMetadata] = useState<MediaMetadata | null>(null);
  const [permissionGranted, setPermissionGranted] = useState(false);
  const [wsConnected, setWsConnected] = useState(false);
  const [serviceRunning, setServiceRunning] = useState(false);

  useEffect(() => {
    if (Platform.OS !== 'android') return;

    isPermissionGranted().then((granted) => {
      setPermissionGranted(granted);
      if (granted) {
        getCurrentMetadata().then(setMetadata);
        startListening();
      }
    });

    isForegroundServiceRunning().then(setServiceRunning);

    const removeListener = addMediaMetadataListener((data) => {
      setMetadata(data);
    });

    const removeWsListener = addWsConnectionStatusListener((status) => {
      setWsConnected(status.connected);
    });

    return () => {
      removeListener();
      removeWsListener();
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

  const toggleService = useCallback(async () => {
    if (Platform.OS !== 'android') return;

    const running = await isForegroundServiceRunning();
    if (running) {
      stopForegroundService();
      setServiceRunning(false);
    } else {
      startForegroundService();
      setServiceRunning(true);
    }
  }, []);

  return {
    metadata,
    permissionGranted,
    isListening: Platform.OS === 'android' && permissionGranted,
    serviceRunning,
    wsConnected,
    openSettings,
    refresh,
    toggleService,
    sendControl,
  };
}

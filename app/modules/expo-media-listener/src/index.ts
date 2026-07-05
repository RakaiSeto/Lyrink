import { EventEmitter, Platform } from 'expo-modules-core';
import ExpoMediaListener from './ExpoMediaListener';
import type { MediaMetadata, ListeningStatus } from './types';

const emitter = new EventEmitter(ExpoMediaListener);

export type { MediaMetadata, ListeningStatus };

export function startListening(): void {
  if (Platform.OS !== 'android') return;
  ExpoMediaListener.startListening();
}

export function stopListening(): void {
  if (Platform.OS !== 'android') return;
  ExpoMediaListener.stopListening();
}

export async function isListening(): Promise<boolean> {
  if (Platform.OS !== 'android') return false;
  return ExpoMediaListener.isListening();
}

export function requestPermission(): void {
  if (Platform.OS !== 'android') return;
  ExpoMediaListener.requestPermission();
}

export async function isPermissionGranted(): Promise<boolean> {
  if (Platform.OS !== 'android') return false;
  return ExpoMediaListener.isPermissionGranted();
}

export async function getCurrentMetadata(): Promise<MediaMetadata | null> {
  if (Platform.OS !== 'android') return null;
  return ExpoMediaListener.getCurrentMetadata();
}

export function startForegroundService(): void {
  if (Platform.OS !== 'android') return;
  ExpoMediaListener.startForegroundService();
}

export function stopForegroundService(): void {
  if (Platform.OS !== 'android') return;
  ExpoMediaListener.stopForegroundService();
}

export async function isForegroundServiceRunning(): Promise<boolean> {
  if (Platform.OS !== 'android') return false;
  return ExpoMediaListener.isForegroundServiceRunning();
}

export async function isNotificationPermissionGranted(): Promise<boolean> {
  if (Platform.OS !== 'android') return true;
  return ExpoMediaListener.isNotificationPermissionGranted();
}

export function addMediaMetadataListener(
  listener: (metadata: MediaMetadata) => void
): () => void {
  if (Platform.OS !== 'android') return () => {};

  const subscription = emitter.addListener<MediaMetadata>(
    'onMediaMetadataChanged',
    listener
  );
  return () => subscription.remove();
}

export function addListeningStatusListener(
  listener: (status: ListeningStatus) => void
): () => void {
  if (Platform.OS !== 'android') return () => {};

  const subscription = emitter.addListener<ListeningStatus>(
    'onListeningStatusChanged',
    listener
  );
  return () => subscription.remove();
}

export async function addPairingCode(code: string): Promise<void> {
  if (Platform.OS !== 'android') return;
  return ExpoMediaListener.addPairingCode(code);
}

export async function removePairingCode(code: string): Promise<void> {
  if (Platform.OS !== 'android') return;
  return ExpoMediaListener.removePairingCode(code);
}

export async function getPairingCodes(): Promise<string[]> {
  if (Platform.OS !== 'android') return [];
  return ExpoMediaListener.getPairingCodes();
}

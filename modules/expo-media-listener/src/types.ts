export type MediaMetadata = {
  title: string | null;
  artist: string | null;
  album: string | null;
  albumArtUri: string | null;
  albumArtBase64: string | null;
  isPlaying: boolean;
  packageName: string | null;
  rawNotificationJson: string | null;
  duration: number;
  playbackPosition: number;
  playbackState: string | null;
  rawPlaybackStateJson: string | null;
};  

export type ListeningStatus = {
  isListening: boolean;
};

export type NativeEventPayload = Record<string, unknown>;

export type ModuleDefinition = {
  startListening(): void;
  stopListening(): void;
  isListening(): Promise<boolean>;
  requestPermission(): void;
  isPermissionGranted(): Promise<boolean>;
  getCurrentMetadata(): Promise<MediaMetadata | null>;
  addListener(eventName: string): void;
  removeListeners(count: number): void;
};

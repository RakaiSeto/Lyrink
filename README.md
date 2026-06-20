# Lyrink

Real-time music playback tracking and syncing platform for YouTube Music on Android.

## Features

- **YouTube Music Detection** — Listens for YouTube Music notifications and extracts full media metadata (title, artist, album, album art, duration, playback position, play/pause state)
- **Real-time Playback Tracking** — Uses Android `MediaSessionManager` for accurate playback state with 500ms JS-side interpolation
- **Foreground Service** — Persistent Android foreground service with a notification showing the currently playing song
- **Server Sync** — Sends playback state to a remote Go server via HTTP POST and WebSocket
- **Album Art Handling** — Extracts album art from YouTube Music, converts to Base64, displays in-app and syncs to server
- **Dark/Light Theme** — Automatic color scheme detection
- **Cross-platform** — Android (full functionality), iOS (stub), Web (limited UI)

## Prerequisites

- Node.js >= 18
- Expo CLI (`npx expo`)
- Android Studio (for Android builds)
- Docker & Docker Compose (for server deployment)

## Getting Started

### Client (Mobile App)

```bash
# Install dependencies
cd app
npm install

# Start dev server
npx expo start

# Build & run on Android
npx expo run:android

# Build & run on iOS (stub only, media listener not functional)
npx expo run:ios

# Web preview
npx expo start --web
```

### Server

The server is a pre-compiled Go binary that receives playback state via HTTP POST and WebSocket connections.

```bash
# Start server with Docker Compose
docker compose up -d

# Server runs on port 8080
# Endpoints:
#   POST /api/data    — receives playback state JSON
#   WebSocket         — real-time playback sync
```

## Project Structure

```
├── app/                          # Expo / React Native mobile app
│   ├── src/
│   │   ├── app/                  # File-based routing (expo-router)
│   │   │   ├── _layout.tsx       # Root layout with theme + splash
│   │   │   └── index.tsx         # Home screen with NowPlayingCard
│   │   ├── components/           # UI components
│   │   │   ├── app-tabs.tsx      # Native tab bar
│   │   │   ├── app-tabs.web.tsx  # Web tab bar
│   │   │   └── ui/               # Reusable UI primitives
│   │   ├── constants/theme.ts    # Colors, spacing, fonts
│   │   └── hooks/
│   │       ├── use-media-metadata.ts  # Core hook for media listener
│   │       └── use-theme.ts          # Theme colors
│   ├── modules/
│   │   └── expo-media-listener/  # Custom Expo native module (Kotlin)
│   │       ├── android/src/main/java/expo/modules/medialistener/
│   │       │   ├── ExpoMediaListenerModule.kt         # JS bridge
│   │       │   ├── MediaNotificationListenerService.kt # NotificationListener
│   │       │   ├── LyrinkForegroundService.kt         # Foreground service
│   │       │   ├── MediaEventEmitter.kt               # Event bus
│   │       │   └── PlaybackStateReporter.kt           # HTTP sync to server
│   │       └── src/index.ts      # TypeScript API surface
│   ├── plugins/
│   │   ├── withMediaListener.js          # AndroidManifest config plugin
│   │   └── withReactNativeArchitectures.js
│   └── app.json                  # Expo configuration
├── server/                       # Pre-compiled Go server (binary)
│   ├── server                    # ELF x86-64 binary
│   └── uploads/                  # Album art uploads
└── docker-compose.yml            # Server deployment config
```

## Architecture

```
YouTube Music Notification
        │
        ▼
MediaNotificationListenerService (Android)
        │
        ├──► MediaSessionManager → real-time playback state
        │
        ▼
MediaEventEmitter (event bus)
        │
        ├──► JS Hook (useMediaMetadata) → UI
        │
        └──► PlaybackStateReporter → Go Server (HTTP POST)
```

1. **MediaNotificationListenerService** — Android `NotificationListenerService` that intercepts YouTube Music notifications and queries `MediaSessionManager` for accurate playback data
2. **MediaEventEmitter** — Central Kotlin event bus that broadcasts `MediaMetadata` to all listeners
3. **useMediaMetadata** — React hook that subscribes to native events, manages permissions, and exposes playback state to the UI
4. **PlaybackStateReporter** — Sends metadata JSON to the server via OkHttp POST whenever playback state changes
5. **Go Server** — Receives and stores playback data, serves album art, supports WebSocket for real-time clients

## Configuration

### Webhook URL

The server endpoint is hardcoded in:
```
app/modules/expo-media-listener/android/src/main/java/expo/modules/medialistener/PlaybackStateReporter.kt
```
```kotlin
private const val WEBHOOK_URL = "https://api-lyrink.rakaiseto.com/api/data"
```

### Expo Config Plugin

`plugins/withMediaListener.js` modifies `AndroidManifest.xml` to add:
- Permissions: `FOREGROUND_SERVICE`, `POST_NOTIFICATIONS`, `INTERNET`
- Services: `MediaNotificationListenerService`, `LyrinkForegroundService`

## Scripts

| Command | Description |
|---------|-------------|
| `npx expo start` | Start Expo dev server |
| `npx expo run:android` | Build & run on Android |
| `npx expo run:ios` | Build & run on iOS |
| `npx expo start --web` | Web preview |
| `npx expo lint` | Run ESLint |

## License

MIT

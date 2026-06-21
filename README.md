# Lyrink

Real-time synced lyrics display for YouTube Music on Android, delivered to your KDE Plasma desktop.

## Features

- **YouTube Music Detection** — Intercepts notifications and queries `MediaSessionManager` for accurate playback state (title, artist, album, position, duration, play/pause)
- **Real-time Server Sync** — Streams playback state from Android to a Go server via HTTP POST, then fans out to all connected clients via WebSocket
- **Synced Lyrics Display** — KDE Plasma widget fetches time-synced lyrics from [lrclib.net](https://lrclib.net) and displays them synchronized to playback position
- **Lyrics Caching** — Local SQLite cache (via `QtQuick.LocalStorage`) avoids redundant API calls for recently fetched tracks
- **Album Art** — Extracts album art from YouTube Music, converts to Base64, and displays across all components
- **Foreground Service** — Persistent Android notification keeps the app alive in the background
- **Dark/Light Theme** — Automatic color scheme detection in the mobile app
- **Cross-platform** — Android (full), iOS (stub), Web (limited UI)

## Architecture Overview

Lyrink is a three-component system: an **Android app** that captures playback state, a **Go server** that relays it in real time, and a **KDE Plasma widget** that displays synced lyrics.

```
┌──────────────────────────┐
│   YouTube Music (Android) │
└─────────────┬────────────┘
              │ NotificationListenerService
              ▼
┌──────────────────────────────────────────────┐
│           Android App (Expo + Kotlin)         │
│                                               │
│  MediaNotificationListenerService            │
│    ├─ queries MediaSessionManager (position) │
│    └─ emits MediaMetadata via EventEmitter   │
│         ├─► JS layer (useMediaMetadata hook) │
│         └─► PlaybackStateReporter            │
│               └─ HTTP POST ──────────────────┼──┐
└──────────────────────────────────────────────┘  │
                                                  │
┌──────────────────────────────────────────────┐  │
│           Go Server (Gin, :8080)              │◄─┘
│                                               │
│  POST /api/data  →  Hub.broadcast            │
│  GET  /ws        ←  WebSocket clients        │
└──────────────────────┬───────────────────────┘
                       │ WebSocket push
                       ▼
┌──────────────────────────────────────────────┐
│        KDE Plasma Widget (QML)                │
│                                               │
│  WebSocket client → parse JSON               │
│  → detect track change → fetch lyrics        │
│  → cache in SQLite → sync to playback pos    │
└──────────────────────────────────────────────┘
```

### How it works

1. The **Android app** runs a `NotificationListenerService` that intercepts YouTube Music notifications. It queries `MediaSessionManager` for accurate playback position and state, then emits `MediaMetadata` events through a central `MediaEventEmitter` event bus.
2. When the **foreground service** is running, `PlaybackStateReporter` sends the metadata as an HTTP POST to the Go server on every state change (track switch, play/pause, position update).
3. The **Go server** is a stateless fan-out relay. It receives the POST body and broadcasts it verbatim to all connected WebSocket clients. No data is stored or transformed.
4. The **KDE Plasma widget** connects via WebSocket, receives playback state, and detects track changes by comparing `title + "|||" + artist`. On new tracks, it fetches synced lyrics from the lrclib.net API, parses the LRC format, caches the result in SQLite, and synchronizes the displayed lyric line to the interpolated playback position every 100ms.

## Project Structure

```
├── app/                                # Expo / React Native mobile app
│   ├── src/
│   │   ├── app/                        # File-based routing (expo-router)
│   │   │   ├── _layout.tsx             # Root layout with theme + splash
│   │   │   └── index.tsx               # Home: NowPlayingCard with playback UI
│   │   ├── components/                 # UI components
│   │   │   ├── app-tabs.tsx            # Native tab bar
│   │   │   ├── animated-icon.tsx       # Animated splash/logo
│   │   │   ├── themed-text.tsx         # Theme-aware text
│   │   │   └── ui/                     # Reusable UI primitives
│   │   ├── constants/theme.ts          # Colors, spacing, fonts
│   │   └── hooks/
│   │       ├── use-media-metadata.ts   # Core hook: permissions, metadata, service
│   │       └── use-theme.ts            # Theme colors
│   ├── modules/
│   │   └── expo-media-listener/        # Custom Expo native module
│   │       ├── src/                    # TypeScript API surface
│   │       │   ├── index.ts            # Public API (startListening, etc.)
│   │       │   └── types.ts            # MediaMetadata, ListeningStatus types
│   │       └── android/src/main/java/expo/modules/medialistener/
│   │           ├── ExpoMediaListenerModule.kt       # JS ↔ Kotlin bridge
│   │           ├── MediaNotificationListenerService.kt  # Core detection engine
│   │           ├── MediaEventEmitter.kt             # Event bus + data model
│   │           ├── LyrinkForegroundService.kt       # Persistent foreground service
│   │           └── PlaybackStateReporter.kt         # HTTP POST to server
│   ├── plugins/
│   │   ├── withMediaListener.js        # AndroidManifest config plugin
│   │   └── withReactNativeArchitectures.js
│   └── app.json                        # Expo configuration
├── server/                             # Go backend (Gin + Gorilla WebSocket)
│   ├── main.go                         # Entry point: Hub, routes, :8080
│   ├── handler/
│   │   ├── hub.go                      # WebSocket client registry + broadcast
│   │   ├── http.go                     # POST /api/data handler
│   │   └── ws.go                       # WebSocket upgrade + read/write pumps
│   ├── model/model.go                  # DataRequest, DataResponse structs
│   ├── Dockerfile                      # Multi-stage: golang:1.25 → alpine:3.20
│   └── go.mod                          # Module: lyrink, Go 1.25
├── widget/                             # KDE Plasma 6 desktop widget (QML)
│   ├── metadata.json                   # Plasma/Applet metadata
│   └── contents/
│       ├── config/main.xml             # KConfig schema (wsUrl default)
│       └── ui/
│           ├── main.qml                # Widget: WebSocket, lyrics fetch, display
│           └── ConfigGeneral.qml       # Settings: WebSocket URL field
└── docker-compose.yml                  # Server deployment
```

## Components Deep Dive

### Android App (`app/`)

The Android app is an Expo SDK 56 project with a custom native module (`expo-media-listener`) written in Kotlin.

**Detection pipeline:**

1. `MediaNotificationListenerService` extends Android's `NotificationListenerService`. It listens for notifications from `com.google.android.apps.youtube.music`.
2. When a YouTube Music notification arrives, the service queries `MediaSessionManager` via an `OnActiveSessionsChangedListener` to get a `MediaController` for accurate playback state (position, duration, play/pause).
3. If no `MediaController` is available (fallback), it extracts metadata directly from notification extras and detects play/pause state from notification action buttons.
4. Album art is extracted as a `Bitmap`, compressed to JPEG (85% quality), and converted to Base64.
5. The `emitIfChanged()` method compares the new metadata against the previous one. If title, artist, isPlaying, or playbackPosition changed, it emits via `MediaEventEmitter`.

**Event bus (`MediaEventEmitter.kt`):**

A singleton Kotlin object with listener lists for metadata changes and listening status. Three consumers subscribe to it:
- `ExpoMediaListenerModule` — forwards events to the JS layer via `sendEvent()`
- `LyrinkForegroundService` — updates its persistent notification with the current song
- `PlaybackStateReporter` — sends HTTP POST to the Go server (only when foreground service is running)

**JS layer (`use-media-metadata.ts`):**

A React hook that manages permissions, starts/stops the native listener, subscribes to metadata events, and exposes `{ metadata, permissionGranted, serviceRunning, toggleService }` to the UI.

**Key files:**

| File | Role |
|------|------|
| `MediaNotificationListenerService.kt` | Core detection: notification interception + MediaSession queries |
| `MediaEventEmitter.kt` | Central event bus + `MediaMetadata` data class (12 fields) |
| `PlaybackStateReporter.kt` | OkHttp POST to `POST /api/data` |
| `LyrinkForegroundService.kt` | Persistent foreground service with song notification |
| `ExpoMediaListenerModule.kt` | Expo module bridge exposing functions to JS |
| `use-media-metadata.ts` | React hook managing permissions, listening, and metadata state |

### Go Server (`server/`)

A minimal stateless relay server built with Gin and Gorilla WebSocket. It does **no data storage or transformation** — it receives JSON via HTTP POST and broadcasts it verbatim to all WebSocket clients.

**Endpoints:**

| Method | Path | Description |
|--------|------|-------------|
| `POST` | `/api/data` | Receives playback state JSON, broadcasts to all WS clients |
| `GET` | `/ws` | WebSocket endpoint for real-time consumers |

**Hub pattern (`handler/hub.go`):**

The `Hub` maintains a set of connected `Client` structs. It runs a goroutine loop that handles client registration, unregistration, and message broadcasting via buffered channels. If a client's send buffer is full, it is disconnected.

**WebSocket lifecycle (`handler/ws.go`):**

- HTTP → WebSocket upgrade (allows all origins)
- `writePump`: sends messages from the `send` channel + periodic pings (54s interval)
- `readPump`: reads pong frames, enforces 60s pong deadline, cleans up on error

**Key files:**

| File | Role |
|------|------|
| `main.go` | Entry point: creates Hub, registers routes, starts on :8080 |
| `handler/hub.go` | Client registry with register/unregister/broadcast channels |
| `handler/http.go` | POST handler: reads body → hub.broadcast |
| `handler/ws.go` | WebSocket upgrade + read/write pumps with keepalive |
| `model/model.go` | `DataRequest` struct matching the Android JSON payload |

### KDE Plasma Widget (`widget/`)

A Plasma 6 desktop widget (QML) that displays real-time synced lyrics for the currently playing track.

**Two representations:**

- **Compact** (system tray): Single label showing current lyric, loading spinner, or "Lyrink" when idle. Click to expand.
- **Full** (expanded panel): Album art, artist/title, lyrics viewport with prev/current/next lines, connection status with restart button.

**WebSocket connection:**

The widget connects to the Go server's WebSocket endpoint (configurable, default `wss://api-lyrink.rakaiseto.com/ws`). It receives the same JSON the Android app posted, parses `title`, `artist`, `albumArtBase64`, `timestamp`, `position`, `duration`, and `isPlaying`. Connection health is monitored with a 5-second timer — if no message arrives for 15 seconds while playing, it forces a reconnect.

**Lyrics fetch and cache:**

When a new track is detected (`title + "|||" + artist` changed), the widget:
1. Checks the local SQLite cache (`QtQuick.LocalStorage`) for previously fetched lyrics
2. On cache miss, fetches from `https://lrclib.net/api/get` with URL-encoded artist, title, and duration
3. Parses LRC format (`[MM:SS.xx] text`) into `{time, text}` objects
4. Saves to cache for future use

**Lyric synchronization:**

A 100ms timer calculates elapsed time as `((Date.now() - deviceTimestamp) + devicePosition) / 1000 - lyricDelay` and walks through the parsed lyrics to find the current line. The display shows three lines (prev/current/next) with a slide animation on lyric change.

**Key files:**

| File | Role |
|------|------|
| `main.qml` | Widget UI: WebSocket client, lyrics fetch/cache/sync, album art display |
| `ConfigGeneral.qml` | Settings page: WebSocket URL text field |
| `contents/config/main.xml` | KConfig schema with default WebSocket URL |
| `metadata.json` | Plasma applet metadata (Plasma 6.0+, GPL-2.0+) |

## Data Flow

### Message format (Android → Server → Widget)

The Android app sends this JSON via HTTP POST. The server broadcasts the same JSON to all WebSocket clients:

```json
{
  "title": "Blinding Lights",
  "artist": "The Weeknd",
  "album": "After Hours",
  "albumArtBase64": "/9j/4AAQSkZJRg...",
  "timestamp": 1719052800000,
  "position": 45230,
  "duration": 200400,
  "isPlaying": true,
  "state": "playing"
}
```

| Field | Type | Description |
|-------|------|-------------|
| `title` | `string` | Song title |
| `artist` | `string` | Artist name |
| `album` | `string` | Album name |
| `albumArtBase64` | `string` | Album art as Base64 JPEG (85% quality) |
| `timestamp` | `number` | Device `Date.now()` in ms when the message was sent |
| `position` | `number` | Playback position in ms at the time of timestamp |
| `duration` | `number` | Total track duration in ms |
| `isPlaying` | `boolean` | Whether playback is active |
| `state` | `string` | `"playing"`, `"paused"`, `"stopped"`, `"buffering"`, or `"none"` |

### Position interpolation

The widget calculates the current elapsed time locally between WebSocket messages:

```
elapsed = ((Date.now() - timestamp) + position) / 1000 - lyricDelay
```

This allows smooth lyric synchronization even when WebSocket messages arrive infrequently. The `lyricDelay` offset (default 0.3s) accounts for network and processing latency.

### When data is sent

The Android app sends a new POST **only when all conditions are met**:
1. The foreground service is running (user tapped "Start" in the UI)
2. The metadata has actually changed (title, artist, isPlaying, or playbackPosition differs from previous)

## Getting Started

### Prerequisites

- Node.js >= 18
- Expo CLI (`npx expo`)
- Android Studio (for Android builds)
- Docker & Docker Compose (for server deployment)
- KDE Plasma 6 (for the desktop widget)

### Android App

```bash
cd app
npm install
npx expo start
npx expo run:android
```

### Server

```bash
# With Docker Compose (recommended)
docker compose up -d

# Or run directly
cd server
go run main.go
```

The server starts on port 8080. Configure the webhook URL in `PlaybackStateReporter.kt` to point to your server instance.

### Widget

The widget requires KDE Plasma 6. Install by placing the `widget/` directory in your Plasma widget directory or through the Plasma widget installer. Configure the WebSocket URL in the widget settings (default: `wss://api-lyrink.rakaiseto.com/ws`).

## Configuration

### Webhook URL

The server endpoint is hardcoded in:
```
app/modules/expo-media-listener/android/src/main/java/expo/modules/medialistener/PlaybackStateReporter.kt
```
```kotlin
private const val WEBHOOK_URL = "https://api-lyrink.rakaiseto.com/api/data"
```

### Widget WebSocket URL

Configurable via the widget settings UI or by editing:
```
widget/contents/config/main.xml
```
Default: `wss://api-lyrink.rakaiseto.com/ws`

### Expo Config Plugin

`plugins/withMediaListener.js` modifies `AndroidManifest.xml` to add:
- **Permissions:** `FOREGROUND_SERVICE`, `POST_NOTIFICATIONS`, `INTERNET`
- **Services:** `MediaNotificationListenerService`, `LyrinkForegroundService`

## Scripts

| Command | Description |
|---------|-------------|
| `npx expo start` | Start Expo dev server |
| `npx expo run:android` | Build & run on Android |
| `npx expo run:ios` | Build & run on iOS (stub) |
| `npx expo start --web` | Web preview |
| `docker compose up -d` | Start Go server with Docker |
| `go run main.go` | Start Go server directly |

## License

MIT

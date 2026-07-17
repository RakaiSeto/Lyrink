# Lyrink — Repository Context

## What It Is

Lyrink is a real-time synced lyrics display system for YouTube Music. It captures playback state from an Android phone and streams it to a KDE Plasma desktop widget that shows time-synced lyrics.

## Architecture

Three components, one data pipeline:

```
Android App (Expo + Kotlin)
    │  NotificationListenerService intercepts YouTube Music
    │  MediaSessionManager queries for playback position
    │  HTTP POST to server on state change
    ▼
Go Server (Gin, :8080)
    │  Stateless relay: POST /api/data → broadcast to WebSocket clients
    │  No storage, no transformation
    ▼
KDE Plasma Widget (QML)
    │  WebSocket client receives playback state
    │  Detects track change (title + "|||" + artist)
    │  Fetches synced lyrics from lrclib.net
    │  Caches in SQLite (QtQuick.LocalStorage)
    │  Syncs display to playback position (100ms timer)
    ▼
Real-time synced lyrics on desktop
```

## Data Model

The core JSON payload (Android → Server → Widget):

```json
{
  "title": "string",
  "artist": "string",
  "album": "string",
  "albumArtBase64": "JPEG base64, 85% quality",
  "timestamp": "Date.now() in ms when sent",
  "position": "playback position in ms",
  "duration": "track duration in ms",
  "isPlaying": "boolean",
  "state": "playing|paused|stopped|buffering|none",
  "pairingCodes": ["optional pairing codes"]
}
```

Position interpolation in widget:
```
elapsed = ((Date.now() - timestamp) + position) / 1000 - lyricDelay
```

## Project Structure

```
├── app/                          # Expo SDK 56 + React Native 19
│   ├── src/
│   │   ├── app/                  # File-based routing (expo-router)
│   │   ├── components/           # UI components (themed, animated)
│   │   ├── hooks/                # use-media-metadata, use-pairing-codes
│   │   └── constants/            # theme.ts
│   ├── modules/
│   │   └── expo-media-listener/  # Custom native module (Kotlin)
│   │       ├── src/              # TypeScript API
│   │       └── android/          # Kotlin implementation
│   └── plugins/                  # Expo config plugins
│
├── server/                       # Go 1.25, Gin, Gorilla WebSocket
│   ├── main.go                   # Entry: Hub, routes, :8080
│   ├── handler/
│   │   ├── hub.go                # Client registry + broadcast
│   │   ├── http.go               # POST /api/data handler
│   │   └── ws.go                 # WebSocket upgrade + pumps
│   ├── model/
│   │   └── model.go              # DataRequest, PairMessage, WSMessage
│   ├── Dockerfile                # Multi-stage: golang:1.25 → alpine:3.20
│   └── go.mod                    # Module: lyrink
│
├── widget/                       # KDE Plasma 6 widget (QML)
│   ├── metadata.json             # Plasma/Applet metadata
│   └── contents/
│       ├── config/main.xml       # KConfig schema (wsUrl)
│       └── ui/
│           ├── main.qml          # Core: WS, lyrics fetch/cache/sync
│           └── ConfigGeneral.qml # Settings page
│
├── docker-compose.yml            # Server deployment (:8080)
└── .github/workflows/release.yml # CI/CD
```

## Key Technical Details

### Android (app/)

- **Detection**: `MediaNotificationListenerService` extends `NotificationListenerService`, listens for `com.google.android.apps.youtube.music` notifications
- **Fallback**: If no `MediaController` available, extracts metadata from notification extras
- **Event bus**: `MediaEventEmitter` singleton — three consumers: JS layer, foreground service, PlaybackStateReporter
- **Reporting**: Only sends POST when foreground service running AND metadata actually changed
- **Album art**: Bitmap → JPEG (85%) → Base64

### Server (server/)

- **Hub pattern**: goroutine-based client registry with register/unregister channels
- **Routing**: `RouteToCodes()` — pairs clients by code, only sends to matching codes
- **WebSocket**: writePump (54s ping), readPump (60s pong deadline), buffered send channel
- **No persistence**: Stateless relay, no database

### Widget (widget/)

- **Two views**: Compact (system tray) and Full (expanded panel with tabs)
- **Pairing**: Generated 8-char alphanumeric code, configurable via settings
- **Lyrics**: LRC format parsed from lrclib.net, cached in SQLite, synced via 100ms timer
- **Connection health**: 5s timer, reconnect if no message for 15s while playing
- **Display**: Three-line view (prev/current/next) with slide animation

## Endpoints

| Method | Path | Description |
|--------|------|-------------|
| POST | /api/data | Receives playback state, broadcasts to WS clients |
| GET | /ws | WebSocket endpoint for consumers |

## Development

```bash
# App
cd app && npm install && npx expo start

# Server
cd server && go run main.go
# or: docker compose up -d

# Widget
# Install to ~/.local/share/plasma/plasmoids/com.github.lyrink.helloworld
# Restart plasmashell
```

## Environment

- **Production server**: `wss://api-lyrink.rakaiseto.com/ws`
- **Default WS port**: 8080
- **Lrclib API**: `https://lrclib.net/api/get`
- **License**: GPL-2.0+ (widget), see README for others

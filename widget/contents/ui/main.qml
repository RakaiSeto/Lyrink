pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtWebSockets
import QtQuick.LocalStorage
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents

PlasmoidItem {
    id: root

    property var lyricsData: []
    property string currentLyric: ""
    property bool isPlaying: false
    property string errorMessage: ""
    property string connectionStatus: "Disconnected"
    property string albumArtBase64: ""
    property string wsUrl: plasmoid.configuration.wsUrl
    property string trackTitle: ""
    property string trackArtist: ""
    property double deviceTimestamp: 0
    property double devicePosition: 0
    property double trackDuration: 0
    property string lastTrackKey: ""
    property double lastMessageTime: 0
    property bool isLoadingLyrics: false
    property string prevLyric: ""
    property string nextLyric: ""
    property double lyricSlideOffset: 0
    property double lyricDelay: 0
    property var db: null
    property var currentXhr: null
    property int lyricsRetryCount: 0
    property string pairingCode: plasmoid.configuration.pairingCode
    property int activeTab: 0

    Component.onCompleted: {
        initDatabase()
        if (root.pairingCode.length === 0) {
            root.pairingCode = generatePairingCode()
            plasmoid.configuration.pairingCode = root.pairingCode
        }
    }

    onWsUrlChanged: {
        reconnectTimer.stop()
        ws.active = false
        ws.active = root.wsUrl.length > 0
    }

    compactRepresentation: Item {
        Layout.preferredWidth: label.implicitWidth
        Layout.preferredHeight: label.implicitHeight

        PlasmaComponents.Label {
            id: label
            opacity: root.isLoadingLyrics && root.isPlaying ? 0 : 1
            anchors.fill: parent
            text: root.isPlaying ? (root.currentLyric.length > 0 ? root.currentLyric : (root.isLoadingLyrics ? "\u27F3" : (root.errorMessage.length > 0 ? "no lyric found for " + root.trackTitle + " by " + root.trackArtist : "\u266A"))) : (root.trackTitle.length > 0 ? root.trackTitle + " (" + root.trackArtist + ") - paused" : "Lyrink")
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        PlasmaComponents.Label {
            id: loadingSpinner
            visible: root.isLoadingLyrics && root.isPlaying
            text: "\u27F3"
            font.pointSize: 14
            anchors.centerIn: parent

            NumberAnimation on rotation {
                from: 0
                to: 360
                duration: 1000
                loops: Animation.Infinite
                running: root.isLoadingLyrics && root.isPlaying
            }
        }

        MouseArea {
            anchors.fill: parent
            property bool wasExpanded: false
            onPressed: wasExpanded = root.expanded
            onClicked: root.expanded = !wasExpanded
        }
    }

    fullRepresentation: ColumnLayout {
        Layout.minimumWidth: 320
        Layout.minimumHeight: 0
        spacing: 8

        PlasmaComponents.TabBar {
            id: tabBar
            Layout.fillWidth: true
            currentIndex: root.activeTab
            onCurrentIndexChanged: root.activeTab = currentIndex

            PlasmaComponents.TabButton {
                text: "Lyrics"
            }
            PlasmaComponents.TabButton {
                text: "Pairing"
            }
        }

        StackLayout {
            currentIndex: tabBar.currentIndex
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                spacing: 8

                RowLayout {
                    Layout.fillWidth: true

                    Rectangle {
                        width: 8
                        height: 8
                        radius: 4
                        color: root.connectionStatus === "Connected" ? "#2ecc71" :
                               root.connectionStatus === "Reconnecting..." ? "#f39c12" : "#e74c3c"
                    }

                    PlasmaComponents.Label {
                        text: root.connectionStatus
                        font.pointSize: 8
                        opacity: 0.6
                    }

                    PlasmaComponents.ToolButton {
                        icon.name: "view-refresh"
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        onClicked: {
                            ws.active = false
                            ws.active = root.wsUrl.length > 0
                        }
                    }

                    PlasmaComponents.ToolButton {
                        id: cacheButton
                        icon.name: "edit-delete"
                        Layout.preferredWidth: 24
                        Layout.preferredHeight: 24
                        onClicked: cacheMenu.open(cacheButton)

                        PlasmaComponents.Menu {
                            id: cacheMenu
                            PlasmaComponents.MenuItem {
                                text: "Clear Current Song"
                                onClicked: clearCurrentSongCache()
                            }
                            PlasmaComponents.MenuItem {
                                text: "Clear All Cache"
                                onClicked: clearLyricsCache()
                            }
                        }
                    }

                    Item {
                        Layout.fillWidth: true
                    }
                }

                Image {
                    source: root.albumArtBase64.length > 0 ? getAlbumArtSource(root.albumArtBase64) : ""
                    Layout.preferredWidth: 200
                    Layout.preferredHeight: 200
                    Layout.alignment: Qt.AlignHCenter
                    fillMode: Image.PreserveAspectFit
                    visible: root.albumArtBase64.length > 0
                }
        }

                PlasmaComponents.Label {
                    text: root.trackArtist
                    font.pointSize: 10
                    opacity: 0.7
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                PlasmaComponents.Label {
                    text: root.trackTitle
                    font.pointSize: 14
                    font.bold: true
                    wrapMode: Text.WordWrap
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                    Layout.leftMargin: 8
                    Layout.rightMargin: 8
                }

                Item {
                    id: lyricsViewport
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 120
                    clip: true

                    PlasmaComponents.Label {
                        id: lyricsErrorLabel
                        text: "Lyric not found"
                        visible: root.errorMessage.length > 0 && root.currentLyric.length === 0
                        opacity: 0.6
                        font.pointSize: 14
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    PlasmaComponents.Label {
                        text: "\u21BB Tap to retry"
                        visible: root.errorMessage.length > 0 && root.currentLyric.length === 0
                        opacity: 0.4
                        font.pointSize: 9
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: lyricsErrorLabel.bottom
                        anchors.topMargin: 8

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.errorMessage = ""
                                root.lyricsRetryCount = 0
                                root.isLoadingLyrics = true
                                fetchLyrics()
                            }
                        }
                    }

                    PlasmaComponents.Label {
                        text: "Fetching lyrics..."
                        visible: root.isLoadingLyrics && root.currentLyric.length === 0
                        opacity: 0.6
                        font.pointSize: 14
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    PlasmaComponents.Label {
                        text: "\u266A"
                        visible: root.lyricsData.length > 0 && root.currentLyric.length === 0 && !root.isLoadingLyrics && root.errorMessage.length === 0
                        opacity: 0.6
                        font.pointSize: 24
                        horizontalAlignment: Text.AlignHCenter
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    Column {
                        id: lyricsColumn
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: parent.height / 2 - implicitHeight / 2 + root.lyricSlideOffset
                        spacing: 8

                        Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }

                        PlasmaComponents.Label {
                            text: root.prevLyric
                            visible: root.prevLyric.length > 0
                            opacity: 0.4
                            font.pointSize: 10
                            horizontalAlignment: Text.AlignHCenter
                            width: lyricsViewport.width
                            wrapMode: Text.WordWrap
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }
                        PlasmaComponents.Label {
                            text: root.currentLyric
                            visible: root.currentLyric.length > 0
                            opacity: 1.0
                            font.pointSize: 14
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                            width: lyricsViewport.width
                            wrapMode: Text.WordWrap
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }

                        PlasmaComponents.Label {
                            text: root.nextLyric
                            visible: root.nextLyric.length > 0
                            opacity: 0.4
                            font.pointSize: 10
                            horizontalAlignment: Text.AlignHCenter
                            width: lyricsViewport.width
                            wrapMode: Text.WordWrap
                            Behavior on opacity { NumberAnimation { duration: 200 } }
                        }
                    }
                }
            }

            ColumnLayout {
                spacing: 8

                Item { Layout.fillHeight: true }

                PlasmaComponents.Label {
                    text: "Pairing Code"
                    font.pointSize: 12
                    font.bold: true
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                Rectangle {
                    Layout.preferredWidth: codeLabel.implicitWidth + 48
                    Layout.preferredHeight: codeLabel.implicitHeight + 24
                    Layout.alignment: Qt.AlignHCenter
                    radius: 8
                    color: "#2ecc71"
                    border.width: 2
                    border.color: "#27ae60"

                    PlasmaComponents.Label {
                        id: codeLabel
                        anchors.centerIn: parent
                        text: root.pairingCode
                        font.pointSize: 24
                        font.bold: true
                        font.family: "monospace"
                        color: "#ffffff"
                        font.letterSpacing: 4
                    }
                }

                PlasmaComponents.Label {
                    text: "Enter this code in the\nLyrink app to pair"
                    font.pointSize: 10
                    opacity: 0.7
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                PlasmaComponents.Label {
                    text: "Code is fixed and never changes"
                    font.pointSize: 8
                    opacity: 0.4
                    horizontalAlignment: Text.AlignHCenter
                    Layout.fillWidth: true
                }

                Item { Layout.fillHeight: true }
            }
        }
    }

    WebSocket {
        id: ws
        url: root.wsUrl
        active: root.wsUrl.length > 0

        onStatusChanged: {
            switch (ws.status) {
            case WebSocket.Connecting:
                root.connectionStatus = "Connecting..."
                break
            case WebSocket.Open:
                root.connectionStatus = "Connected"
                root.lastMessageTime = Date.now()
                reconnectTimer.stop()
                sendPairMessage()
                break
            case WebSocket.Closing:
                root.connectionStatus = "Disconnecting..."
                break
            case WebSocket.Closed:
                root.connectionStatus = "Reconnecting..."
                reconnectTimer.start()
                break
            case WebSocket.Error:
                root.connectionStatus = "Reconnecting..."
                reconnectTimer.start()
                break
            }
        }

        onTextMessageReceived: function(message) {
            root.lastMessageTime = Date.now()
            reconnectTimer.stop()
            try {
                var json = JSON.parse(message)
                if (json.albumArtBase64) {
                    root.albumArtBase64 = json.albumArtBase64
                }
                if (json.title !== undefined) {
                    root.trackTitle = json.title
                }
                if (json.artist !== undefined) {
                    root.trackArtist = json.artist
                }
                if (json.timestamp !== undefined) {
                    root.deviceTimestamp = json.timestamp
                }
                if (json.position !== undefined) {
                    root.devicePosition = json.position
                }
                if (json.duration !== undefined) {
                    root.trackDuration = json.duration
                }
                if (json.isPlaying !== undefined) {
                    root.isPlaying = json.isPlaying
                }
                if (root.isPlaying) {
                    lyricTimer.start()
                } else {
                    lyricTimer.stop()
                }
                var trackKey = root.trackTitle + "|||" + root.trackArtist
                if (trackKey !== root.lastTrackKey && root.trackTitle.length > 0 && root.trackArtist.length > 0) {
                    root.lastTrackKey = trackKey
                    root.lyricsData = []
                    root.currentLyric = ""
                    root.prevLyric = ""
                    root.nextLyric = ""
                    root.errorMessage = ""
                    root.lyricsRetryCount = 0
                    lyricsRetryTimer.stop()
                    root.isLoadingLyrics = true
                    fetchLyrics()
                }
            } catch (e) {
                console.warn("WebSocket parse error:", e.message)
            }
        }
    }

    Timer {
        id: reconnectTimer
        interval: 3000
        running: false
        repeat: false
        onTriggered: {
            ws.active = false
            ws.active = root.wsUrl.length > 0
        }
    }

    Timer {
        id: lyricTimer
        interval: 100
        running: false
        repeat: true
        onTriggered: updateCurrentLyric()
    }

    Timer {
        id: lyricsRetryTimer
        interval: 1500
        running: false
        repeat: false
        onTriggered: fetchLyrics()
    }

    Timer {
        id: connectionHealthTimer
        interval: 5000
        running: root.isPlaying
        repeat: true
        onTriggered: {
            if (root.connectionStatus === "Connected" && Date.now() - root.lastMessageTime > 15000) {
                root.connectionStatus = "Reconnecting..."
                ws.active = false
                ws.active = root.wsUrl.length > 0
            }
        }
    }

    Timer {
        id: lyricSlideResetTimer
        interval: 50
        onTriggered: root.lyricSlideOffset = 0
    }

    function generatePairingCode() {
        var code = ""
        for (var i = 0; i < 6; i++) {
            code += Math.floor(Math.random() * 10).toString()
        }
        return code
    }

    function sendPairMessage() {
        if (ws.status === WebSocket.Open && root.pairingCode.length > 0) {
            ws.sendTextMessage('{"type":"pair","code":"' + root.pairingCode + '"}')
        }
    }

    function getAlbumArtSource(base64) {
        if (base64.length === 0) return ""

        var prefix = ""
        if (base64.charAt(0) === '/' && base64.charAt(1) === '9' && base64.charAt(2) === 'j') {
            prefix = "data:image/jpeg;base64,"
        } else if (base64.startsWith("iVBOR")) {
            prefix = "data:image/png;base64,"
        } else if (base64.startsWith("UklGR")) {
            prefix = "data:image/webp;base64,"
        } else {
            prefix = "data:image/jpeg;base64,"
        }
        return prefix + base64
    }

    function fetchLyrics() {
        if (currentXhr) {
            currentXhr.abort()
            currentXhr = null
        }

        var trackKey = trackTitle + "|||" + trackArtist
        var cached = getCachedLyrics(trackKey)
        if (cached) {
            root.isLoadingLyrics = false
            lyricsData = parseSyncedLyrics(cached)
            return
        }

        var artist = formatUrlParam(trackArtist)
        var title = formatUrlParam(trackTitle)
        var url = "https://lrclib.net/api/search?artist_name=" + artist + "&track_name=" + title
        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                root.currentXhr = null
                var currentTrackKey = root.trackTitle + "|||" + root.trackArtist
                if (currentTrackKey !== trackKey) return
                root.isLoadingLyrics = false
                if (xhr.status === 200) {
                    try {
                        var results = JSON.parse(xhr.responseText)
                        var found = false
                        var bestMatch = null
                        var bestDiff = Infinity

                        for (var i = 0; i < results.length; i++) {
                            if (results[i].syncedLyrics) {
                                var resultDuration = results[i].duration * 1000
                                var diff = Math.abs(resultDuration - root.trackDuration)
                                if (diff < bestDiff) {
                                    bestDiff = diff
                                    bestMatch = results[i]
                                }
                            }
                        }

                        if (bestMatch) {
                            saveCachedLyrics(trackKey, bestMatch.syncedLyrics)
                            lyricsData = parseSyncedLyrics(bestMatch.syncedLyrics)
                            found = true
                        }

                        if (!found) {
                            if (root.lyricsRetryCount < 2) {
                                root.lyricsRetryCount++
                                root.isLoadingLyrics = true
                                lyricsRetryTimer.start()
                            } else {
                                errorMessage = "No synced lyrics available"
                                root.lyricsRetryCount = 0
                            }
                        } else {
                            root.lyricsRetryCount = 0
                        }
                    } catch (e) {
                        if (root.lyricsRetryCount < 2) {
                            root.lyricsRetryCount++
                            root.isLoadingLyrics = true
                            lyricsRetryTimer.start()
                        } else {
                            errorMessage = "Failed to parse lyrics data"
                            root.lyricsRetryCount = 0
                        }
                    }
                } else {
                    if (root.lyricsRetryCount < 2) {
                        root.lyricsRetryCount++
                        root.isLoadingLyrics = true
                        lyricsRetryTimer.start()
                    } else {
                        errorMessage = "Failed to fetch lyrics (HTTP " + xhr.status + ")"
                        root.lyricsRetryCount = 0
                    }
                }
            }
        }
        currentXhr = xhr
        xhr.send()
    }

    function parseSyncedLyrics(lyrics) {
        var lines = lyrics.split("\n")
        var result = []
        for (var i = 0; i < lines.length; i++) {
            var match = lines[i].match(/\[(\d{2}):(\d{2})\.(\d{2})\]\s*(.*)/)
            if (match) {
                var minutes = parseInt(match[1])
                var seconds = parseInt(match[2])
                var hundredths = parseInt(match[3])
                var time = minutes * 60 + seconds + hundredths / 100
                result.push({time: time, text: match[4]})
            }
        }
        return result
    }

    function formatUrlParam(text) {
        return encodeURIComponent(text.trim())
    }

    function initDatabase() {
        db = LocalStorage.openDatabaseSync("LyrinkLyrics", "1.0", "Lyrics cache for Lyrink widget", 1048576)
        db.transaction(function(tx) {
            tx.executeSql("CREATE TABLE IF NOT EXISTS lyrics_cache (track_key TEXT PRIMARY KEY, synced_lyrics TEXT NOT NULL, fetched_at INTEGER NOT NULL)")
        })
    }

    function getCachedLyrics(trackKey) {
        if (!db) return null
        var result = null
        db.transaction(function(tx) {
            var rs = tx.executeSql("SELECT synced_lyrics FROM lyrics_cache WHERE track_key = ?", [trackKey])
            if (rs.rows.length > 0) {
                result = rs.rows.item(0).synced_lyrics
            }
        })
        return result
    }

    function saveCachedLyrics(trackKey, syncedLyrics) {
        if (!db) return
        db.transaction(function(tx) {
            tx.executeSql("INSERT OR REPLACE INTO lyrics_cache (track_key, synced_lyrics, fetched_at) VALUES (?, ?, ?)",
                [trackKey, syncedLyrics, Date.now()])
        })
    }

    function clearLyricsCache() {
        if (!db) return
        db.transaction(function(tx) {
            tx.executeSql("DELETE FROM lyrics_cache")
        })
        lyricsData = []
        currentLyric = ""
    }

    function clearCurrentSongCache() {
        if (!db || !lastTrackKey) return
        db.transaction(function(tx) {
            tx.executeSql("DELETE FROM lyrics_cache WHERE track_key = ?", [lastTrackKey])
        })
        lyricsData = []
        currentLyric = ""
    }

    function updateCurrentLyric() {
        if (lyricsData.length === 0) return
        if (!isPlaying) return

        var elapsed = ((Date.now() - deviceTimestamp) + devicePosition) / 1000 - root.lyricDelay
        if (elapsed < 0) elapsed = 0

        var currentIndex = -1

        for (var i = 0; i < lyricsData.length; i++) {
            if (lyricsData[i].time <= elapsed) {
                if (lyricsData[i].text.length > 0) {
                    currentIndex = i
                }
            } else {
                break
            }
        }

        if (currentIndex >= 0) {
            var newPrev = currentIndex > 0 ? lyricsData[currentIndex - 1].text : ""
            var newCurrent = lyricsData[currentIndex].text
            var newNext = currentIndex < lyricsData.length - 1 ? lyricsData[currentIndex + 1].text : ""

            if (newCurrent !== currentLyric && currentLyric.length > 0) {
                root.lyricSlideOffset = 15
                lyricSlideResetTimer.start()
            }

            prevLyric = newPrev
            currentLyric = newCurrent
            nextLyric = newNext
        }
    }
}

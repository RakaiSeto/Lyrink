pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtWebSockets
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
            text: root.currentLyric.length > 0 ? root.currentLyric : (root.isPlaying ? "\u266A" : "Lyrink")
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

        PlasmaComponents.Label {
            text: root.trackArtist
            font.pointSize: 10
            opacity: 0.7
        }

        PlasmaComponents.Label {
            text: root.trackTitle
            font.pointSize: 14
            font.bold: true
        }

        Item {
            Layout.fillHeight: true
        }

        PlasmaComponents.Label {
            id: statusLabel
            text: root.errorMessage
            visible: root.errorMessage.length > 0
            color: "#e74c3c"
        }

        Item {
            id: lyricsViewport
            Layout.fillWidth: true
            Layout.preferredHeight: 120
            clip: true

            Column {
                id: lyricsColumn
                anchors.horizontalCenter: parent.horizontalCenter
                y: parent.height / 2 - implicitHeight / 2 + root.lyricSlideOffset
                spacing: 8

                Behavior on y { NumberAnimation { duration: 300; easing.type: Easing.InOutQuad } }

                PlasmaComponents.Label {
                    text: root.prevLyric
                    visible: root.isPlaying && root.prevLyric.length > 0
                    opacity: 0.4
                    font.pointSize: 10
                    horizontalAlignment: Text.AlignHCenter
                    width: lyricsViewport.width
                    wrapMode: Text.WordWrap
                    Behavior on opacity { NumberAnimation { duration: 200 } }
                }

                PlasmaComponents.Label {
                    text: root.currentLyric
                    visible: root.isPlaying && root.currentLyric.length > 0
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
                    visible: root.isPlaying && root.nextLyric.length > 0
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
                    root.errorMessage = ""
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
        var artist = formatUrlParam(trackArtist)
        var title = formatUrlParam(trackTitle)
        var duration = Math.round(trackDuration / 1000)
        var url = "https://lrclib.net/api/get?artist_name=" + artist + "&track_name=" + title + "&duration=" + duration
        var xhr = new XMLHttpRequest()
        xhr.open("GET", url)
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
                root.isLoadingLyrics = false
                if (xhr.status === 200) {
                    try {
                        var data = JSON.parse(xhr.responseText)
                        if (data.syncedLyrics) {
                            lyricsData = parseSyncedLyrics(data.syncedLyrics)
                        } else {
                            errorMessage = "No synced lyrics available"
                        }
                    } catch (e) {
                        errorMessage = "Failed to parse lyrics data"
                    }
                } else {
                    errorMessage = "Failed to fetch lyrics (HTTP " + xhr.status + ")"
                }
            }
        }
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
        return text.trim().replace(/\s+/g, "+")
    }

    function updateCurrentLyric() {
        if (lyricsData.length === 0) return
        if (!isPlaying) return

        var elapsed = ((Date.now() - deviceTimestamp) + devicePosition) / 1000
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

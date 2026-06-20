pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents

PlasmoidItem {
    id: root

    property var lyricsData: []
    property string currentLyric: ""
    property bool isPlaying: false
    property double startTime: 0
    property string errorMessage: ""

    compactRepresentation: Item {
        Layout.preferredWidth: label.implicitWidth
        Layout.preferredHeight: label.implicitHeight

        PlasmaComponents.Label {
            id: label
            anchors.fill: parent
            text: root.currentLyric.length > 0 ? root.currentLyric : (root.isPlaying ? "\u266A" : "Lyrink")
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
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
        Layout.minimumHeight: 240
        spacing: 8

        PlasmaComponents.Label {
            text: "The Weeknd"
            font.pointSize: 10
            opacity: 0.7
        }

        PlasmaComponents.Label {
            text: "Less Than Zero"
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

        PlasmaComponents.Label {
            id: currentLyricLabel
            text: root.currentLyric
            visible: root.isPlaying && root.currentLyric.length > 0
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
        }

        PlasmaComponents.Button {
            id: startButton
            text: root.isPlaying ? "Stop" : "Start"
            onClicked: {
                if (root.isPlaying) {
                    stopPlayback()
                } else {
                    startPlayback()
                }
            }
        }
    }

    Timer {
        id: lyricTimer
        interval: 100
        running: false
        repeat: true
        onTriggered: updateCurrentLyric()
    }

    function startPlayback() {
        currentLyric = ""
        errorMessage = ""
        lyricsData = []
        startTime = Date.now()
        isPlaying = true
        lyricTimer.start()
        fetchLyrics()
    }

    function stopPlayback() {
        isPlaying = false
        lyricTimer.stop()
        currentLyric = ""
        lyricsData = []
    }

    function fetchLyrics() {
        var xhr = new XMLHttpRequest()
        xhr.open("GET", "https://lrclib.net/api/get?artist_name=The+Weeknd&track_name=Less+Than+Zero&duration=212")
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4) {
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

    function updateCurrentLyric() {
        if (lyricsData.length === 0) return

        var elapsed = (Date.now() - startTime) / 1000
        var found = ""

        for (var i = 0; i < lyricsData.length; i++) {
            if (lyricsData[i].time <= elapsed) {
                if (lyricsData[i].text.length > 0) {
                    found = lyricsData[i].text
                }
            } else {
                break
            }
        }

        currentLyric = found

        var lastLyricTime = lyricsData[lyricsData.length - 1].time
        if (elapsed > lastLyricTime + 5) {
            stopPlayback()
        }
    }
}

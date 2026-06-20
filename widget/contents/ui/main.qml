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
    property string trackTitle: ""
    property string trackArtist: ""
    property double trackDuration: 0
    property bool isLoadingLyrics: false
    property string prevLyric: ""
    property string nextLyric: ""
    property double lyricSlideOffset: 0

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
        Layout.minimumHeight: 240
        spacing: 8

        PlasmaComponents.Label {
            text: root.trackArtist.length > 0 ? root.trackArtist : "Artist"
            font.pointSize: 10
            opacity: 0.7
        }

        PlasmaComponents.Label {
            text: root.trackTitle.length > 0 ? root.trackTitle : "Title"
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

    Timer {
        id: lyricSlideResetTimer
        interval: 50
        onTriggered: root.lyricSlideOffset = 0
    }

    function startPlayback() {
        currentLyric = ""
        errorMessage = ""
        lyricsData = []
        startTime = Date.now()
        isPlaying = true
        trackTitle = "Less Than Zero"
        trackArtist = "The Weeknd"
        trackDuration = 212000
        isLoadingLyrics = true
        lyricTimer.start()
        fetchLyrics()
    }

    function stopPlayback() {
        isPlaying = false
        lyricTimer.stop()
        currentLyric = ""
        lyricsData = []
        isLoadingLyrics = false
        prevLyric = ""
        nextLyric = ""
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

        var elapsed = (Date.now() - startTime) / 1000
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

        var lastLyricTime = lyricsData[lyricsData.length - 1].time
        if (elapsed > lastLyricTime + 5) {
            stopPlayback()
        }
    }
}

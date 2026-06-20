import QtQuick
import QtQuick.Controls as QQC2
import org.kde.kirigami as Kirigami

Kirigami.FormLayout {
    id: page

    QQC2.TextField {
        id: wsUrlField
        Kirigami.FormData.label: "WebSocket URL:"
        text: plasmoid.configuration.wsUrl
        placeholderText: "wss://api-lyrink.rakaiseto.com/ws"

        onEditingFinished: {
            if (text.trim().length > 0) {
                plasmoid.configuration.wsUrl = text.trim()
            }
        }
    }
}

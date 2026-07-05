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

    QQC2.TextField {
        id: pairingCodeField
        Kirigami.FormData.label: "Pairing Code:"
        text: plasmoid.configuration.pairingCode
        readOnly: true
        selectByMouse: true
        font.family: "monospace"
        font.pointSize: 14

        background: Rectangle {
            radius: 4
            color: pairingCodeField.readOnly ? "#f0f0f0" : "#ffffff"
            border.width: 1
            border.color: pairingCodeField.readOnly ? "#cccccc" : "#208AEF"
        }
    }

    Kirigami.InlineMessage {
        type: Kirigami.InlineMessage.Information
        text: "This code is generated once and cannot be changed. Enter it in the Lyrink app to pair."
        Layout.fillWidth: true
    }
}

import QtQuick
import ".."

/// Placeholder for the keybinds editor tab — "coming soon".
Item {
    id: root
    width: parent ? parent.width : 400
    height: placeholderCol.height

    Column {
        id: placeholderCol
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: 12
        topPadding: 48
        bottomPadding: 48

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "keybinds"
            color: Theme.text3
            font.family: Theme.sansFont
            font.pixelSize: 16
            font.weight: Font.DemiBold
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "coming soon"
            color: Theme.text4
            font.family: Theme.monoFont
            font.pixelSize: 12
        }
    }
}

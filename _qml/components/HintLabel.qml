import QtQuick
import ".."

/// Keyboard-hint footer pill shown below overlays.
///
/// Usage:
///   HintLabel { text: "Esc close  ·  ↑↓ navigate  ·  ↵ run" }
Rectangle {
    id: root

    property string text: ""

    width: _t.width + 16
    height: _t.height + 8
    radius: 3
    color: Theme.base
    border.color: Theme.borderSub
    border.width: 1

    Text {
        id: _t
        anchors.centerIn: parent
        text: root.text
        color: Theme.text3
        font.family: Theme.monoFont
        font.pixelSize: 11
    }
}

import QtQuick
import ".."

/// A labelled action button.
///
/// Usage:
///   GButton { label: "Save"; onClicked: doSave() }
///   GButton { label: "Delete"; danger: true; onClicked: doDelete() }
///   GButton { label: "Apply"; active: isActive; onClicked: doApply() }
///
/// Variants:
///   danger: true  — urgent border on hover
///   active: true  — accent fill (primary/confirm action)
Rectangle {
    id: root

    property string label: ""
    property bool danger: false
    property bool active: false
    signal clicked()

    width: _label.width + 24
    height: 28
    radius: 2
    color: root.active
        ? Theme.accent
        : (area.containsMouse ? Theme.baseRaised : Theme.base)
    border.color: (area.containsMouse && root.danger) ? Theme.urgent : Theme.border
    border.width: 1

    Text {
        id: _label
        anchors.centerIn: parent
        text: root.label
        color: root.active ? Theme.baseDeep : Theme.text2
        font.family: Theme.monoFont
        font.pixelSize: 12
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: root.clicked()
    }
}

import QtQuick
import ".."

/// Single row in any result or channel list.
///
/// Usage:
///   ResultItem {
///       primary:   "research"
///       secondary: "[channel]"
///       selected:  listView.currentIndex === index
///       onActivated: listView.currentIndex = index
///   }
Item {
    id: root

    property string primary: ""
    property string secondary: ""
    property bool selected: false
    signal activated()

    width: parent.width
    height: 28

    Rectangle {
        anchors.fill: parent
        color: root.selected ? Theme.baseHl : (area.containsMouse ? Theme.baseRaised : "transparent")
    }

    // Selected left bar.
    Rectangle {
        width: 2
        height: parent.height
        color: root.selected ? Theme.accent : "transparent"
    }

    Text {
        anchors.left: parent.left
        anchors.leftMargin: 10
        anchors.right: _secondary.left
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: root.primary
        color: Theme.text1
        font.family: Theme.monoFont
        font.pixelSize: 12
        elide: Text.ElideRight
    }

    Text {
        id: _secondary
        anchors.right: parent.right
        anchors.rightMargin: 10
        anchors.verticalCenter: parent.verticalCenter
        text: root.secondary
        color: Theme.text3
        font.family: Theme.monoFont
        font.pixelSize: 11
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        onClicked: root.activated()
    }
}

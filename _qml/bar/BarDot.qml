import QtQuick
import ".."
import "../compositor"
import "../services"

/// Inactive channel dot indicator.
///
/// Shows a small dot for each workspace that is not currently active.
/// Occupied workspaces (with windows) are brighter. Hovering expands
/// to show the workspace name. Clicking switches to that workspace.
Item {
    id: root

    /// Workspace data: { name, columnCount, active }
    required property var workspace

    // Hide the active workspace (BarChannel shows it instead).
    visible: !workspace.active

    implicitWidth: hovered ? expandedRow.implicitWidth + 12 : 8
    implicitHeight: parent ? parent.height : ModeService.standardHeight

    property bool hovered: mouseArea.containsMouse

    Behavior on implicitWidth {
        NumberAnimation { duration: 120; easing.type: Easing.OutCubic }
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: CompositorService.focusWorkspace(root.workspace.name)
    }

    // Dot (default state).
    Rectangle {
        id: dot
        anchors.centerIn: parent
        width: 5
        height: 5
        radius: 2.5
        color: root.workspace.columnCount > 0 ? Theme.text3 : Theme.borderSub
        visible: !root.hovered
    }

    // Expanded name (hover state).
    Row {
        id: expandedRow
        anchors.centerIn: parent
        spacing: 4
        visible: root.hovered

        Text {
            text: root.workspace.name
            color: Theme.text2
            font.family: Theme.sansFont
            font.pixelSize: 11
        }
    }
}

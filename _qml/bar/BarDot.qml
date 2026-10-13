import QtQuick
import ".."
import "../compositor"

/// Channel dot for one workspace on the bar's output.
///
/// Every workspace on the output gets a dot, in the output's own order,
/// so positions are stable as focus moves (the active channel's name
/// and pages follow the strip in BarChannel). Click focuses; hover
/// shows the name after the tooltip delay.
///
///   visible workspace — filled text-1 (text-2 on an unfocused output)
///   occupied          — filled text-3
///   empty             — filled border-sub
///   unnamed + empty   — hollow ring (niri's trailing "new" workspace),
///                       ring brightened when visible
///   urgent            — urgent, overriding the above
Item {
    id: root

    /// Workspace entry from CompositorService.
    required property var workspace

    /// Whether the bar's output holds keyboard focus.
    property bool outputFocused: false

    /// The owning bar's BarTooltip.
    property var tip: null

    readonly property bool _hollow: !root.workspace.name && root.workspace.windowCount === 0

    implicitWidth: 13
    implicitHeight: parent ? parent.height : 30

    Rectangle {
        anchors.centerIn: parent
        width: 5
        height: 5
        radius: 2.5
        color: root._hollow ? "transparent" : root._color()
        border.width: root._hollow ? 1 : 0
        border.color: area.containsMouse ? Theme.text1
            : root.workspace.active ? (root.outputFocused ? Theme.text1 : Theme.text2)
            : Theme.borderSub
    }

    function _color(): color {
        const ws = root.workspace;
        if (ws.urgent) return Theme.urgent;
        if (area.containsMouse) return Theme.text1;
        if (ws.active) return root.outputFocused ? Theme.text1 : Theme.text2;
        if (ws.windowCount > 0) return Theme.text3;
        return Theme.borderSub;
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: CompositorService.focusWorkspaceEntry(root.workspace)
        onContainsMouseChanged: {
            if (containsMouse) tipDelay.restart();
            else {
                tipDelay.stop();
                if (root.tip) root.tip.hide(root);
            }
        }
    }

    Timer {
        id: tipDelay
        interval: 400
        onTriggered: {
            if (!root.tip) return;
            const ws = root.workspace;
            const n = ws.windowCount;
            const name = ws.name
                || (n > 0 ? "workspace " + ws.idx : "new workspace");
            root.tip.show(root, n > 0
                ? name + " \u2022 " + n + (n === 1 ? " window" : " windows")
                : name);
        }
    }
}

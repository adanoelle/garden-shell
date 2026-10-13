import QtQuick
import ".."

/// One text slot in the bar — the bar's single interaction vocabulary.
///
/// Full bar height hit target (no 5 px click targets). Interactive
/// slots get a base-hl chip on hover and a pointer cursor; any slot
/// with `tooltip` text shows it after the spec's 400 ms delay.
///
/// Ambient slots (`ambient: true`) rest at text-4 and brighten to
/// `activeColor` for 1.5 s when `pulse()` is called — the volume and
/// brightness indicators. `_displayColor` is an intermediate property
/// so the two ColorAnimations don't fight the binding system.
Item {
    id: root

    property string text: ""
    property color color: Theme.text3
    property string fontFamily: Theme.monoFont
    property int fontSize: Theme.fontMeta
    property bool bold: false

    /// Tooltip text; empty = none.
    property string tooltip: ""

    /// The owning bar's BarTooltip.
    property var tip: null

    /// Clickable / scrollable: hover chip + pointer cursor.
    property bool interactive: false

    /// Persistent base-hl chip (the active page).
    property bool selected: false

    /// 1 px accent underline on the chip (the keyboard-focused page).
    property bool marked: false

    /// Horizontal padding inside the hit target.
    property int padding: 6

    /// Max label width before eliding (0 = unbounded).
    property int maxTextWidth: 0

    // Ambient behaviour.
    property bool ambient: false
    property color activeColor: Theme.text1
    property color _displayColor: Theme.text4

    /// Optional leading item (e.g. a status dot) placed before the text.
    default property alias leading: leadingRow.data

    signal clicked(var mouse)
    signal scrolled(int steps)

    readonly property bool hovered: area.containsMouse

    implicitWidth: contentRow.implicitWidth + root.padding * 2
    implicitHeight: parent ? parent.height : 30

    function pulse() {
        holdTimer.restart();
        toDim.stop();
        toActive.start();
    }

    Rectangle {
        anchors.fill: parent
        anchors.topMargin: 5
        anchors.bottomMargin: 5
        color: root.selected || (root.interactive && root.hovered)
            ? Theme.baseHl : "transparent"

        Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: 1
            color: Theme.accent
            visible: root.marked
        }
    }

    Row {
        id: contentRow
        anchors.centerIn: parent
        spacing: 5

        Row {
            id: leadingRow
            anchors.verticalCenter: parent.verticalCenter
            spacing: 5
            visible: children.length > 0
        }

        Text {
            id: label
            anchors.verticalCenter: parent.verticalCenter
            width: root.maxTextWidth > 0
                ? Math.min(implicitWidth, root.maxTextWidth) : implicitWidth
            elide: Text.ElideRight
            text: root.text
            color: root.ambient ? root._displayColor : root.color
            font.family: root.fontFamily
            font.pixelSize: root.fontSize
            font.weight: root.bold ? Font.DemiBold : Font.Normal
        }
    }

    MouseArea {
        id: area
        anchors.fill: parent
        hoverEnabled: true
        acceptedButtons: root.interactive
            ? (Qt.LeftButton | Qt.RightButton | Qt.MiddleButton) : Qt.NoButton
        cursorShape: root.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor

        onClicked: mouse => root.clicked(mouse)
        onWheel: wheel => {
            const steps = wheel.angleDelta.y / 120;
            if (steps !== 0) root.scrolled(steps > 0 ? Math.ceil(steps) : Math.floor(steps));
        }
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
        onTriggered: if (root.tip && root.tooltip) root.tip.show(root, root.tooltip)
    }

    // Keep an open tooltip current (e.g. volume changes under the cursor).
    onTooltipChanged: {
        if (root.tip && root.tip._target === root) {
            if (root.tooltip) root.tip.show(root, root.tooltip);
            else root.tip.hide(root);
        }
    }

    // ── Ambient brighten / dim ──────────────────────────────────────

    ColorAnimation {
        id: toActive
        target: root
        property: "_displayColor"
        to: root.activeColor
        duration: Theme.motionFast
        easing.type: Easing.OutCubic
    }

    ColorAnimation {
        id: toDim
        target: root
        property: "_displayColor"
        to: Theme.text4
        duration: Theme.motionBase
        easing.type: Easing.InCubic
    }

    Timer {
        id: holdTimer
        interval: 1500
        onTriggered: toDim.start()
    }
}

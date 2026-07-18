import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../services"

/// Volume/brightness OSD (02-shell-design.md §10).
///
/// Non-modal window (PanelWindow, WlrLayer.Overlay, no keyboard focus,
/// no exclusive zone) — follows the NotificationPopups pattern, not
/// OverlayBase. One component serves both volume and brightness;
/// retargets on collision (most recent wins, no stacking).
///
/// 280×28 px, centered bottom, mono label + 4 px progress bar,
/// 1.5 s auto-dismiss. Muted: "muted" in text-4, empty bar.
PanelWindow {
    id: root

    // ── Geometry ────────────────────────────────────────────────────

    readonly property int osdWidth: 280
    readonly property int osdHeight: 28
    readonly property int edgeMargin: 16

    // ── State ───────────────────────────────────────────────────────

    /// What the OSD is currently showing: "volume" or "brightness".
    property string _source: "volume"

    /// 0.0–1.0 progress value.
    property real _value: 0

    /// Whether the source is muted (brightness is never muted).
    property bool _muted: false

    property bool _showing: false

    // ── Triggers ────────────────────────────────────────────────────

    Connections {
        target: AudioService
        function onStateChanged() {
            root._source = "volume";
            root._value = AudioService.volume;
            root._muted = AudioService.muted;
            root._show();
        }
    }

    Connections {
        target: BrightnessService
        function onStateChanged() {
            root._source = "brightness";
            root._value = BrightnessService.brightness;
            root._muted = false;
            root._show();
        }
    }

    // Optimistic path: fern brightness keybinds call showBrightnessOsd /
    // stepBrightnessOsd via IPC so the OSD reacts instantly instead of
    // waiting out the 3s ddcutil poll.
    Connections {
        target: HookService
        function onBrightnessOsdRequested(value) {
            root._source = "brightness";
            root._value = value;
            root._muted = false;
            root._show();
        }
    }

    // ── Show / auto-dismiss ─────────────────────────────────────────

    function _show() {
        root._showing = true;
        dismissTimer.restart();
    }

    Timer {
        id: dismissTimer
        interval: 1500
        onTriggered: root._showing = false
    }

    // ── Window setup ────────────────────────────────────────────────

    // Bottom-anchored only: with neither left nor right anchored the
    // window is just the 280px card, horizontally centered by the
    // compositor — a full-width strip would eat clicks along the whole
    // screen bottom while visible.
    anchors {
        bottom: true
    }

    margins.bottom: root.edgeMargin

    visible: root._showing
    color: "transparent"
    focusable: false
    exclusiveZone: 0

    implicitWidth: root.osdWidth
    implicitHeight: root.osdHeight

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "garden-osd"

    // ── Content ─────────────────────────────────────────────────────

    Rectangle {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        width: root.osdWidth
        height: root.osdHeight
        radius: 2
        color: Theme.baseRaised
        border.width: 1
        border.color: Theme.border

        // Label: "vol 72%" / "muted" / "bri 50%".
        Text {
            id: label
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: {
                if (root._source === "volume" && root._muted)
                    return "muted";
                const pct = Math.round(root._value * 100);
                const prefix = root._source === "volume" ? "vol" : "bri";
                return prefix + " " + pct + "%";
            }
            color: root._muted ? Theme.text4 : Theme.text2
            font.family: Theme.monoFont
            font.pixelSize: 11
        }

        // Progress bar: 4 px tall, fills remaining width.
        Rectangle {
            id: barTrack
            anchors.left: label.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 4
            radius: 2
            color: Theme.borderSub

            Rectangle {
                width: root._muted ? 0 : parent.width * root._value
                height: parent.height
                radius: 2
                color: Theme.accent

                Behavior on width {
                    NumberAnimation { duration: 80; easing.type: Easing.OutCubic }
                }
            }
        }
    }
}

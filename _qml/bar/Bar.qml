import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."
import "../compositor"
import "../services"

/// Bar for one output.
///
/// Each bar follows its own output: its channel dots, the channel
/// visible there (name + pages), and that channel's bar mode. The
/// output holding keyboard focus is drawn at full strength; the other
/// bars dim their channel name.
///
/// Minimal mode is a 2 px rule that expands to a standard-height bar
/// while hovered (spec §2: "2px → 30px on hover"). The exclusive zone
/// stays 2 px, so the expanded bar overlays windows rather than
/// shoving them down.
PanelWindow {
    id: bar

    // The screen comes from PanelWindow's built-in `screen`, set by the
    // Variants delegate in shell.qml (`screen: modelData`). Do NOT
    // redeclare it here: a `property var screen` shadows the window's
    // own property, the bar is never bound to an output, and niri
    // places every bar on the focused screen (no bar on a docked
    // monitor).

    readonly property var output: CompositorService.outputState(bar.screen?.name ?? "")
    readonly property var workspace: bar.output?.active ?? null
    readonly property bool outputFocused: bar.output?.focused ?? false
    readonly property string channel: bar.workspace?.name ?? ""

    readonly property string barMode: ModeService.barModeFor(bar.channel)
    readonly property bool minimal: bar.barMode === "minimal-bar"
    readonly property bool showContent: !bar.minimal || bar._revealed
    readonly property bool _onTop: ConfigService.barPosition !== "bottom"

    /// Minimal bar hovered open.
    property bool _revealed: false

    anchors {
        top: bar._onTop
        bottom: !bar._onTop
        left: true
        right: true
    }

    implicitHeight: bar.showContent
        ? ModeService.heightFor(bar.minimal ? "standard-bar" : bar.barMode)
        : ModeService.minimalHeight
    exclusiveZone: ModeService.heightFor(bar.barMode)
    color: Theme.baseDeep

    // ── Minimal-mode reveal ─────────────────────────────────────────

    HoverHandler {
        id: hover
        onHoveredChanged: {
            if (hovered) {
                collapse.stop();
                if (bar.minimal) bar._revealed = true;
            } else {
                collapse.restart();
            }
        }
    }

    Timer {
        id: collapse
        interval: 400
        onTriggered: {
            bar._revealed = false;
            tip.hide(null);
        }
    }

    onMinimalChanged: if (!bar.minimal) bar._revealed = false

    BarTooltip {
        id: tip
        anchor.window: bar
    }

    // ── Content ─────────────────────────────────────────────────────

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Theme.space2
        anchors.rightMargin: Theme.space2
        spacing: Theme.space1
        visible: bar.showContent

        // Channel dots — every workspace on this output, in order.
        Row {
            Layout.fillHeight: true

            Repeater {
                model: bar.output?.workspaces ?? []

                delegate: BarDot {
                    required property var modelData
                    workspace: modelData
                    outputFocused: bar.outputFocused
                    tip: tip
                }
            }
        }

        // Visible channel: name + pages.
        BarChannel {
            Layout.fillHeight: true
            Layout.maximumWidth: bar.width * 0.6
            clip: true
            workspace: bar.workspace
            outputFocused: bar.outputFocused
            showTitle: bar.barMode === "full-bar"
            viewWidth: bar.width
            tip: tip
        }

        Item { Layout.fillWidth: true }

        BarSystemState {
            Layout.fillHeight: true
            channel: bar.channel
            screen: bar.screen
            tip: tip
        }

        BarClock {
            Layout.fillHeight: true
            showDate: bar.barMode === "full-bar"
            tip: tip
        }
    }

    // ── Edge rule ───────────────────────────────────────────────────
    //
    // 1 px border-sub along the edge facing the desktop, in every mode —
    // the minimal bar is just this rule on base-deep.

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: bar._onTop ? parent.bottom : undefined
        anchors.top: bar._onTop ? undefined : parent.top
        height: 1
        color: Theme.borderSub
    }
}

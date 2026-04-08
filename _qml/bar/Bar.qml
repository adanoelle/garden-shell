import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import ".."
import "../compositor"
import "../services"

/// Top bar panel anchored to the top of each screen.
///
/// Displays channel dots, active channel name with column indicators,
/// and a clock. Height adapts based on ModeService.currentHeight.
PanelWindow {
    id: bar

    /// The screen this bar instance is assigned to.
    required property var screen

    anchors {
        top: ConfigService.barPosition === "top"
        bottom: ConfigService.barPosition === "bottom"
        left: true
        right: true
    }

    implicitHeight: ModeService.currentHeight
    exclusiveZone: implicitHeight
    color: Theme.baseDeep

    // ── Content (hidden in minimal mode) ────────────────────────────

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 12
        anchors.rightMargin: 12
        spacing: 8
        visible: ModeService.showContent
        opacity: ModeService.showContent ? 1.0 : 0.0

        // Channel dots (inactive workspaces).
        Repeater {
            model: CompositorService.workspaces

            delegate: BarDot {
                required property var modelData
                workspace: modelData
            }
        }

        // Active channel display with column indicators.
        BarChannel {
            Layout.fillWidth: false
        }

        // Spacer.
        Item {
            Layout.fillWidth: true
        }

        // Clock.
        BarClock {}
    }

    // ── Minimal mode: thin accent line ──────────────────────────────

    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        height: 1
        color: Theme.borderSub
        visible: !ModeService.showContent
    }
}

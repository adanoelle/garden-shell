import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../services"

/// Notification popup stack — the shell's first NON-MODAL window.
///
/// Establishes the non-modal pattern (OSD, DesktopClock follow this,
/// not OverlayBase):
///   - PanelWindow on WlrLayer.Overlay
///   - exclusiveZone: 0 — claims no space, respects the bar's zone
///   - keyboardFocus: None — never steals focus
///   - window sized to content, so clicks outside cards fall through
///     to whatever is below (nothing to click through inside it)
///
/// Spec (02-shell-design.md §6): cards slide from the right edge,
/// 264–272 px wide, base-raised with 1 px border; app name bold text-1,
/// body text-2, timestamp mono text-4; progress line depletes over the
/// expiry window then vertical-compress dismiss; 60 ms staggered
/// entrance per card in a burst.
PanelWindow {
    id: root

    readonly property int cardWidth: 268
    readonly property int edgeMargin: 12

    // Burst counter for staggered entrance: cards arriving close
    // together get 0 ms, 60 ms, 120 ms… delays; resets after a lull.
    property int _burst: 0

    Timer {
        id: burstReset
        interval: 300
        onTriggered: root._burst = 0
    }

    anchors {
        top: true
        right: true
    }

    margins {
        top: root.edgeMargin
        right: root.edgeMargin
    }

    visible: NotificationService.popups.length > 0
    color: "transparent"
    focusable: false
    exclusiveZone: 0

    implicitWidth: root.cardWidth
    implicitHeight: cards.implicitHeight

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    WlrLayershell.namespace: "garden-notifications"

    Column {
        id: cards
        width: root.cardWidth
        spacing: 8

        Repeater {
            model: ScriptModel {
                values: NotificationService.popups
            }

            delegate: NotificationCard {
                required property var modelData
                notification: modelData
                width: root.cardWidth

                Component.onCompleted: {
                    entranceDelay = root._burst * 60;
                    root._burst++;
                    burstReset.restart();
                }
            }
        }
    }
}

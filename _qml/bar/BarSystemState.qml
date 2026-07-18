import QtQuick
import Quickshell.Services.SystemTray
import ".."
import "../services"

/// Ambient volume and brightness indicators for the bar.
///
/// Two compact slots — `v{n}` and `b{n}` — sit at near-invisible text-4
/// opacity at rest. When a value changes the affected slot brightens to
/// text-1 for 1.5s then fades back. Muted state shows `vm` in Theme.urgent.
/// Hidden entirely in minimal bar mode.
Row {
    id: root

    spacing: 8
    visible: ModeService.showContent

    // Notification suppression indicator (spec §6): dot while
    // suppressed — near-invisible text-4 when the queue is empty,
    // accent once notifications have queued silently.
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 5
        height: 5
        radius: 2.5
        visible: NotificationService.suppressed
        color: NotificationService.queuedCount > 0 ? Theme.accent : Theme.text4
    }

    BarStateSlot {
        id: volSlot
        prefix: "v"
        value: AudioService.muted
                   ? "m"
                   : Math.round(AudioService.volume * 100).toString()
        activeColor: AudioService.muted ? Theme.urgent : Theme.text1

        Connections {
            target: AudioService
            function onStateChanged() { volSlot._trigger() }
        }
    }

    BarStateSlot {
        id: briSlot
        prefix: "b"
        value: Math.round(BrightnessService.brightness * 100).toString()

        Connections {
            target: BrightnessService
            function onStateChanged() { briSlot._trigger() }
        }
    }

    // Network (Phase E) — text-first status: SSID on wifi, "eth" on
    // wired, "offline" when disconnected. Accent dot = VPN/tailscale.
    Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 5

        Rectangle {
            anchors.verticalCenter: parent.verticalCenter
            width: 5
            height: 5
            radius: 2.5
            visible: NetworkService.vpnActive
            color: Theme.accent
        }

        Text {
            anchors.verticalCenter: parent.verticalCenter
            text: NetworkService.connectionType === "wifi"
                      ? NetworkService.ssid
                      : NetworkService.connectionType === "wired"
                          ? "eth" : "offline"
            font.family: Theme.monoFont
            font.pixelSize: 11
            color: Theme.text3
        }
    }

    // Battery (Phase E) — persistent text-3 percentage, unlike the
    // ambient v/b slots: charge is glanceable state, not an event.
    // Urgent below 15% while discharging; `+` suffix on AC. Hidden
    // entirely when the machine has no battery.
    Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: BatteryService.available
        text: Math.round(BatteryService.percentage * 100) + "%"
              + (BatteryService.charging ? "+" : "")
        font.family: Theme.monoFont
        font.pixelSize: 11
        color: BatteryService.low ? Theme.urgent : Theme.text3
    }

    // Tray (Phase E) — single dot when tray items exist (no icon
    // grid); click opens the TrayPanel dropdown. Urgent when any item
    // needs attention.
    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: 5
        height: 5
        radius: 2.5
        visible: SystemTray.items.values.length > 0
        color: SystemTray.items.values.some(
                   i => i.status === Status.NeedsAttention)
                   ? Theme.urgent : Theme.text3

        MouseArea {
            anchors.fill: parent
            anchors.margins: -4   // clickable halo around the 5px dot
            onClicked: HookService.trayToggled()
        }
    }
}

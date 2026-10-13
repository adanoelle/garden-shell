import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Services.SystemTray
import ".."
import "../services"

/// Right-hand system slots: media, volume, brightness, network,
/// bluetooth, battery, tray. Text-first; every slot is a BarSlot, so
/// hover, hit targets and tooltips behave the same everywhere.
///
///   v{n} b{n} — ambient: rest at text-4, brighten on change (1.5 s).
///               Volume: click mutes, scroll steps 5%.
///   network   — SSID / "eth" / "offline", accent dot = VPN/tailscale,
///               urgent on a captive portal / limited connectivity.
///   bt        — "bt", or the connected device's name.
///   battery   — persistent: charge is glanceable state, not an event.
///   media     — channels with the `mpris-ambient` mode only.
///
/// Panels open on this bar's screen.
Row {
    id: root

    /// Channel visible on this bar's output (mode lookups).
    property string channel: ""

    /// The owning bar's screen — panels open there.
    property var screen: null

    /// The owning bar's BarTooltip.
    property var tip: null

    // ── Media (mpris-ambient) ───────────────────────────────────────

    readonly property bool _mediaMode: ModeService.modesFor(root.channel).includes("mpris-ambient")

    // Prefer a playing player; else any player with a track loaded.
    readonly property var _player: {
        const players = Mpris.players.values;
        return players.find(p => p.isPlaying)
            ?? players.find(p => (p.trackTitle ?? "") !== "")
            ?? null;
    }

    BarSlot {
        visible: root._mediaMode && root._player !== null
        text: {
            const p = root._player;
            if (!p) return "";
            const artist = p.trackArtist ?? "";
            return (p.isPlaying ? "\u25b8 " : "\u2016 ") + p.trackTitle
                + (artist ? " \u2022 " + artist : "");
        }
        fontFamily: Theme.sansFont
        maxTextWidth: 260
        color: Theme.text3
        interactive: root._player?.canTogglePlaying ?? false
        tip: root.tip
        tooltip: root._player?.identity ?? ""
        onClicked: root._player.togglePlaying()
    }

    // ── Notification suppression (spec §6) ──────────────────────────
    //
    // Dot while suppressed: text-4 when the queue is empty, accent once
    // notifications have queued silently.

    BarSlot {
        visible: NotificationService.suppressed
        interactive: true
        tip: root.tip
        tooltip: "notifications suppressed"
            + (NotificationService.queuedCount > 0
                ? " \u2022 " + NotificationService.queuedCount + " queued" : "")
        onClicked: HookService.notificationCenterToggled()

        Rectangle {
            width: 5
            height: 5
            radius: 2.5
            color: NotificationService.queuedCount > 0 ? Theme.accent : Theme.text4
        }
    }

    // ── Volume ──────────────────────────────────────────────────────

    BarSlot {
        id: volSlot
        ambient: true
        text: "v" + (AudioService.muted ? "m" : Math.round(AudioService.volume * 100))
        activeColor: AudioService.muted ? Theme.urgent : Theme.text1
        interactive: true
        tip: root.tip
        tooltip: (AudioService.muted ? "muted"
                  : "volume " + Math.round(AudioService.volume * 100) + "%")
            + (AudioService.sink?.description ? " \u2022 " + AudioService.sink.description : "")
        onClicked: AudioService.toggleMute()
        onScrolled: steps => AudioService.setVolume(AudioService.volume + steps * 0.05)

        Connections {
            target: AudioService
            function onStateChanged() { volSlot.pulse(); }
        }
    }

    // ── Brightness ──────────────────────────────────────────────────

    BarSlot {
        id: briSlot
        visible: BrightnessService.available
        ambient: true
        text: "b" + Math.round(BrightnessService.brightness * 100)
        tip: root.tip
        tooltip: "brightness " + Math.round(BrightnessService.brightness * 100) + "%"

        Connections {
            target: BrightnessService
            function onStateChanged() { briSlot.pulse(); }
        }
    }

    // ── Network ─────────────────────────────────────────────────────

    BarSlot {
        text: NetworkService.connectionType === "wifi" ? NetworkService.ssid
            : NetworkService.connectionType === "wired" ? "eth" : "offline"
        maxTextWidth: 140
        // Captive portal / limited connectivity reads as urgent.
        color: NetworkService.connectivityIssue !== "" ? Theme.urgent : Theme.text3
        interactive: true
        tip: root.tip
        tooltip: (NetworkService.connectionType === "wifi" ? "wifi \u2022 " + NetworkService.ssid
                  : NetworkService.connectionType === "wired" ? "wired" : "offline")
            + (NetworkService.connectivityIssue !== ""
                ? " \u2022 " + (NetworkService.connectivityIssue === "portal"
                    ? "captive portal" : NetworkService.connectivityIssue) : "")
            + (NetworkService.vpnActive ? " \u2022 vpn" : "")
        onClicked: HookService.networkPanelToggled(root.screen)

        Rectangle {
            visible: NetworkService.vpnActive
            width: 5
            height: 5
            radius: 2.5
            color: Theme.accent
        }
    }

    // ── Bluetooth ───────────────────────────────────────────────────

    BarSlot {
        text: BluetoothService.anyConnected
            ? BluetoothService.connectedDevices[0].name : "bt"
        maxTextWidth: 140
        color: BluetoothService.anyConnected ? Theme.text3 : Theme.text4
        interactive: true
        tip: root.tip
        tooltip: !BluetoothService.powered ? "bluetooth off"
            : BluetoothService.anyConnected
                ? "bluetooth \u2022 " + BluetoothService.connectedDevices
                    .map(d => d.name + (d.batteryAvailable ? " " + Math.round(d.battery * 100) + "%" : ""))
                    .join(", ")
                : "bluetooth \u2022 no devices"
        onClicked: HookService.bluetoothPanelToggled(root.screen)
    }

    // ── Battery ─────────────────────────────────────────────────────
    //
    // Urgent at ≤15% while discharging; `+` suffix on AC. Hidden on
    // machines without a battery.

    BarSlot {
        visible: BatteryService.available
        text: Math.round(BatteryService.percentage * 100) + "%"
            + (BatteryService.charging ? "+" : "")
        color: BatteryService.low ? Theme.urgent : Theme.text3
        tip: root.tip
        tooltip: {
            if (BatteryService.charging) {
                const t = BatteryService.timeToFull;
                return t > 0 ? "charging \u2022 full in " + root._duration(t) : "on ac power";
            }
            const t = BatteryService.timeToEmpty;
            return t > 0 ? root._duration(t) + " remaining" : "on battery";
        }
    }

    // ── Tray ────────────────────────────────────────────────────────
    //
    // Single dot when tray items exist (no icon grid); urgent when any
    // item needs attention. Click opens the TrayPanel.

    BarSlot {
        visible: SystemTray.items.values.length > 0
        interactive: true
        tip: root.tip
        tooltip: SystemTray.items.values.map(i => i.title || i.id).join(", ")
        onClicked: HookService.trayToggled(root.screen)

        Rectangle {
            width: 5
            height: 5
            radius: 2.5
            color: SystemTray.items.values.some(i => i.status === Status.NeedsAttention)
                ? Theme.urgent : Theme.text3
        }
    }

    function _duration(seconds: real): string {
        const m = Math.round(seconds / 60);
        const h = Math.floor(m / 60);
        return h > 0 ? h + "h " + String(m % 60).padStart(2, "0") + "m" : m + "m";
    }
}

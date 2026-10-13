pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking

/// Reactive network state from Quickshell's native NetworkManager module.
///
/// Wifi and wired come straight from `Networking` over D-Bus — devices,
/// scan results (`WifiNetwork`: name, signalStrength, security, known,
/// connected, stateChanging) and connectivity — with no nmcli polling.
/// Views bind to those live objects.
///
/// VPNs are the exception: the native module models wifi/wired devices
/// only, so NM vpn/wireguard profiles still come from nmcli (re-queried
/// on `nmcli monitor` events), and tailscale from `tailscale status`.
Singleton {
    id: root

    // ── Devices ─────────────────────────────────────────────────────

    readonly property var _devices: Networking.devices.values

    /// First wifi device (null on wifi-less machines).
    readonly property var wifiDevice: root._devices.find(d => d.type === DeviceType.Wifi) ?? null

    /// Wired devices.
    readonly property var wiredDevices: root._devices.filter(d => d.type === DeviceType.Wired)

    /// Wifi radio on (soft switch) — writable via setWifiEnabled().
    readonly property bool wifiEnabled: Networking.wifiEnabled

    /// Scan results, deduped by name (strongest kept), sorted connected
    /// first, then known, then by signal.
    readonly property var wifiNetworks: {
        const nets = root.wifiDevice?.networks.values ?? [];
        const best = {};
        for (const n of nets) {
            if (!n.name) continue;   // hidden networks
            const prev = best[n.name];
            if (!prev || n.connected || (!prev.connected && n.signalStrength > prev.signalStrength))
                best[n.name] = n;
        }
        return Object.values(best).sort((a, b) =>
            (b.connected - a.connected) || (b.known - a.known)
            || (b.signalStrength - a.signalStrength));
    }

    // ── Summary state (bar) ─────────────────────────────────────────

    readonly property var _wifiNetwork: root.wifiNetworks.find(n => n.connected) ?? null
    readonly property var _wiredUp: root.wiredDevices.find(d => d.connected) ?? null

    /// "wifi" | "wired" | "none"
    readonly property string connectionType: root._wifiNetwork ? "wifi"
        : root._wiredUp ? "wired" : "none"

    /// Connected wifi network name, "" otherwise.
    readonly property string ssid: root._wifiNetwork?.name ?? ""

    /// Connectivity problem worth surfacing: "portal" (captive portal),
    /// "limited", "no internet" — "" when fine or unknown.
    readonly property string connectivityIssue: {
        if (root.connectionType === "none" || !Networking.canCheckConnectivity) return "";
        switch (Networking.connectivity) {
        case NetworkConnectivity.Portal:  return "portal";
        case NetworkConnectivity.Limited: return "limited";
        case NetworkConnectivity.None:    return "no internet";
        default:                          return "";
        }
    }

    /// Any NM vpn/wireguard connection or tailscale up.
    readonly property bool vpnActive: root.vpnConnections.some(c => c.active) || root.tailscaleUp

    // ── Panel state ─────────────────────────────────────────────────

    /// True while the NetworkPanel is visible — wifi scanning runs then.
    property bool panelOpen: false

    function setPanelOpen(open) {
        root.panelOpen = open;
        if (root.wifiDevice) root.wifiDevice.scannerEnabled = open;
        if (open) root._requeryVpn();
        else root._clearError();
    }

    // ── Wifi / wired actions ────────────────────────────────────────

    function setWifiEnabled(on: bool) {
        Networking.wifiEnabled = on;
    }

    function connectNetwork(network) {
        root._clearError();
        network.connect();
    }

    function disconnectNetwork(network) {
        root._clearError();
        network.disconnect();
    }

    /// Bring a wired device up (its NM connection) or down.
    function toggleWired(device) {
        root._clearError();
        if (device.connected) device.disconnect();
        else device.network?.connect();
    }

    // Failure reasons arrive per network; surface the latest.
    Instantiator {
        model: root.wifiNetworks
        delegate: Connections {
            required property var modelData
            target: modelData
            function onConnectionFailed(reason) {
                root._fail(modelData.name, ConnectionFailReason.toString(reason));
            }
        }
    }

    // ── VPN (nmcli + tailscale) ─────────────────────────────────────

    /// NM vpn/wireguard profiles: [{name, type, active}].
    property var vpnConnections: []

    /// Tailscale backend running.
    property bool tailscaleUp: false

    /// VPN profile an up/down action is running against.
    property string busyVpn: ""

    function toggleVpn(name: string, active: bool) {
        if (vpnAction.running) return;
        root._clearError();
        root.busyVpn = name;
        vpnAction.command = ["nmcli", "connection", active ? "down" : "up", "id", name];
        vpnAction.running = true;
    }

    // nmcli monitor only triggers VPN re-queries now; it shouldn't exit,
    // but respawn after a beat if NetworkManager restarts.
    Process {
        id: monitor
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser {
            onRead: () => vpnDebounce.restart()
        }
        onExited: respawn.restart()
    }

    Timer {
        id: respawn
        interval: 3000
        onTriggered: monitor.running = true
    }

    Timer {
        id: vpnDebounce
        interval: 300
        onTriggered: root._requeryVpn()
    }

    Component.onCompleted: root._requeryVpn()

    function _requeryVpn() {
        vpnQuery.running = true;
        tailscaleQuery.running = true;
    }

    Process {
        id: vpnQuery
        command: ["nmcli", "-t", "-f", "NAME,TYPE,ACTIVE", "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const vpns = [];
                for (const line of text.split("\n")) {
                    if (!line) continue;
                    const parts = root._splitTerse(line);
                    if (parts.length < 3) continue;
                    if (parts[1] !== "vpn" && parts[1] !== "wireguard") continue;
                    vpns.push({ name: parts[0], type: parts[1], active: parts[2] === "yes" });
                }
                vpns.sort((a, b) => a.name.localeCompare(b.name));
                root.vpnConnections = vpns;
            }
        }
    }

    // sh guard: exits 0 with "{}" when tailscale isn't installed, so
    // machines without it stay silent (no spawn-failure log spam).
    Process {
        id: tailscaleQuery
        command: ["sh", "-c",
            "command -v tailscale >/dev/null && exec tailscale status --json; echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root.tailscaleUp = JSON.parse(text).BackendState === "Running";
                } catch (e) {
                    root.tailscaleUp = false;
                }
            }
        }
    }

    Process {
        id: vpnAction
        stderr: StdioCollector { id: vpnErr }
        onExited: exitCode => {
            const name = root.busyVpn;
            root.busyVpn = "";
            if (exitCode !== 0) {
                const msg = vpnErr.text.split("\n")[0].replace(/^Error:\s*/, "").trim();
                root._fail(name, msg || "failed");
            }
            root._requeryVpn();
        }
    }

    /// Split an nmcli terse line on unescaped ":" (terse output escapes
    /// ":" as "\:" and "\" as "\\").
    function _splitTerse(line) {
        const parts = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const ch = line[i];
            if (ch === "\\" && i + 1 < line.length) {
                cur += line[i + 1];
                i++;
            } else if (ch === ":") {
                parts.push(cur);
                cur = "";
            } else {
                cur += ch;
            }
        }
        parts.push(cur);
        return parts;
    }

    // ── Errors ──────────────────────────────────────────────────────

    /// Last failure: network/profile name + short message. Cleared after
    /// 6 s, by the next action, or on panel close.
    property string errorName: ""
    property string errorText: ""

    function _fail(name, text) {
        root.errorName = name;
        root.errorText = text.length > 60 ? text.slice(0, 60) + "\u2026" : text;
        errorClear.restart();
    }

    function _clearError() {
        root.errorName = "";
        root.errorText = "";
        errorClear.stop();
    }

    Timer {
        id: errorClear
        interval: 6000
        onTriggered: root._clearError()
    }
}

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/// Reactive network state parsed from nmcli (no Quickshell builtin).
///
/// `nmcli monitor` runs as a long-lived event stream; each event line
/// debounce-triggers a re-query of active connections. VPN presence
/// checks both NetworkManager vpn/wireguard connections and tailscale
/// (`tailscale status --json`, BackendState "Running") — tailscale's
/// tun device flaps NM events, so it rides the same re-query trigger.
Singleton {
    id: root

    /// "wifi" | "wired" | "none"
    property string connectionType: "none"

    /// SSID when on wifi (NM connection name — matches the SSID for
    /// standard NM-created profiles), "" otherwise.
    property string ssid: ""

    /// Any NM vpn/wireguard connection or tailscale up.
    readonly property bool vpnActive: root._nmVpn || root._tailscale

    property bool _nmVpn: false
    property bool _tailscale: false

    // ── Event stream ────────────────────────────────────────────────

    Process {
        id: monitor
        command: ["nmcli", "monitor"]
        running: true
        stdout: SplitParser {
            onRead: () => requeryDebounce.restart()
        }
        // nmcli monitor shouldn't exit; if it does (NM restart),
        // respawn after a beat so state doesn't silently freeze.
        onExited: respawn.restart()
    }

    Timer {
        id: respawn
        interval: 3000
        onTriggered: monitor.running = true
    }

    // Coalesce nmcli event bursts into a single re-query.
    Timer {
        id: requeryDebounce
        interval: 300
        onTriggered: root._requery()
    }

    Component.onCompleted: root._requery()

    function _requery() {
        query.running = true;
        tailscaleQuery.running = true;
    }

    // ── Active connections ──────────────────────────────────────────

    Process {
        id: query
        command: ["nmcli", "-t", "-f", "TYPE,DEVICE,NAME",
                  "connection", "show", "--active"]
        stdout: StdioCollector {
            onStreamFinished: root._parseConnections(text)
        }
    }

    // Terse format: "802-3-ethernet:enp4s0:Wired connection 2".
    // NAME is last so it can absorb embedded colons; bridge/loopback
    // entries (docker0, lo) fall through untouched.
    function _parseConnections(text) {
        let wifiName = "";
        let wired = false;
        let vpn = false;

        for (const line of text.split("\n")) {
            if (!line) continue;
            const parts = line.split(":");
            switch (parts[0]) {
            case "802-11-wireless":
                wifiName = parts.slice(2).join(":");
                break;
            case "802-3-ethernet":
                wired = true;
                break;
            case "vpn":
            case "wireguard":
                vpn = true;
                break;
            }
        }

        root._nmVpn = vpn;
        if (wifiName) {
            root.connectionType = "wifi";
            root.ssid = wifiName;
        } else {
            root.connectionType = wired ? "wired" : "none";
            root.ssid = "";
        }
    }

    // ── Tailscale ───────────────────────────────────────────────────

    // sh guard: exits 0 with "{}" when tailscale isn't installed, so
    // machines without it stay silent (no spawn-failure log spam).
    Process {
        id: tailscaleQuery
        command: ["sh", "-c",
            "command -v tailscale >/dev/null && exec tailscale status --json; echo '{}'"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    root._tailscale =
                        JSON.parse(text).BackendState === "Running";
                } catch (e) {
                    root._tailscale = false;
                }
            }
        }
    }
}

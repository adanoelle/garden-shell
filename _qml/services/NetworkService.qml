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

    // ── Panel state (NetworkPanel) ──────────────────────────────────

    /// True while the NetworkPanel is visible — gates panel-only
    /// queries so the monitor doesn't refresh lists nobody sees.
    property bool panelOpen: false

    /// Saved NM profiles: [{name, type, device, active}]. Allowlisted
    /// to wifi/ethernet/vpn/wireguard — drops loopback/bridge/tun
    /// noise (lo, docker0, tailscale0).
    property var savedConnections: []

    /// First wifi-capable device name, "" on wifi-less machines
    /// (gates the panel's wifi section).
    property string wifiDevice: ""

    /// Scan results: [{ssid, signal, inUse, secured, known}], deduped
    /// by SSID (max signal), sorted in-use first then signal desc.
    property var wifiNetworks: []

    /// True while an explicit `--rescan yes` scan is in flight.
    property bool scanning: false

    /// Connection name an up/down action is currently running against.
    property string busyName: ""

    /// Last failed action: connection name + trimmed stderr snippet.
    /// Cleared by the 6s timer, the next action, or panel close.
    property string errorName: ""
    property string errorText: ""

    /// Saved wireless profile names — "known network" check. NM
    /// convention names the profile after the SSID, so profile-name
    /// membership approximates "we have credentials for this SSID".
    property var _savedWifiNames: []

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
        // External changes (nm-applet, nmcli in a terminal) refresh
        // the open panel too. No auto-rescan of wifi here — radio
        // churn; scan only on panel open + explicit rescan.
        if (root.panelOpen) savedQuery.running = true;
    }

    // ── Panel API ───────────────────────────────────────────────────

    function setPanelOpen(open) {
        root.panelOpen = open;
        if (open) {
            savedQuery.running = true;
            // deviceQuery kicks a scan on completion when a wifi
            // device exists (wifiDevice may be stale/"" right now).
            deviceQuery.running = true;
        } else {
            root.errorName = "";
            root.errorText = "";
            errorClear.stop();
        }
    }

    function rescan() {
        if (root.wifiDevice === "") return;
        root._startScan("yes");
    }

    function activate(name) {
        root._runAction(name, ["nmcli", "connection", "up", "id", name]);
    }

    function deactivate(name) {
        root._runAction(name, ["nmcli", "connection", "down", "id", name]);
    }

    function _runAction(name, cmd) {
        if (action.running) return;   // single-flight
        root.errorName = "";
        root.errorText = "";
        errorClear.stop();
        root.busyName = name;
        action.command = cmd;
        action.running = true;
    }

    function _startScan(rescanMode) {
        if (scanQuery.running) return;
        root.scanning = rescanMode === "yes";
        scanQuery.command = ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY",
                             "device", "wifi", "list", "--rescan", rescanMode];
        scanQuery.running = true;
    }

    /// Split an nmcli terse line on unescaped ":". Terse output
    /// escapes ":" as "\:" and "\" as "\\" — the active-connection
    /// parser dodges this by putting NAME last, but the panel queries
    /// put NAME/SSID first, so they need real unescaping.
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

    // ── Panel queries ───────────────────────────────────────────────

    Process {
        id: savedQuery
        command: ["nmcli", "-t", "-f", "NAME,TYPE,DEVICE,ACTIVE",
                  "connection", "show"]
        stdout: StdioCollector {
            onStreamFinished: root._parseSaved(text)
        }
    }

    function _parseSaved(text) {
        const allowed = ["802-11-wireless", "802-3-ethernet",
                         "vpn", "wireguard"];
        const conns = [];
        const wifiNames = [];

        for (const line of text.split("\n")) {
            if (!line) continue;
            const parts = root._splitTerse(line);
            if (parts.length < 4) continue;
            if (allowed.indexOf(parts[1]) < 0) continue;
            conns.push({
                name: parts[0],
                type: parts[1],
                device: parts[2],
                active: parts[3] === "yes",
            });
            if (parts[1] === "802-11-wireless") wifiNames.push(parts[0]);
        }

        // Link types first, then vpn/wireguard; alpha within group.
        const group = (c) =>
            (c.type === "vpn" || c.type === "wireguard") ? 1 : 0;
        conns.sort((a, b) => group(a) - group(b)
                             || a.name.localeCompare(b.name));

        // New array assignment — QML var change detection.
        root.savedConnections = conns;
        root._savedWifiNames = wifiNames;
    }

    Process {
        id: deviceQuery
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE", "device"]
        stdout: StdioCollector {
            onStreamFinished: {
                let dev = "";
                for (const line of text.split("\n")) {
                    if (!line) continue;
                    const parts = root._splitTerse(line);
                    if (parts[1] === "wifi") { dev = parts[0]; break; }
                }
                root.wifiDevice = dev;
                if (dev !== "" && root.panelOpen) root._startScan("auto");
            }
        }
    }

    Process {
        id: scanQuery
        stdout: StdioCollector { id: scanOut }
        onExited: (exitCode) => {
            root.scanning = false;
            if (exitCode !== 0) {
                root.wifiNetworks = [];
                return;
            }
            root._parseScan(scanOut.text);
        }
    }

    function _parseScan(text) {
        // Dedupe by SSID keeping max signal (APs on multiple bands).
        const bySsid = {};
        for (const line of text.split("\n")) {
            if (!line) continue;
            const parts = root._splitTerse(line);
            if (parts.length < 4) continue;
            const ssid = parts[1];
            if (!ssid) continue;   // hidden networks
            const net = {
                ssid: ssid,
                signal: parseInt(parts[2], 10) || 0,
                inUse: parts[0] === "*",
                secured: parts[3] !== "" && parts[3] !== "--",
                known: root._savedWifiNames.indexOf(ssid) >= 0,
            };
            const prev = bySsid[ssid];
            if (!prev || net.signal > prev.signal) {
                if (prev && prev.inUse) net.inUse = true;
                bySsid[ssid] = net;
            } else if (net.inUse) {
                prev.inUse = true;
            }
        }

        const nets = Object.values(bySsid);
        nets.sort((a, b) => (b.inUse - a.inUse) || (b.signal - a.signal));
        root.wifiNetworks = nets;
    }

    // ── Actions ─────────────────────────────────────────────────────

    // One reusable up/down Process; command set by _runAction.
    Process {
        id: action
        stderr: StdioCollector { id: actionErr }
        onExited: (exitCode) => {
            const name = root.busyName;
            root.busyName = "";
            if (exitCode !== 0) {
                // First stderr line, sans "Error:" prefix, clamped so
                // it fits the row's status slot.
                let msg = actionErr.text.split("\n")[0]
                    .replace(/^Error:\s*/, "").trim();
                if (msg.length > 60) msg = msg.slice(0, 60) + "\u2026";
                root.errorName = name;
                root.errorText = msg || "failed";
                errorClear.restart();
            }
            root._requery();   // re-queries savedQuery too when panelOpen
        }
    }

    Timer {
        id: errorClear
        interval: 6000
        onTriggered: {
            root.errorName = "";
            root.errorText = "";
        }
    }
}

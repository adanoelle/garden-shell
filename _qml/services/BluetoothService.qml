pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/// Reactive bluetooth state parsed from bluetoothctl.
///
/// `dbus-monitor` on org.bluez signals runs as a long-lived event
/// stream; any signal line debounce-triggers a re-query of device
/// lists. Follows the NetworkService pattern exactly.
Singleton {
    id: root

    /// Adapter powered on/off.
    property bool powered: false

    /// At least one device is connected.
    readonly property bool anyConnected: root.connectedDevices.length > 0

    /// [{name, mac}] — currently connected devices.
    property var connectedDevices: []

    // ── Panel state ─────────────────────────────────────────────────

    /// True while the BluetoothPanel is visible — gates panel-only
    /// queries so the monitor doesn't refresh lists nobody sees.
    property bool panelOpen: false

    /// [{name, mac, connected}] — paired devices.
    property var pairedDevices: []

    /// [{name, mac}] — unpaired nearby devices from scan.
    property var scanResults: []

    /// True while a discovery scan is running.
    property bool scanning: false

    /// MAC address an action is currently running against.
    property string busyMac: ""

    /// Last failed action: device name + trimmed stderr snippet.
    property string errorName: ""
    property string errorText: ""

    // ── Event stream ────────────────────────────────────────────────

    Process {
        id: monitor
        command: ["dbus-monitor", "--system",
                  "type='signal',sender='org.bluez',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'"]
        running: true
        stdout: SplitParser {
            onRead: () => requeryDebounce.restart()
        }
        onExited: respawn.restart()
    }

    Timer {
        id: respawn
        interval: 3000
        onTriggered: monitor.running = true
    }

    Timer {
        id: requeryDebounce
        interval: 300
        onTriggered: root._requery()
    }

    Component.onCompleted: root._requery()

    function _requery() {
        adapterQuery.running = true;
        connectedQuery.running = true;
        // pairedQuery depends on connectedDevices for the `connected`
        // flag — kicked from connectedQuery.onStreamFinished instead.
    }

    // ── Panel API ───────────────────────────────────────────────────

    function setPanelOpen(open) {
        root.panelOpen = open;
        if (open) {
            connectedQuery.running = true;   // chains into pairedQuery
            root.startScan();
        } else {
            root.stopScan();
            root.errorName = "";
            root.errorText = "";
            errorClear.stop();
        }
    }

    function connect(mac) {
        root._runAction(mac, ["bluetoothctl", "connect", mac]);
    }

    function disconnect(mac) {
        root._runAction(mac, ["bluetoothctl", "disconnect", mac]);
    }

    function pair(mac) {
        root._runAction(mac,
            ["sh", "-c", "bluetoothctl trust " + mac
             + " && bluetoothctl pair " + mac
             + " && bluetoothctl connect " + mac]);
    }

    function remove(mac) {
        root._runAction(mac, ["bluetoothctl", "remove", mac]);
    }

    function togglePower() {
        const cmd = root.powered ? "off" : "on";
        powerAction.command = ["bluetoothctl", "power", cmd];
        powerAction.running = true;
    }

    function startScan() {
        if (root.scanning) return;
        root.scanning = true;
        scanProc.running = true;
        scanTimeout.restart();
    }

    function stopScan() {
        scanTimeout.stop();
        if (root.scanning) {
            root.scanning = false;
            scanProc.signal(15);       // SIGTERM
            scanStop.running = true;   // bluetoothctl scan off
        }
    }

    function _runAction(mac, cmd) {
        if (action.running) return;
        root.errorName = "";
        root.errorText = "";
        errorClear.stop();
        root.busyMac = mac;
        action.command = cmd;
        action.running = true;
    }

    /// Parse `Device AA:BB:CC:DD:EE:FF Some Name` lines.
    function _parseDeviceLines(text) {
        const devs = [];
        for (const line of text.split("\n")) {
            const m = line.match(/^Device\s+([0-9A-Fa-f:]{17})\s+(.+)$/);
            if (m) devs.push({ mac: m[1], name: m[2] });
        }
        return devs;
    }

    // ── Adapter query ───────────────────────────────────────────────

    Process {
        id: adapterQuery
        command: ["bluetoothctl", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const on = text.indexOf("Powered: yes") >= 0;
                root.powered = on;
                if (on) root._ensureMprisProxy();
            }
        }
    }

    // mpris-proxy bridges AVRCP button presses (headphone play/pause)
    // to MPRIS D-Bus calls. Started on-demand when adapter is powered.
    // Quick exit (< 2s) means not installed — stop retrying.
    property bool _mprisProxyRunning: false
    property bool _mprisProxyFailed: false
    property real _mprisProxyStartTime: 0

    function _ensureMprisProxy() {
        if (root._mprisProxyRunning || root._mprisProxyFailed) return;
        root._mprisProxyStartTime = Date.now();
        mprisProxyProc.running = true;
        root._mprisProxyRunning = true;
    }

    Process {
        id: mprisProxyProc
        command: ["mpris-proxy"]
        onExited: {
            root._mprisProxyRunning = false;
            // Quick exit means not installed or broken — don't retry.
            // Long-lived exit (killed by reload) is fine to restart.
            if (Date.now() - root._mprisProxyStartTime < 2000)
                root._mprisProxyFailed = true;
        }
    }

    // ── Connected devices ───────────────────────────────────────────

    Process {
        id: connectedQuery
        command: ["bluetoothctl", "devices", "Connected"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.connectedDevices = root._parseDeviceLines(text);
                if (root.panelOpen) pairedQuery.running = true;
            }
        }
    }

    // ── Paired devices (panel-gated) ────────────────────────────────

    Process {
        id: pairedQuery
        command: ["bluetoothctl", "devices", "Paired"]
        stdout: StdioCollector {
            onStreamFinished: {
                const paired = root._parseDeviceLines(text);
                const connMacs = root.connectedDevices.map(d => d.mac);
                for (const d of paired)
                    d.connected = connMacs.indexOf(d.mac) >= 0;
                root.pairedDevices = paired;
            }
        }
    }

    // ── Scanning ────────────────────────────────────────────────────

    Process {
        id: scanProc
        command: ["bluetoothctl", "--timeout", "12", "scan", "on"]
        stdout: SplitParser {
            // Each discovery line triggers a device list refresh.
            onRead: () => scanRequery.restart()
        }
        onExited: {
            root.scanning = false;
            scanTimeout.stop();
        }
    }

    Timer {
        id: scanTimeout
        interval: 12000
        onTriggered: root.stopScan()
    }

    Process {
        id: scanStop
        command: ["bluetoothctl", "scan", "off"]
    }

    // Re-query discovered devices during scan (debounced).
    Timer {
        id: scanRequery
        interval: 500
        onTriggered: nearbyQuery.running = true
    }

    Process {
        id: nearbyQuery
        command: ["bluetoothctl", "devices"]
        stdout: StdioCollector {
            onStreamFinished: {
                const all = root._parseDeviceLines(text);
                const pairedMacs = root.pairedDevices.map(d => d.mac);
                const nearby = all.filter(
                    d => pairedMacs.indexOf(d.mac) < 0);
                root.scanResults = nearby;
            }
        }
    }

    // ── Actions ─────────────────────────────────────────────────────

    Process {
        id: action
        stderr: StdioCollector { id: actionErr }
        onExited: (exitCode) => {
            const mac = root.busyMac;
            root.busyMac = "";
            if (exitCode !== 0) {
                let msg = actionErr.text.split("\n")[0]
                    .replace(/^.*Failed\s*/i, "").trim();
                if (msg.length > 60) msg = msg.slice(0, 60) + "\u2026";
                // Find device name for the MAC.
                const dev = root.pairedDevices.find(d => d.mac === mac)
                            || root.scanResults.find(d => d.mac === mac);
                root.errorName = dev ? dev.name : mac;
                root.errorText = msg || "failed";
                errorClear.restart();
            }
            root._requery();
        }
    }

    Process {
        id: powerAction
        onExited: root._requery()
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

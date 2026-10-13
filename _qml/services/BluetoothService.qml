pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io

/// Reactive bluetooth state from Quickshell's native BlueZ module.
///
/// Everything is event-driven over D-Bus — no bluetoothctl polling. The
/// device lists below are arrays of live `BluetoothDevice` objects
/// (name, address, connected, paired, state, battery…), so views bind
/// straight to device properties.
///
/// Two deliberate exceptions:
///
///   - Adapter power reads `enabled` (BlueZ `Powered`), never the
///     adapter's `state`: that comes from BlueZ `PowerState`, which
///     BlueZ < 5.66 lacks, so it would read "Disabled" forever.
///   - Pairing a *new* device shells out to bluetoothctl. BlueZ's
///     Device1.Pair() fails unless a pairing agent is registered and
///     Quickshell registers none; bluetoothctl brings its own agent for
///     the duration (Just Works — AirPods etc., no PIN entry).
///
/// Native calls report no errors, so failures are inferred: a connect
/// that settles back to Disconnected shows "failed" for 6 s.
Singleton {
    id: root

    readonly property var adapter: Bluetooth.defaultAdapter

    /// Adapter powered on.
    readonly property bool powered: root.adapter?.enabled ?? false

    /// Discovery running.
    readonly property bool scanning: root.adapter?.discovering ?? false

    readonly property var _devices: root.adapter?.devices.values ?? []

    /// Connected devices.
    readonly property var connectedDevices: root._devices.filter(d => d.connected)
    readonly property bool anyConnected: root.connectedDevices.length > 0

    /// Paired devices, connected first then by name.
    readonly property var pairedDevices: root._devices
        .filter(d => d.paired)
        .sort((a, b) => (b.connected - a.connected) || a.name.localeCompare(b.name))

    /// Unpaired devices seen by discovery, one per name. BlueZ names a
    /// device after its address until it learns a real name — skip
    /// those. Earbuds often advertise twice (BLE + classic addresses)
    /// under one name; list the name once.
    readonly property var nearbyDevices: {
        const seen = {};
        return root._devices.filter(d => {
            if (d.paired || root._isAddressName(d.name) || seen[d.name]) return false;
            seen[d.name] = true;
            return true;
        });
    }

    function _isAddressName(name: string): bool {
        return /^([0-9A-F]{2}[-:]){5}[0-9A-F]{2}$/i.test(name);
    }

    // ── Panel state ─────────────────────────────────────────────────

    /// True while the BluetoothPanel is visible; discovery runs then.
    property bool panelOpen: false

    function setPanelOpen(open) {
        root.panelOpen = open;
        if (open) {
            root.startScan();
        } else {
            root.stopScan();
            root._clearError();
        }
    }

    // ── Actions ─────────────────────────────────────────────────────

    function togglePower() {
        if (root.adapter) root.adapter.enabled = !root.adapter.enabled;
    }

    function startScan() {
        if (root.adapter?.enabled) root.adapter.discovering = true;
    }

    function stopScan() {
        if (root.adapter?.discovering) root.adapter.discovering = false;
    }

    function connect(device) {
        root._clearError();
        root._watch = device;
        device.connect();
    }

    function disconnect(device) {
        root._clearError();
        device.disconnect();
    }

    function forget(device) {
        root._clearError();
        device.forget();
    }

    /// Trust + pair + connect via bluetoothctl (see header).
    function pair(device) {
        if (pairProc.running) return;
        root._clearError();
        root.pairingAddress = device.address;
        pairProc.command = ["sh", "-c",
            'bluetoothctl trust "$1" && bluetoothctl pair "$1" && bluetoothctl connect "$1"',
            "garden-bt-pair", device.address];
        pairProc.running = true;
    }

    /// Address of the device bluetoothctl is pairing ("" when idle).
    property string pairingAddress: ""

    Process {
        id: pairProc
        stderr: StdioCollector { id: pairErr }
        onExited: exitCode => {
            const address = root.pairingAddress;
            root.pairingAddress = "";
            if (exitCode !== 0) {
                const msg = pairErr.text.split("\n")[0].replace(/^.*Failed\s*/i, "").trim();
                root._fail(address, msg || "pairing failed");
            }
        }
    }

    // ── Errors ──────────────────────────────────────────────────────

    /// Last failure: device address + short message. Cleared after 6 s,
    /// by the next action, or on panel close.
    property string errorAddress: ""
    property string errorText: ""

    function _fail(address, text) {
        root.errorAddress = address;
        root.errorText = text.length > 60 ? text.slice(0, 60) + "\u2026" : text;
        errorClear.restart();
    }

    function _clearError() {
        root.errorAddress = "";
        root.errorText = "";
        errorClear.stop();
    }

    Timer {
        id: errorClear
        interval: 6000
        onTriggered: root._clearError()
    }

    /// Device whose connect attempt is being watched for failure.
    property var _watch: null

    Connections {
        target: root._watch
        function onStateChanged() {
            const d = root._watch;
            if (d.state === BluetoothDeviceState.Connected) {
                root._watch = null;
            } else if (d.state === BluetoothDeviceState.Disconnected) {
                root._watch = null;
                root._fail(d.address, "connect failed");
            }
        }
    }

    // ── AVRCP media keys ────────────────────────────────────────────
    //
    // mpris-proxy bridges headphone play/pause to MPRIS. Started when the
    // adapter is powered; a quick exit (< 2 s) means it isn't installed —
    // stop retrying.

    property bool _mprisProxyFailed: false
    property real _mprisProxyStart: 0

    onPoweredChanged: root._ensureMprisProxy()
    Component.onCompleted: root._ensureMprisProxy()

    function _ensureMprisProxy() {
        if (!root.powered || mprisProxy.running || root._mprisProxyFailed) return;
        root._mprisProxyStart = Date.now();
        mprisProxy.running = true;
    }

    Process {
        id: mprisProxy
        command: ["mpris-proxy"]
        onExited: {
            if (Date.now() - root._mprisProxyStart < 2000) root._mprisProxyFailed = true;
        }
    }
}

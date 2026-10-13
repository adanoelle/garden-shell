import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Networking

/// Read-only probe of Quickshell's native Bluetooth and Networking state.
///
/// Verifies the modules see this machine's hardware before services are
/// built on them (CLAUDE.md integration rule 1). Run via
/// `qs -p _qml/dev/netbt-probe.qml` — waits briefly for D-Bus state to
/// populate, prints it, then exits. Never changes adapter or connection
/// state, never scans.
///
/// Not part of the shell — never imported by shell.qml.
ShellRoot {
    id: root

    // Singletons are lazy: touch both now so their D-Bus clients start,
    // and read them only after the settle timer.
    property var _net: Networking
    property var _bt: Bluetooth

    function _enumName(e, v) {
        try { return e.toString(v); } catch (err) { return String(v); }
    }

    function _dump() {
        console.info("\u2500\u2500 networking");
        console.info("  backend", root._enumName(NetworkBackendType, Networking.backend),
                     "| wifiEnabled", Networking.wifiEnabled,
                     "| wifiHardwareEnabled", Networking.wifiHardwareEnabled,
                     "| connectivity", root._enumName(NetworkConnectivity, Networking.connectivity),
                     "| canCheckConnectivity", Networking.canCheckConnectivity);
        for (const d of Networking.devices.values) {
            console.info("  device", d.name,
                         "type", root._enumName(DeviceType, d.type),
                         "connected", d.connected,
                         "state", root._enumName(ConnectionState, d.state),
                         "nmManaged", d.nmManaged,
                         "networks", d.networks.values.length,
                         d.type === DeviceType.Wired ? "hasLink " + d.hasLink + " link " + d.linkSpeed : "");
            for (const n of d.networks.values) {
                console.info("    network", JSON.stringify(n.name),
                             "connected", n.connected, "known", n.known,
                             "state", root._enumName(ConnectionState, n.state),
                             n.signalStrength !== undefined
                                 ? "signal " + Math.round(n.signalStrength * 100) + "% security "
                                   + root._enumName(WifiSecurityType, n.security)
                                 : "",
                             "settings", n.nmSettings.length);
            }
        }

        console.info("\u2500\u2500 bluetooth");
        const a = Bluetooth.defaultAdapter;
        if (!a) {
            console.info("  no adapter");
        } else {
            console.info("  adapter", a.name, a.adapterId,
                         "enabled", a.enabled,
                         "state", root._enumName(BluetoothAdapterState, a.state),
                         "discovering", a.discovering,
                         "devices", a.devices.values.length);
            for (const d of a.devices.values) {
                console.info("    device", JSON.stringify(d.name),
                             "connected", d.connected, "paired", d.paired,
                             "trusted", d.trusted, "bonded", d.bonded,
                             "state", root._enumName(BluetoothDeviceState, d.state),
                             "icon", d.icon,
                             d.batteryAvailable ? "battery " + Math.round(d.battery * 100) + "%" : "");
            }
        }
        Qt.quit();
    }

    Timer {
        running: true
        interval: 3000
        onTriggered: root._dump()
    }
}

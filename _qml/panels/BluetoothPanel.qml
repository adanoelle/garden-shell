import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../services"

/// Bluetooth dropdown — clickable bar bluetooth indicator.
///
/// Anchored-panel pattern (see NetworkPanel): transparent full-surface
/// PanelWindow catches outside clicks; the card anchors under the
/// bar's right edge. Pointer-only — no keyboard grab.
///
/// Sections: status header with power toggle, paired devices
/// (click to connect/disconnect), and nearby scan results (click to
/// trust+pair+connect). AirPods use Just Works pairing, no PIN entry.
PanelWindow {
    id: panel

    visible: false

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }
    exclusiveZone: 0
    color: "transparent"

    WlrLayershell.namespace: "garden-bluetooth"
    WlrLayershell.layer: WlrLayer.Overlay

    readonly property int contentWidth: 260

    onVisibleChanged: {
        BluetoothService.setPanelOpen(visible);
    }

    Connections {
        target: HookService
        function onBluetoothPanelToggled() { panel.visible = !panel.visible; }
    }

    // ── Shared row ───────────────────────────────────────────────────

    component BtRow: Item {
        id: row

        required property string name
        required property string mac
        property bool connected: false
        signal clicked()

        readonly property bool busy: BluetoothService.busyMac === row.mac
        readonly property bool showError:
            BluetoothService.errorName === row.name

        width: panel.contentWidth
        height: nameText.implicitHeight

        Text {
            id: nameText
            anchors.left: parent.left
            anchors.right: statusText.left
            anchors.rightMargin: 8
            text: row.name
            elide: Text.ElideRight
            font.family: Theme.monoFont
            font.pixelSize: 12
            color: row.connected ? Theme.text1 : Theme.text3
        }

        Text {
            id: statusText
            anchors.right: parent.right
            width: Math.min(implicitWidth, row.width - 40)
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            text: row.busy ? "\u2026"
                  : row.showError ? BluetoothService.errorText
                  : row.connected ? "connected" : "\u2014"
            font.family: Theme.monoFont
            font.pixelSize: 11
            color: row.busy ? Theme.text2
                   : row.showError ? Theme.urgent
                   : row.connected ? Theme.ok : Theme.text4
        }

        MouseArea {
            anchors.fill: parent
            enabled: !row.busy
            onClicked: row.clicked()
        }
    }

    // Click-outside catcher.
    MouseArea {
        anchors.fill: parent
        onClicked: panel.visible = false
    }

    Rectangle {
        id: card

        anchors.top: ConfigService.barPosition === "top"
                         ? parent.top : undefined
        anchors.bottom: ConfigService.barPosition === "bottom"
                            ? parent.bottom : undefined
        anchors.right: parent.right
        anchors.topMargin: ModeService.currentHeight + 4
        anchors.bottomMargin: ModeService.currentHeight + 4
        anchors.rightMargin: 12

        width: panel.contentWidth + 32
        height: content.implicitHeight + 24
        color: Theme.base
        border.color: Theme.border
        border.width: 1

        MouseArea {
            anchors.fill: parent
            onClicked: {}   // absorb clicks on card
        }

        Column {
            id: content
            anchors.centerIn: parent
            spacing: 10

            // ── Status header ────────────────────────────────────
            Column {
                spacing: 2

                Text {
                    text: !BluetoothService.powered ? "bluetooth off"
                          : BluetoothService.anyConnected
                              ? BluetoothService.connectedDevices
                                    .map(d => d.name).join(", ")
                              : "no devices"
                    font.family: Theme.monoFont
                    font.pixelSize: 12
                    color: Theme.text1
                }

                Text {
                    text: BluetoothService.powered ? "power off" : "power on"
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                    color: Theme.text3

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        onClicked: BluetoothService.togglePower()
                    }
                }
            }

            // ── Paired devices ───────────────────────────────────
            Column {
                spacing: 6
                visible: BluetoothService.powered
                         && BluetoothService.pairedDevices.length > 0

                Text {
                    text: "paired"
                    font.family: Theme.monoFont
                    font.pixelSize: 10
                    color: Theme.text4
                }

                Repeater {
                    model: BluetoothService.pairedDevices

                    delegate: BtRow {
                        id: pairedRow
                        required property var modelData
                        name: pairedRow.modelData.name
                        mac: pairedRow.modelData.mac
                        connected: pairedRow.modelData.connected
                        onClicked: {
                            if (pairedRow.connected)
                                BluetoothService.disconnect(pairedRow.mac);
                            else
                                BluetoothService.connect(pairedRow.mac);
                        }
                    }
                }
            }

            // ── Nearby (scan results) ────────────────────────────
            Column {
                spacing: 6
                visible: BluetoothService.powered

                Text {
                    text: "nearby"
                    font.family: Theme.monoFont
                    font.pixelSize: 10
                    color: Theme.text4
                }

                Repeater {
                    model: BluetoothService.scanResults.slice(0, 8)

                    delegate: BtRow {
                        id: nearbyRow
                        required property var modelData
                        name: nearbyRow.modelData.name
                        mac: nearbyRow.modelData.mac
                        onClicked: BluetoothService.pair(nearbyRow.mac)
                    }
                }

                Text {
                    visible: BluetoothService.scanning
                    text: "scanning\u2026"
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                    color: Theme.text4
                }

                Text {
                    visible: BluetoothService.scanResults.length === 0
                                 && !BluetoothService.scanning
                    text: "no devices found"
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                    color: Theme.text4
                }

                Text {
                    text: BluetoothService.scanning ? "stop" : "scan"
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                    color: Theme.text3

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        onClicked: {
                            if (BluetoothService.scanning)
                                BluetoothService.stopScan();
                            else
                                BluetoothService.startScan();
                        }
                    }
                }
            }
        }
    }
}

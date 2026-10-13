import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Wayland
import ".."
import "../services"

/// Bluetooth dropdown — clickable bar bluetooth indicator.
///
/// Anchored-panel pattern (see NetworkPanel): transparent full-surface
/// PanelWindow catches outside clicks; the card anchors under the
/// bar's right edge. Pointer-only — no keyboard grab.
///
/// Sections: status header with power toggle, paired devices (click to
/// connect/disconnect, right-click to forget — confirmed), and nearby
/// devices from discovery, which runs while the panel is open (click to
/// trust + pair + connect; Just Works devices like AirPods, no PIN).
/// Rows bind to live BluetoothDevice objects from BluetoothService.
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

    /// Address of a paired device awaiting a second right-click to forget.
    property string _forgetAddress: ""

    onVisibleChanged: {
        BluetoothService.setPanelOpen(visible);
        if (!visible) panel._forgetAddress = "";
    }

    Connections {
        target: HookService
        function onBluetoothPanelToggled(screen) { panel._toggle(screen); }
        function onTrayToggled() { panel.visible = false; }  // one panel at a time
        function onNetworkPanelToggled() { panel.visible = false; }  // one panel at a time
    }

    /// Open on the clicked bar's screen (null = compositor's choice).
    function _toggle(screen) {
        if (!panel.visible) panel.screen = screen;
        panel.visible = !panel.visible;
    }

    // ── Shared row ───────────────────────────────────────────────────

    component BtRow: Item {
        id: row

        required property var device
        property bool forgettable: false
        signal clicked()

        readonly property bool busy: row.device.pairing
            || row.device.state === BluetoothDeviceState.Connecting
            || row.device.state === BluetoothDeviceState.Disconnecting
            || BluetoothService.pairingAddress === row.device.address
        readonly property bool showError: BluetoothService.errorAddress === row.device.address
        readonly property bool confirmingForget: panel._forgetAddress === row.device.address

        width: panel.contentWidth
        height: nameText.implicitHeight

        Text {
            id: nameText
            anchors.left: parent.left
            anchors.right: statusText.left
            anchors.rightMargin: Theme.space2
            text: row.device.name
            elide: Text.ElideRight
            font.family: Theme.sansFont
            font.pixelSize: Theme.fontBody
            color: row.device.connected ? Theme.text1 : Theme.text3
        }

        Text {
            id: statusText
            anchors.right: parent.right
            anchors.verticalCenter: nameText.verticalCenter
            width: Math.min(implicitWidth, row.width - 60)
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            text: row.busy ? "\u2026"
                : row.showError ? BluetoothService.errorText
                : row.confirmingForget ? "forget? right-click"
                : row.device.connected
                    ? (row.device.batteryAvailable
                        ? Math.round(row.device.battery * 100) + "%" : "connected")
                    : "\u2014"
            font.family: Theme.monoFont
            font.pixelSize: Theme.fontMeta
            color: row.busy ? Theme.text2
                : (row.showError || row.confirmingForget) ? Theme.urgent
                : row.device.connected ? Theme.ok : Theme.text4
        }

        MouseArea {
            anchors.fill: parent
            enabled: !row.busy
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => {
                if (mouse.button === Qt.RightButton && row.forgettable) {
                    if (panel._forgetAddress === row.device.address) {
                        panel._forgetAddress = "";
                        BluetoothService.forget(row.device);
                    } else {
                        panel._forgetAddress = row.device.address;
                    }
                    return;
                }
                panel._forgetAddress = "";
                row.clicked();
            }
        }
    }

    /// Small section label, with an optional action on the right.
    component SectionLabel: Item {
        id: section

        required property string label
        property string action: ""
        signal actionClicked()

        width: panel.contentWidth
        height: labelText.implicitHeight

        Text {
            id: labelText
            text: section.label
            font.family: Theme.monoFont
            font.pixelSize: Theme.fontCaption
            color: Theme.text4
        }

        Text {
            anchors.right: parent.right
            anchors.baseline: labelText.baseline
            visible: section.action !== ""
            text: section.action
            font.family: Theme.sansFont
            font.pixelSize: Theme.fontMeta
            color: actionArea.containsMouse ? Theme.text1 : Theme.text3

            MouseArea {
                id: actionArea
                anchors.fill: parent
                anchors.margins: -4
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: section.actionClicked()
            }
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
        anchors.topMargin: ModeService.panelOffset
        anchors.bottomMargin: ModeService.panelOffset
        anchors.rightMargin: Theme.space3

        width: panel.contentWidth + Theme.space4 * 2
        height: content.implicitHeight + Theme.space3 * 2
        color: Theme.base
        border.color: Theme.border
        border.width: 1

        // Absorb clicks on the card; a stray click cancels a pending forget.
        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            onClicked: panel._forgetAddress = ""
        }

        Column {
            id: content
            anchors.centerIn: parent
            spacing: 10

            // ── Status header ────────────────────────────────────
            Item {
                width: panel.contentWidth
                height: headerText.implicitHeight

                Text {
                    id: headerText
                    anchors.left: parent.left
                    anchors.right: powerText.left
                    anchors.rightMargin: Theme.space2
                    elide: Text.ElideRight
                    text: !BluetoothService.adapter ? "no adapter"
                        : !BluetoothService.powered ? "bluetooth off"
                        : BluetoothService.anyConnected
                            ? BluetoothService.connectedDevices.map(d => d.name).join(", ")
                            : "no devices"
                    font.family: Theme.sansFont
                    font.pixelSize: Theme.fontBody
                    color: Theme.text1
                }

                Text {
                    id: powerText
                    anchors.right: parent.right
                    anchors.baseline: headerText.baseline
                    visible: BluetoothService.adapter !== null
                    text: BluetoothService.powered ? "turn off" : "turn on"
                    font.family: Theme.sansFont
                    font.pixelSize: Theme.fontMeta
                    color: powerArea.containsMouse ? Theme.text1 : Theme.text3

                    MouseArea {
                        id: powerArea
                        anchors.fill: parent
                        anchors.margins: -4
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: BluetoothService.togglePower()
                    }
                }
            }

            // ── Paired devices ───────────────────────────────────
            Column {
                spacing: 6
                visible: BluetoothService.powered
                         && BluetoothService.pairedDevices.length > 0

                SectionLabel { label: "paired" }

                Repeater {
                    model: BluetoothService.pairedDevices

                    delegate: BtRow {
                        required property var modelData
                        device: modelData
                        forgettable: true
                        onClicked: {
                            if (modelData.connected) BluetoothService.disconnect(modelData);
                            else BluetoothService.connect(modelData);
                        }
                    }
                }
            }

            // ── Nearby (discovery) ───────────────────────────────
            Column {
                spacing: 6
                visible: BluetoothService.powered

                SectionLabel {
                    label: "nearby"
                    action: BluetoothService.scanning ? "stop" : "scan"
                    onActionClicked: {
                        if (BluetoothService.scanning) BluetoothService.stopScan();
                        else BluetoothService.startScan();
                    }
                }

                Repeater {
                    model: BluetoothService.nearbyDevices.slice(0, 8)

                    delegate: BtRow {
                        required property var modelData
                        device: modelData
                        onClicked: BluetoothService.pair(modelData)
                    }
                }

                Text {
                    visible: BluetoothService.nearbyDevices.length === 0
                    text: BluetoothService.scanning ? "scanning\u2026" : "no devices found"
                    font.family: Theme.monoFont
                    font.pixelSize: Theme.fontMeta
                    color: Theme.text4
                }
            }
        }
    }
}

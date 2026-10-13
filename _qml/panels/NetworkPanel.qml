import QtQuick
import Quickshell
import Quickshell.Networking
import Quickshell.Wayland
import ".."
import "../services"

/// Network dropdown — clickable bar network label.
///
/// Anchored-panel pattern (see TrayPanel): transparent full-surface
/// PanelWindow catches outside clicks; the card anchors under the
/// bar's right edge. Pointer-only — no keyboard grab, so no password
/// entry: known networks and open networks connect on click; unknown
/// secured networks are listed but not clickable.
///
/// Rows bind to NetworkService's live native objects (wired devices,
/// wifi networks); VPN rows are nmcli profiles.
///
/// Confirm idiom (PowerMenu second-click pattern) guards taking down
/// the last active link. Bringing a link back up is a local D-Bus call
/// to NetworkManager, so confirm guards accidents, not lockout.
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

    WlrLayershell.namespace: "garden-network"
    WlrLayershell.layer: WlrLayer.Overlay

    /// Fixed content width so names elide and the card doesn't jitter
    /// as scan results change; height stays content-driven.
    readonly property int contentWidth: 260

    /// Row key ("wifi:<name>" / "wired:<device>") awaiting a second
    /// click to confirm taking the link down.
    property string _confirmKey: ""

    onVisibleChanged: {
        NetworkService.setPanelOpen(visible);
        if (!visible) panel._confirmKey = "";
    }

    Connections {
        target: HookService
        function onNetworkPanelToggled(screen) { panel._toggle(screen); }
        function onTrayToggled() { panel.visible = false; }  // one panel at a time
        function onBluetoothPanelToggled() { panel.visible = false; }  // one panel at a time
    }

    /// Open on the clicked bar's screen (null = compositor's choice).
    function _toggle(screen) {
        if (!panel.visible) panel.screen = screen;
        panel.visible = !panel.visible;
    }

    // ── Behavior helpers ─────────────────────────────────────────────

    function _linkCount(): int {
        return (NetworkService.connectionType === "wifi" ? 1 : 0)
            + NetworkService.wiredDevices.filter(d => d.connected).length;
    }

    /// Run `down` unless it would drop the last link — then ask first.
    function _guardedDown(key: string, down) {
        if (panel._linkCount() <= 1 && panel._confirmKey !== key) {
            panel._confirmKey = key;
            return;
        }
        panel._confirmKey = "";
        down();
    }

    function _bars(strength: real): string {
        const pct = strength * 100;
        if (pct >= 75) return "\u2582\u2584\u2586\u2588";
        if (pct >= 50) return "\u2582\u2584\u2586";
        if (pct >= 25) return "\u2582\u2584";
        return "\u2582";
    }

    function _busy(state): bool {
        return state === ConnectionState.Connecting || state === ConnectionState.Disconnecting;
    }

    // ── Shared row ───────────────────────────────────────────────────

    /// Optional leading glyphs (signal bars), name, and a status slot.
    /// Error feedback lives in the status slot — text-first, no toasts.
    component NetRow: Item {
        id: row

        required property string name
        property string key: ""
        property string leading: ""
        property bool active: false
        property bool busy: false
        property bool clickable: true
        property color nameColor: row.active ? Theme.text1 : Theme.text3
        property string idleStatus: row.active ? "up" : "\u2014"
        signal clicked()

        readonly property bool showError: NetworkService.errorName === row.name
        readonly property bool confirming: row.key !== "" && panel._confirmKey === row.key

        width: panel.contentWidth
        height: nameText.implicitHeight

        Text {
            id: leadingText
            anchors.left: parent.left
            width: row.leading ? 34 : 0
            text: row.leading
            font.family: Theme.monoFont
            font.pixelSize: Theme.fontMeta
            color: Theme.text3
        }

        Text {
            id: nameText
            anchors.left: leadingText.right
            anchors.right: statusText.left
            anchors.rightMargin: Theme.space2
            text: row.name
            elide: Text.ElideRight
            font.family: Theme.sansFont
            font.pixelSize: Theme.fontBody
            color: row.nameColor
        }

        Text {
            id: statusText
            anchors.right: parent.right
            anchors.verticalCenter: nameText.verticalCenter
            width: Math.min(implicitWidth, row.width - 60)
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            text: row.busy ? "\u2026"
                : row.showError ? NetworkService.errorText
                : row.confirming ? "confirm down?"
                : row.idleStatus
            font.family: Theme.monoFont
            font.pixelSize: Theme.fontMeta
            color: row.busy ? Theme.text2
                : (row.showError || row.confirming) ? Theme.urgent
                : row.active ? Theme.ok : Theme.text4
        }

        MouseArea {
            anchors.fill: parent
            enabled: row.clickable && !row.busy
            cursorShape: Qt.PointingHandCursor
            onClicked: row.clicked()
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

    // Click-outside catcher — anything not on the card dismisses.
    MouseArea {
        anchors.fill: parent
        onClicked: panel.visible = false
    }

    Rectangle {
        id: card

        // Follow the bar edge (top or bottom per ConfigService).
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

        // Absorb clicks on the card so the catcher doesn't dismiss;
        // a stray card click also resets a pending confirm.
        MouseArea {
            anchors.fill: parent
            onClicked: panel._confirmKey = ""
        }

        Column {
            id: content
            anchors.centerIn: parent
            spacing: 10

            // ── Status header ────────────────────────────────────
            Column {
                spacing: 2

                Text {
                    text: NetworkService.connectionType === "wifi"
                              ? NetworkService.ssid + " \u2022 wifi"
                              : NetworkService.connectionType === "wired"
                                  ? "wired" : "offline"
                    font.family: Theme.sansFont
                    font.pixelSize: Theme.fontBody
                    color: Theme.text1
                }

                Text {
                    visible: NetworkService.connectivityIssue !== ""
                    text: NetworkService.connectivityIssue === "portal"
                        ? "captive portal \u00b7 sign in to continue"
                        : NetworkService.connectivityIssue
                    font.family: Theme.monoFont
                    font.pixelSize: Theme.fontMeta
                    color: Theme.urgent
                }

                Text {
                    visible: NetworkService.vpnActive
                    text: "vpn active"
                    font.family: Theme.monoFont
                    font.pixelSize: Theme.fontMeta
                    color: Theme.accent
                }
            }

            // ── Wired ────────────────────────────────────────────
            Column {
                spacing: 6
                visible: NetworkService.wiredDevices.length > 0

                SectionLabel { label: "wired" }

                Repeater {
                    model: NetworkService.wiredDevices

                    delegate: NetRow {
                        required property var modelData
                        name: modelData.network?.name || modelData.name
                        key: "wired:" + modelData.name
                        active: modelData.connected
                        busy: panel._busy(modelData.state)
                        clickable: modelData.connected || (modelData.hasLink && modelData.network !== null)
                        idleStatus: !modelData.hasLink ? "no link"
                            : modelData.connected ? "up" : "\u2014"
                        onClicked: {
                            if (modelData.connected)
                                panel._guardedDown(key, () => NetworkService.toggleWired(modelData));
                            else {
                                panel._confirmKey = "";
                                NetworkService.toggleWired(modelData);
                            }
                        }
                    }
                }
            }

            // ── Wifi (hidden on wifi-less machines) ──────────────
            Column {
                spacing: 6
                visible: NetworkService.wifiDevice !== null

                SectionLabel {
                    label: "wifi"
                    action: NetworkService.wifiEnabled ? "turn off" : "turn on"
                    onActionClicked: NetworkService.setWifiEnabled(!NetworkService.wifiEnabled)
                }

                Repeater {
                    model: NetworkService.wifiEnabled
                        ? NetworkService.wifiNetworks.slice(0, 8) : []

                    delegate: NetRow {
                        required property var modelData

                        readonly property bool _open: modelData.security === WifiSecurityType.Open

                        name: modelData.name + (_open ? "" : " *")
                        key: "wifi:" + modelData.name
                        leading: panel._bars(modelData.signalStrength)
                        active: modelData.connected
                        busy: modelData.stateChanging
                        // Unknown secured networks need a password —
                        // not enterable in a pointer-only panel.
                        clickable: modelData.connected || modelData.known || _open
                        nameColor: modelData.connected ? Theme.text1
                            : clickable ? Theme.text2 : Theme.text4
                        idleStatus: modelData.connected ? "up" : ""
                        onClicked: {
                            if (modelData.connected)
                                panel._guardedDown(key, () => NetworkService.disconnectNetwork(modelData));
                            else {
                                panel._confirmKey = "";
                                NetworkService.connectNetwork(modelData);
                            }
                        }
                    }
                }

                Text {
                    visible: NetworkService.wifiEnabled && NetworkService.wifiNetworks.length === 0
                    text: "searching\u2026"
                    font.family: Theme.monoFont
                    font.pixelSize: Theme.fontMeta
                    color: Theme.text4
                }
            }

            // ── VPN ──────────────────────────────────────────────
            Column {
                spacing: 6
                visible: NetworkService.vpnConnections.length > 0
                             || NetworkService.tailscaleUp

                SectionLabel { label: "vpn" }

                Repeater {
                    model: NetworkService.vpnConnections

                    // VPN down is never connectivity-fatal — no confirm.
                    delegate: NetRow {
                        required property var modelData
                        name: modelData.name
                        active: modelData.active
                        busy: NetworkService.busyVpn === modelData.name
                        onClicked: {
                            panel._confirmKey = "";
                            NetworkService.toggleVpn(modelData.name, modelData.active);
                        }
                    }
                }

                // Read-only — `tailscale up` may need a browser auth
                // flow, which a pointer-only panel can't host.
                NetRow {
                    visible: NetworkService.tailscaleUp
                    name: "tailscale"
                    active: true
                    clickable: false
                }
            }
        }
    }
}

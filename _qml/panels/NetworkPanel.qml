import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../services"

/// Network dropdown — clickable bar network label.
///
/// Anchored-panel pattern (see TrayPanel): transparent full-surface
/// PanelWindow catches outside clicks; the card anchors under the
/// bar's right edge. Pointer-only — no keyboard grab, which is why
/// scope is saved connections only: activating a known profile needs
/// no password entry. Unknown secured wifi networks are listed but
/// not clickable.
///
/// Confirm idiom (PowerMenu second-click pattern) guards deactivating
/// the last active link. Note `nmcli connection up` is a local D-Bus
/// call to NetworkManager, so the panel can restore the link even
/// while the network is down — confirm guards accidents, not lockout.
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

    /// Fixed content width so SSIDs elide and the card doesn't jitter
    /// as scan results change; height stays content-driven.
    readonly property int contentWidth: 260

    /// Connection name awaiting a second click to confirm `down`.
    property string _confirmName: ""

    onVisibleChanged: {
        NetworkService.setPanelOpen(visible);
        if (!visible) panel._confirmName = "";
    }

    Connections {
        target: HookService
        function onNetworkPanelToggled() { panel.visible = !panel.visible; }
    }

    // ── Behavior helpers ─────────────────────────────────────────────

    function _linkActiveCount() {
        return NetworkService.savedConnections.filter(c =>
            c.active && (c.type === "802-3-ethernet"
                         || c.type === "802-11-wireless")).length;
    }

    /// Up/down toggle for wired/wifi rows. Deactivating the last
    /// active link requires a confirming second click.
    function _toggleLink(name, active) {
        if (!active) {
            panel._confirmName = "";
            NetworkService.activate(name);
            return;
        }
        if (panel._linkActiveCount() <= 1 && panel._confirmName !== name) {
            panel._confirmName = name;
            return;
        }
        panel._confirmName = "";
        NetworkService.deactivate(name);
    }

    function _bars(sig) {
        if (sig >= 75) return "\u2582\u2584\u2586\u2588";
        if (sig >= 50) return "\u2582\u2584\u2586";
        if (sig >= 25) return "\u2582\u2584";
        return "\u2582";
    }

    // ── Shared row ───────────────────────────────────────────────────

    /// Name + status-slot row for saved connections and VPNs. Error
    /// feedback lives in the status slot — text-first, no toasts.
    component NetRow: Item {
        id: row

        required property string name
        property bool active: false
        property bool clickable: true
        signal toggled()

        readonly property bool busy: NetworkService.busyName === row.name
        readonly property bool showError:
            NetworkService.errorName === row.name
        readonly property bool confirming: panel._confirmName === row.name

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
            color: row.active ? Theme.text1 : Theme.text3
        }

        Text {
            id: statusText
            anchors.right: parent.right
            width: Math.min(implicitWidth, row.width - 40)
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            text: row.busy ? "\u2026"
                  : row.showError ? NetworkService.errorText
                  : row.confirming ? "confirm down?"
                  : row.active ? "up" : "\u2014"
            font.family: Theme.monoFont
            font.pixelSize: 11
            color: row.busy ? Theme.text2
                   : (row.showError || row.confirming) ? Theme.urgent
                   : row.active ? Theme.ok : Theme.text4
        }

        MouseArea {
            anchors.fill: parent
            enabled: row.clickable && !row.busy
            onClicked: row.toggled()
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
        anchors.topMargin: ModeService.currentHeight + 4
        anchors.bottomMargin: ModeService.currentHeight + 4
        anchors.rightMargin: 12

        width: panel.contentWidth + 32
        height: content.implicitHeight + 24
        color: Theme.base
        border.color: Theme.border
        border.width: 1

        // Absorb clicks on the card so the catcher doesn't dismiss;
        // a stray card click also resets a pending confirm.
        MouseArea {
            anchors.fill: parent
            onClicked: panel._confirmName = ""
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
                              ? NetworkService.ssid + " \u00b7 wifi"
                              : NetworkService.connectionType === "wired"
                                  ? "eth" : "offline"
                    font.family: Theme.monoFont
                    font.pixelSize: 12
                    color: Theme.text1
                }

                Text {
                    visible: NetworkService.vpnActive
                    text: "vpn active"
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                    color: Theme.accent
                }
            }

            // ── Saved connections (wired + wifi profiles) ────────
            Column {
                spacing: 6

                Text {
                    text: "connections"
                    font.family: Theme.monoFont
                    font.pixelSize: 10
                    color: Theme.text4
                }

                Repeater {
                    model: NetworkService.savedConnections.filter(c =>
                        c.type === "802-3-ethernet"
                        || c.type === "802-11-wireless")

                    delegate: NetRow {
                        id: connRow
                        required property var modelData
                        name: connRow.modelData.name
                        active: connRow.modelData.active
                        onToggled: panel._toggleLink(connRow.name,
                                                     connRow.active)
                    }
                }
            }

            // ── Wifi (hidden on wifi-less machines) ──────────────
            Column {
                spacing: 6
                visible: NetworkService.wifiDevice !== ""

                Text {
                    text: "wifi"
                    font.family: Theme.monoFont
                    font.pixelSize: 10
                    color: Theme.text4
                }

                Repeater {
                    model: NetworkService.wifiNetworks.slice(0, 8)

                    delegate: Item {
                        id: wifiRow

                        required property var modelData

                        readonly property bool busy:
                            NetworkService.busyName === wifiRow.modelData.ssid
                        readonly property bool confirming:
                            panel._confirmName === wifiRow.modelData.ssid
                        readonly property bool clickable:
                            wifiRow.modelData.inUse || wifiRow.modelData.known

                        width: panel.contentWidth
                        height: ssidText.implicitHeight

                        Text {
                            id: barsText
                            anchors.left: parent.left
                            width: 34
                            text: panel._bars(wifiRow.modelData.signal)
                            font.family: Theme.monoFont
                            font.pixelSize: 11
                            color: Theme.text3
                        }

                        Text {
                            id: ssidText
                            anchors.left: barsText.right
                            anchors.right: wifiStatus.left
                            anchors.rightMargin: 8
                            text: wifiRow.modelData.ssid
                                  + (wifiRow.modelData.secured ? " *" : "")
                            elide: Text.ElideRight
                            font.family: Theme.monoFont
                            font.pixelSize: 12
                            color: wifiRow.modelData.inUse ? Theme.text1
                                   : wifiRow.modelData.known ? Theme.text2
                                   : Theme.text4
                        }

                        Text {
                            id: wifiStatus
                            anchors.right: parent.right
                            text: wifiRow.busy ? "\u2026"
                                  : wifiRow.confirming ? "confirm down?" : ""
                            font.family: Theme.monoFont
                            font.pixelSize: 11
                            color: wifiRow.confirming
                                       ? Theme.urgent : Theme.text2
                        }

                        // Unknown secured networks aren't clickable —
                        // no password entry in a pointer-only panel.
                        MouseArea {
                            anchors.fill: parent
                            enabled: wifiRow.clickable && !wifiRow.busy
                            onClicked: {
                                if (wifiRow.modelData.inUse) {
                                    // NM profile name == SSID for
                                    // standard NM-created profiles.
                                    panel._toggleLink(
                                        wifiRow.modelData.ssid, true);
                                } else {
                                    panel._confirmName = "";
                                    // `connection up`, never `device
                                    // wifi connect` — the latter can
                                    // duplicate profiles.
                                    NetworkService.activate(
                                        wifiRow.modelData.ssid);
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: NetworkService.scanning
                    text: "scanning\u2026"
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                    color: Theme.text4
                }

                Text {
                    visible: NetworkService.wifiNetworks.length === 0
                                 && !NetworkService.scanning
                    text: "no networks"
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                    color: Theme.text4
                }

                Text {
                    text: "rescan"
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                    color: Theme.text3

                    MouseArea {
                        anchors.fill: parent
                        anchors.margins: -4
                        enabled: !NetworkService.scanning
                        onClicked: NetworkService.rescan()
                    }
                }
            }

            // ── VPN ──────────────────────────────────────────────
            Column {
                id: vpnSection
                spacing: 6

                readonly property var vpns:
                    NetworkService.savedConnections.filter(c =>
                        c.type === "vpn" || c.type === "wireguard")

                visible: vpnSection.vpns.length > 0
                             || NetworkService._tailscale

                Text {
                    text: "vpn"
                    font.family: Theme.monoFont
                    font.pixelSize: 10
                    color: Theme.text4
                }

                Repeater {
                    model: vpnSection.vpns

                    // VPN down is never connectivity-fatal — no confirm.
                    delegate: NetRow {
                        id: vpnRow
                        required property var modelData
                        name: vpnRow.modelData.name
                        active: vpnRow.modelData.active
                        onToggled: {
                            panel._confirmName = "";
                            if (vpnRow.active)
                                NetworkService.deactivate(vpnRow.name);
                            else
                                NetworkService.activate(vpnRow.name);
                        }
                    }
                }

                // Read-only — `tailscale up` may need a browser auth
                // flow, which a pointer-only panel can't host.
                Text {
                    visible: NetworkService._tailscale
                    text: "tailscale \u00b7 up"
                    font.family: Theme.monoFont
                    font.pixelSize: 12
                    color: Theme.text2
                }
            }
        }
    }
}

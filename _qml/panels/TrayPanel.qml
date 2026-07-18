import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.SystemTray
import ".."
import "../services"

/// System tray dropdown — spec Phase E3.
///
/// The bar shows a single dot when tray items exist; clicking it (or
/// `qs ipc call garden toggleTray`) opens this text dropdown under the
/// bar's right edge: one `name · status` line per item. Left click
/// activates the item and closes; right click (or left, for menu-only
/// appindicator items like nm-applet) opens its menu — rendered here
/// as themed text rows via QsMenuOpener, NOT the unstyled Qt platform
/// menu. `‹ back` pops one level; submenus drill down in place.
///
/// ── Anchored-panel pattern (fourth window kind) ──────────────────
/// NOT an OverlayBase. A transparent full-surface PanelWindow catches
/// outside clicks to dismiss; the card anchors to a bar-relative
/// corner. No keyboard grab, no dimming — pointer-only. NetworkPanel
/// and the calendar will reuse this shape.
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

    WlrLayershell.namespace: "garden-tray"
    WlrLayershell.layer: WlrLayer.Overlay

    /// Menu drill-down stack: [] = item list; last element is the
    /// QsMenuHandle (tray item menu or submenu entry) being shown.
    property var _menuPath: []

    onVisibleChanged: if (!visible) panel._menuPath = []

    Connections {
        target: HookService
        function onTrayToggled() { panel.visible = !panel.visible; }
    }

    QsMenuOpener {
        id: menuOpener
        menu: panel._menuPath.length > 0
                  ? panel._menuPath[panel._menuPath.length - 1] : null
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

        width: content.implicitWidth + 32
        height: content.implicitHeight + 24
        color: Theme.base
        border.color: Theme.border
        border.width: 1

        // Absorb clicks on the card so the catcher doesn't dismiss.
        MouseArea { anchors.fill: parent }

        Column {
            id: content
            anchors.centerIn: parent
            spacing: 6

            // ── Item list (menu closed) ──────────────────────────
            Column {
                visible: panel._menuPath.length === 0
                spacing: 6

                Repeater {
                    model: SystemTray.items

                    delegate: Text {
                        id: itemRow

                        required property var modelData

                        text: (itemRow.modelData.title || itemRow.modelData.id)
                              + " \u00b7 "
                              + panel._statusText(itemRow.modelData.status)
                        font.family: Theme.monoFont
                        font.pixelSize: 12
                        color: itemRow.modelData.status === Status.NeedsAttention
                                   ? Theme.urgent : Theme.text2

                        MouseArea {
                            anchors.fill: parent
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onClicked: (mouse) => {
                                // Menu-only items (appindicator style,
                                // e.g. nm-applet) have no Activate —
                                // left click opens the menu too.
                                if (mouse.button === Qt.RightButton
                                        || itemRow.modelData.onlyMenu) {
                                    panel._menuPath = [itemRow.modelData.menu];
                                } else {
                                    itemRow.modelData.activate();
                                    panel.visible = false;
                                }
                            }
                        }
                    }
                }

                Text {
                    visible: SystemTray.items.values.length === 0
                    text: "no tray items"
                    font.family: Theme.monoFont
                    font.pixelSize: 12
                    color: Theme.text4
                }
            }

            // ── Themed menu (drill-down) ─────────────────────────
            Column {
                id: menuColumn
                visible: panel._menuPath.length > 0
                spacing: 6

                Text {
                    text: "\u2039 back"
                    font.family: Theme.monoFont
                    font.pixelSize: 12
                    color: Theme.text4

                    MouseArea {
                        anchors.fill: parent
                        onClicked: panel._menuPath =
                            panel._menuPath.slice(0, -1)
                    }
                }

                Repeater {
                    model: menuOpener.children

                    delegate: Item {
                        id: entryRow

                        required property var modelData

                        // No width back-binding to the Column — the
                        // positioner sizes itself FROM child widths,
                        // so parent.width here is a binding loop that
                        // blows the layout past the card.
                        implicitWidth: entryText.visible
                                           ? entryText.width : 40
                        implicitHeight: entryRow.modelData.isSeparator
                                            ? 5 : entryText.implicitHeight

                        // Separator rule — spans the widest entry via
                        // the Column (safe: rule width doesn't feed
                        // back into this delegate's implicitWidth).
                        Rectangle {
                            visible: entryRow.modelData.isSeparator
                            anchors.verticalCenter: parent.verticalCenter
                            width: menuColumn.width
                            height: 1
                            color: Theme.borderSub
                        }

                        Text {
                            id: entryText
                            visible: !entryRow.modelData.isSeparator
                            width: Math.min(implicitWidth, 320)
                            elide: Text.ElideRight
                            text: panel._checkPrefix(entryRow.modelData)
                                  + entryRow.modelData.text
                                  + (entryRow.modelData.hasChildren
                                         ? " \u203a" : "")
                            font.family: Theme.monoFont
                            font.pixelSize: 12
                            color: entryRow.modelData.enabled
                                       ? Theme.text2 : Theme.text4

                            MouseArea {
                                anchors.fill: parent
                                enabled: entryRow.modelData.enabled
                                onClicked: {
                                    if (entryRow.modelData.hasChildren) {
                                        panel._menuPath = panel._menuPath
                                            .concat([entryRow.modelData]);
                                    } else {
                                        entryRow.modelData.triggered();
                                        panel.visible = false;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    function _statusText(s) {
        if (s === Status.Passive) return "passive";
        if (s === Status.Active) return "active";
        if (s === Status.NeedsAttention) return "attention";
        return String(s);
    }

    function _checkPrefix(entry) {
        if (entry.buttonType === QsMenuButtonType.CheckBox)
            return entry.checkState === Qt.Checked ? "[x] " : "[ ] ";
        if (entry.buttonType === QsMenuButtonType.RadioButton)
            return entry.checkState === Qt.Checked ? "(\u00b7) " : "( ) ";
        return "";
    }
}

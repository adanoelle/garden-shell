import QtQuick
import Quickshell
import ".."
import "../components"
import "../services"

/// Settings panel overlay (Super+,).
///
/// Full-screen overlay with dithered backdrop, tab bar (palette / keybinds),
/// and scrollable content area.
OverlayBase {
    id: settings

    _namespace:    "garden-settings"
    contentTarget: content
    slideTarget:   contentSlide

    // ── State ───────────────────────────────────────────────────────

    property string _activeTab: "palette"

    // ── Toggle ──────────────────────────────────────────────────────

    Connections {
        target: HookService
        function onSettingsToggled() { settings._toggle(); }
    }

    // ── Lifecycle hooks ─────────────────────────────────────────────

    function _onBeforeShow() {
        settings._activeTab = "palette";
        keyHandler.forceActiveFocus();
    }

    function _onBeforeClose() {
        // Auto-discard unsaved palette edits.
        paletteEditor._discardEdits();
    }

    // ── Keyboard ────────────────────────────────────────────────────

    FocusScope {
        id: keyHandler
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: {
            if (paletteEditor.dropdownOpen)
                paletteEditor.closeDropdown();
            else
                settings._close();
        }
    }

    // ── Content ─────────────────────────────────────────────────────

    Column {
        id: content
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: 640
        spacing: 0
        opacity: 0

        transform: Translate { id: contentSlide; y: 20 }

        // Main panel.
        Rectangle {
            id: panelRect
            width: parent.width
            height: panelContent.height + 2
            color: Theme.base
            border.color: Theme.border
            border.width: 1

            // Prevent clicks inside the panel from closing the overlay.
            MouseArea {
                anchors.fill: parent
                onClicked: (event) => event.accepted = true
            }

            // Dropdown backdrop: closes palette dropdown when clicking outside it.
            MouseArea {
                anchors.fill: parent
                visible: paletteEditor.dropdownOpen
                z: 50
                onClicked: paletteEditor.closeDropdown()
            }

            Column {
                id: panelContent
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 1

                // ── Tab bar ─────────────────────────────────────────

                Item {
                    width: parent.width
                    height: 40

                    Row {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 4

                        // Palette tab.
                        Rectangle {
                            width: paletteTabText.width + 20
                            height: 28
                            color: settings._activeTab === "palette"
                                ? Theme.baseHl : "transparent"

                            Text {
                                id: paletteTabText
                                anchors.centerIn: parent
                                text: "palette"
                                color: settings._activeTab === "palette"
                                    ? Theme.text1 : Theme.text3
                                font.family: Theme.monoFont
                                font.pixelSize: 12
                                font.weight: settings._activeTab === "palette"
                                    ? Font.DemiBold : Font.Normal
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: settings._activeTab = "palette"
                            }
                        }

                        // Keybinds tab.
                        Rectangle {
                            width: keybindsTabText.width + 20
                            height: 28
                            color: settings._activeTab === "keybinds"
                                ? Theme.baseHl : "transparent"

                            Text {
                                id: keybindsTabText
                                anchors.centerIn: parent
                                text: "keybinds"
                                color: settings._activeTab === "keybinds"
                                    ? Theme.text1 : Theme.text3
                                font.family: Theme.monoFont
                                font.pixelSize: 12
                                font.weight: settings._activeTab === "keybinds"
                                    ? Font.DemiBold : Font.Normal
                            }

                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onClicked: settings._activeTab = "keybinds"
                            }
                        }
                    }

                    // Title on the right side.
                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "settings"
                        color: Theme.text4
                        font.family: Theme.monoFont
                        font.pixelSize: 11
                    }
                }

                // Tab bar separator.
                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.borderSub
                }

                // ── Tab content (scrollable) ────────────────────────

                Flickable {
                    id: scrollArea
                    width: parent.width
                    height: Math.min(contentHeight, settings.height - 160)
                    contentHeight: tabLoader.height
                    clip: true
                    flickableDirection: Flickable.VerticalFlick
                    boundsBehavior: Flickable.StopAtBounds
                    onContentYChanged: paletteEditor.closeDropdown()

                    Item {
                        id: tabLoader
                        width: parent.width
                        height: settings._activeTab === "palette"
                            ? paletteEditor.height + 24
                            : keybindsPlaceholder.height + 24

                        // Palette editor (always loaded, visibility toggled).
                        PaletteEditor {
                            id: paletteEditor
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 12
                            visible: settings._activeTab === "palette"
                            popupParent: panelRect
                        }

                        // Keybinds placeholder.
                        KeybindsPlaceholder {
                            id: keybindsPlaceholder
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 12
                            visible: settings._activeTab === "keybinds"
                        }
                    }
                }
            }
        }

        HintLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Esc close"
        }
    }
}

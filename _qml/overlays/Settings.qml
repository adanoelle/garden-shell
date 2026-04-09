import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../services"

/// Settings panel overlay (Super+,).
///
/// Full-screen overlay with dithered backdrop, tab bar (palette / keybinds),
/// and scrollable content area. Follows the same pattern as Launcher.qml
/// and ChannelSwitcher.qml.
PanelWindow {
    id: settings

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    visible: false
    color: "transparent"
    focusable: true
    exclusiveZone: 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "garden-settings"

    // ── State ───────────────────────────────────────────────────────

    property bool _open: false
    property string _activeTab: "palette"

    // ── Toggle ──────────────────────────────────────────────────────

    Connections {
        target: HookService
        function onSettingsToggled() { settings._toggle(); }
    }

    function _toggle() {
        if (_open) _close();
        else _show();
    }

    function _show() {
        _open = true;
        content.opacity = 0;
        contentSlide.y = 20;
        _activeTab = "palette";
        visible = true;
        keyHandler.forceActiveFocus();
        showAnim.start();
    }

    function _close() {
        if (!_open) return;
        // Auto-discard unsaved palette edits.
        paletteEditor._discardEdits();
        hideAnim.start();
    }

    // ── Animations ──────────────────────────────────────────────────

    ParallelAnimation {
        id: showAnim

        NumberAnimation {
            target: content; property: "opacity"
            to: 1; duration: 200; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: contentSlide; property: "y"
            to: 0; duration: 200; easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: hideAnim

        NumberAnimation {
            target: content; property: "opacity"
            to: 0; duration: 200; easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: contentSlide; property: "y"
            to: 20; duration: 200; easing.type: Easing.InCubic
        }

        onFinished: {
            settings._open = false;
            settings.visible = false;
        }
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

    // ── Backdrop ────────────────────────────────────────────────────

    DitherOverlay { density: "dense" }

    MouseArea {
        anchors.fill: parent
        onClicked: settings._close()
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

        // Hint text.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: hintText.width + 16
            height: hintText.height + 8
            radius: 3
            color: Theme.base
            border.color: Theme.borderSub
            border.width: 1

            Text {
                id: hintText
                anchors.centerIn: parent
                text: "Esc close"
                color: Theme.text3
                font.family: Theme.monoFont
                font.pixelSize: 11
            }
        }
    }
}

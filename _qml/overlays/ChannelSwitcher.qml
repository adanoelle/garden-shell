import QtQuick
import Quickshell
import Quickshell.Wayland
import ".."
import "../compositor"
import "../services"

/// Channel (workspace) switcher overlay (Super+Tab).
///
/// Shows all workspaces with their windows. Triggered via
/// `qs ipc call garden toggleSwitcher` or HookService.switcherToggled signal.
PanelWindow {
    id: switcher

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
    WlrLayershell.namespace: "garden-switcher"

    // ── State ─────────────────────────────────────────────────────────

    property bool _open: false
    property int _selectedIndex: 0

    // ── Toggle ────────────────────────────────────────────────────────

    Connections {
        target: HookService
        function onSwitcherToggled() { switcher._toggle(); }
    }

    function _toggle() {
        if (_open) _close();
        else _show();
    }

    function _show() {
        _open = true;
        content.opacity = 0;
        contentSlide.y = 20;
        // Pre-select the active workspace.
        const ws = CompositorService.workspaces;
        _selectedIndex = 0;
        for (let i = 0; i < ws.length; i++) {
            if (ws[i].active) { _selectedIndex = i; break; }
        }
        visible = true;
        keyHandler.forceActiveFocus();
        showAnim.start();
    }

    function _close() {
        if (!_open) return;
        hideAnim.start();
    }

    function _switchToSelected() {
        const ws = CompositorService.workspaces;
        if (_selectedIndex >= 0 && _selectedIndex < ws.length) {
            CompositorService.focusWorkspace(ws[_selectedIndex].name);
        }
        _close();
    }

    // ── Animations ────────────────────────────────────────────────────

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
            switcher._open = false;
            switcher.visible = false;
        }
    }

    // ── Keyboard ──────────────────────────────────────────────────────

    FocusScope {
        id: keyHandler
        anchors.fill: parent
        focus: true

        Keys.onEscapePressed: switcher._close()

        Keys.onUpPressed: {
            if (switcher._selectedIndex > 0) switcher._selectedIndex--;
        }

        Keys.onDownPressed: {
            const ws = CompositorService.workspaces;
            if (switcher._selectedIndex < ws.length - 1) switcher._selectedIndex++;
        }

        Keys.onReturnPressed: switcher._switchToSelected()
    }

    // ── Backdrop ──────────────────────────────────────────────────────

    DitherOverlay { density: "dense" }

    MouseArea {
        anchors.fill: parent
        onClicked: switcher._close()
    }

    // ── Content ───────────────────────────────────────────────────────

    Column {
        id: content
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: 420
        spacing: 8
        opacity: 0

        transform: Translate { id: contentSlide; y: 20 }

        // Main panel.
        Rectangle {
            width: parent.width
            height: channelList.height + 2
            color: Theme.base
            border.color: Theme.border
            border.width: 1

            Column {
                id: channelList
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 1

                Repeater {
                    model: CompositorService.workspaces

                    delegate: Rectangle {
                        id: channelDelegate
                        required property var modelData
                        required property int index

                        width: channelList.width
                        height: channelCol.height + 16
                        color: index === switcher._selectedIndex
                            ? Theme.baseHl : "transparent"

                        Column {
                            id: channelCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 2

                            // Channel name row.
                            Item {
                                width: parent.width
                                height: channelName.height

                                Text {
                                    id: channelName
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: channelDelegate.modelData.name
                                    color: Theme.text1
                                    font.family: Theme.sansFont
                                    font.pixelSize: 14
                                    font.bold: channelDelegate.modelData.active
                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: {
                                        const n = channelDelegate.modelData.columnCount;
                                        return n + (n === 1 ? " col" : " cols");
                                    }
                                    color: Theme.text3
                                    font.family: Theme.monoFont
                                    font.pixelSize: 11
                                }
                            }

                            // Window labels row (only when workspace has windows).
                            Row {
                                spacing: 6
                                visible: channelDelegate.modelData.columnCount > 0

                                Repeater {
                                    model: {
                                        const wsId = NiriAdapter.workspaceId(
                                            channelDelegate.modelData.name);
                                        if (wsId < 0) return [];
                                        return NiriAdapter.windowsForWorkspace(wsId);
                                    }

                                    delegate: Text {
                                        required property var modelData

                                        text: {
                                            const prefix = modelData.isFocused
                                                && channelDelegate.modelData.active
                                                ? "\u25cf" : "";
                                            const label = modelData.appId
                                                || modelData.title.split(" ")[0]
                                                || "\u00b7";
                                            return prefix + label;
                                        }
                                        color: modelData.isFocused
                                            && channelDelegate.modelData.active
                                            ? Theme.text1 : Theme.text4
                                        font.family: Theme.monoFont
                                        font.pixelSize: 11
                                        elide: Text.ElideRight
                                        maximumLineCount: 1
                                    }
                                }
                            }
                        }

                        // Separator between channels.
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            height: channelDelegate.index < CompositorService.workspaces.length - 1
                                ? 1 : 0
                            color: Theme.borderSub
                            visible: height > 0
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                switcher._selectedIndex = channelDelegate.index;
                                switcher._switchToSelected();
                            }
                        }
                    }
                }
            }
        }

        // Hint text with background for readability over dither.
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
                text: "Esc close  \u00b7  \u2191\u2193 select  \u00b7  \u21b5 switch"
                color: Theme.text3
                font.family: Theme.monoFont
                font.pixelSize: 11
            }
        }
    }
}

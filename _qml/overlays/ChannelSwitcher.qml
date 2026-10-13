import QtQuick
import Quickshell
import ".."
import "../components"
import "../compositor"
import "../services"

/// Channel (workspace) switcher overlay (Super+Tab).
///
/// Shows all workspaces with their windows. Triggered via
/// `qs ipc call garden toggleSwitcher` or HookService.switcherToggled signal.
OverlayBase {
    id: switcher

    _namespace:    "garden-switcher"
    contentTarget: content
    slideTarget:   contentSlide

    // ── State ─────────────────────────────────────────────────────────

    property int _selectedIndex: 0

    /// Workspaces worth listing: named ones, plus unnamed ones holding
    /// windows (skips niri's trailing empty workspace per output).
    readonly property var _items: CompositorService.workspaces
        .filter(w => w.name || w.windowCount > 0)

    readonly property bool _multiOutput:
        Object.keys(CompositorService.outputs).length > 1

    // ── Toggle ────────────────────────────────────────────────────────

    Connections {
        target: HookService
        function onSwitcherToggled() { switcher._toggle(); }
    }

    // ── Show-init hook ────────────────────────────────────────────────

    function _onBeforeShow() {
        // Pre-select the focused workspace.
        const i = switcher._items.findIndex(w => w.focused);
        switcher._selectedIndex = Math.max(0, i);
        keyHandler.forceActiveFocus();
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
            if (switcher._selectedIndex < switcher._items.length - 1)
                switcher._selectedIndex++;
        }

        Keys.onReturnPressed: switcher._switchToSelected()
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
                    model: switcher._items

                    delegate: Rectangle {
                        id: channelDelegate
                        required property var modelData
                        required property int index

                        width: channelList.width
                        height: channelCol.height + 16
                        color: index === switcher._selectedIndex
                            ? Theme.baseHl : "transparent"

                        // Selected left bar (ResultItem idiom).
                        Rectangle {
                            width: 2
                            height: parent.height
                            color: Theme.accent
                            visible: channelDelegate.index === switcher._selectedIndex
                        }

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
                                    text: channelDelegate.modelData.label
                                    color: Theme.text1
                                    font.family: Theme.sansFont
                                    font.pixelSize: Theme.fontLarge
                                    font.weight: channelDelegate.modelData.focused
                                        ? Font.DemiBold : Font.Normal
                                }

                                Text {
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: {
                                        const ws = channelDelegate.modelData;
                                        const n = ws.columns.length;
                                        const f = ws.floating.length;
                                        const pages = n + (n === 1 ? " page" : " pages")
                                            + (f > 0 ? " +" + f : "");
                                        return switcher._multiOutput
                                            ? ws.output + " \u00b7 " + pages : pages;
                                    }
                                    color: Theme.text3
                                    font.family: Theme.monoFont
                                    font.pixelSize: Theme.fontMeta
                                }
                            }

                            // Pages in strip order, then floating windows.
                            // Flow wraps instead of running past the panel.
                            Flow {
                                width: parent.width
                                spacing: Theme.space2
                                visible: channelDelegate.modelData.windowCount > 0

                                Repeater {
                                    model: channelDelegate.modelData.columns
                                        .concat(channelDelegate.modelData.floating)

                                    delegate: Text {
                                        required property var modelData

                                        readonly property bool _here: modelData.focused
                                            && channelDelegate.modelData.focused

                                        text: (_here ? "\u25cf " : "")
                                            + ConfigService.appLabel(modelData.appId, modelData.title)
                                            + (modelData.tiles > 1 ? " \u00d7" + modelData.tiles : "")
                                        color: _here ? Theme.text1
                                            : modelData.active ? Theme.text2 : Theme.text3
                                        font.family: Theme.sansFont
                                        font.pixelSize: Theme.fontBody
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
                            height: channelDelegate.index < switcher._items.length - 1
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

        HintLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Esc close  \u00b7  \u2191\u2193 select  \u00b7  \u21b5 switch"
        }
    }

    // ── Switch to selected workspace ──────────────────────────────────

    function _switchToSelected() {
        const ws = switcher._items;
        if (_selectedIndex >= 0 && _selectedIndex < ws.length) {
            CompositorService.focusWorkspaceEntry(ws[_selectedIndex]);
        }
        _close();
    }
}

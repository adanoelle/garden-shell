import QtQuick
import ".."

/// Read-only keybinds reference showing all niri keybinds organized by category.
Item {
    id: root
    width: parent ? parent.width : 400
    height: mainCol.height

    readonly property var _sections: [
        {
            label: "navigation",
            binds: [
                { key: "Mod+H", action: "focus left" },
                { key: "Mod+J", action: "focus down" },
                { key: "Mod+K", action: "focus up" },
                { key: "Mod+L", action: "focus right" },
                { key: "Mod+Scroll", action: "focus column" },
            ]
        },
        {
            label: "move windows",
            binds: [
                { key: "Mod+Shift+H", action: "move left" },
                { key: "Mod+Shift+J", action: "move down" },
                { key: "Mod+Shift+K", action: "move up" },
                { key: "Mod+Shift+L", action: "move right" },
            ]
        },
        {
            label: "channels",
            binds: [
                { key: "Mod+1–5", action: "focus channel" },
                { key: "Mod+Shift+1–5", action: "move to channel" },
                { key: "Mod+Shift+Tab", action: "previous channel" },
            ]
        },
        {
            label: "layout",
            binds: [
                { key: "Mod+[", action: "consume / expel left" },
                { key: "Mod+]", action: "consume / expel right" },
                { key: "Mod+=", action: "wider (+10%)" },
                { key: "Mod+−", action: "narrower (−10%)" },
                { key: "Mod+F", action: "maximize column" },
                { key: "Mod+Shift+F", action: "fullscreen" },
                { key: "Mod+R", action: "cycle preset width" },
                { key: "Mod+V", action: "toggle floating" },
            ]
        },
        {
            label: "spawn",
            binds: [
                { key: "Mod+N", action: "terminal" },
                { key: "Mod+B", action: "browser" },
            ]
        },
        {
            label: "screenshots",
            binds: [
                { key: "Mod+S", action: "region" },
                { key: "Mod+Shift+S", action: "window" },
                { key: "Mod+Ctrl+S", action: "screen" },
            ]
        },
        {
            label: "overlays",
            binds: [
                { key: "Mod+/", action: "launcher" },
                { key: "Mod+Tab", action: "switcher" },
                { key: "Mod+,", action: "settings" },
                { key: "Mod+Shift+N", action: "notifications" },
                { key: "Mod+Shift+M", action: "notification center" },
                { key: "Mod+Escape", action: "power menu" },
            ]
        },
        {
            label: "media",
            binds: [
                { key: "Brightness Up", action: "brightness +5" },
                { key: "Brightness Down", action: "brightness −5" },
            ]
        },
        {
            label: "session",
            binds: [
                { key: "Mod+A", action: "overview" },
                { key: "Mod+Shift+Q", action: "close window" },
                { key: "Mod+Shift+/", action: "hotkey overlay" },
                { key: "Mod+Alt+L", action: "lock" },
                { key: "Mod+Shift+E", action: "quit niri" },
            ]
        },
    ]

    Column {
        id: mainCol
        anchors.left: parent.left
        anchors.right: parent.right
        spacing: 16
        topPadding: 4

        Repeater {
            model: root._sections

            Column {
                id: sectionDelegate
                required property var modelData
                width: mainCol.width
                spacing: 4

                // Section header.
                Text {
                    text: sectionDelegate.modelData.label
                    color: Theme.text2
                    font.family: Theme.sansFont
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    bottomPadding: 2
                }

                // Keybind rows.
                Repeater {
                    model: sectionDelegate.modelData.binds

                    Item {
                        id: bindRow
                        required property var modelData
                        width: sectionDelegate.width
                        height: 26

                        // Key pills.
                        Row {
                            id: keyPills
                            anchors.left: parent.left
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Repeater {
                                model: bindRow.modelData.key.split("+")

                                Rectangle {
                                    required property var modelData
                                    width: pillText.width + 12
                                    height: 20
                                    radius: 4
                                    color: Theme.baseRaised
                                    border.color: Theme.borderSub
                                    border.width: 1

                                    Text {
                                        id: pillText
                                        anchors.centerIn: parent
                                        text: modelData
                                        color: Theme.text2
                                        font.family: Theme.monoFont
                                        font.pixelSize: 11
                                    }
                                }
                            }
                        }

                        // Action description.
                        Text {
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            text: bindRow.modelData.action
                            color: Theme.text3
                            font.family: Theme.monoFont
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }
}

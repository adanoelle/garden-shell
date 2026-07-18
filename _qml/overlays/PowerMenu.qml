import QtQuick
import Quickshell.Io
import ".."
import "../components"
import "../services"

/// Power menu overlay (Super+Escape) — spec §10.
///
/// Horizontal text row `lock · suspend · logout · reboot · shutdown`.
/// Left/right (or h/l) + Enter to act; destructive actions (logout,
/// reboot, shutdown) require a second Enter — the label swaps to
/// "confirm <action>?" in urgent. Esc cancels a pending confirm, then
/// closes. Toggled via `qs ipc call garden togglePowerMenu`.
OverlayBase {
    id: menu

    _namespace:    "garden-power"
    animDuration:  200
    contentTarget: content
    slideTarget:   contentSlide

    // ── Actions ───────────────────────────────────────────────────────

    readonly property var actions: [
        { name: "lock",     destructive: false },
        { name: "suspend",  destructive: false },
        { name: "logout",   destructive: true  },
        { name: "reboot",   destructive: true  },
        { name: "shutdown", destructive: true  }
    ]

    property int _selectedIndex: 0

    /// Index of the destructive action awaiting its second Enter (-1 = none).
    property int _confirmIndex: -1

    /// True briefly after a spawned command fails (e.g. polkit denial) —
    /// flashes the panel border urgent so failures aren't silent.
    property bool _failed: false

    // ── Toggle ────────────────────────────────────────────────────────

    Connections {
        target: HookService
        function onPowerMenuToggled() { menu._toggle(); }
    }

    // ── Show-init hook ────────────────────────────────────────────────

    function _onBeforeShow() {
        menu._selectedIndex = 0;
        menu._confirmIndex = -1;
        menu._failed = false;
        keyHandler.forceActiveFocus();
    }

    // ── Activation ────────────────────────────────────────────────────

    function _activate(index) {
        const action = menu.actions[index];

        if (action.destructive && menu._confirmIndex !== index) {
            menu._confirmIndex = index;
            return;
        }

        switch (action.name) {
        case "lock":
            menu._close();
            HookService.lockRequested();
            break;
        case "suspend":
            menu._close();
            menu._run(["systemctl", "suspend"]);
            break;
        case "logout":
            // Our menu already confirmed; skip niri's own prompt.
            menu._run(["niri", "msg", "action", "quit", "--skip-confirmation"]);
            break;
        case "reboot":
            menu._run(["systemctl", "reboot"]);
            break;
        case "shutdown":
            menu._run(["systemctl", "poweroff"]);
            break;
        }
    }

    Process {
        id: actionProcess
        running: false

        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) return;
            console.warn("PowerMenu: command failed (exit " + exitCode + "):",
                         actionProcess.command.join(" "));
            if (menu._open) {
                menu._confirmIndex = -1;
                menu._failed = true;
                failedClear.restart();
            }
        }
    }

    Timer {
        id: failedClear
        interval: 1200
        onTriggered: menu._failed = false
    }

    function _run(cmd) {
        actionProcess.command = cmd;
        actionProcess.running = true;
    }

    // ── Content ───────────────────────────────────────────────────────

    Column {
        id: content
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        opacity: 0

        transform: Translate { id: contentSlide; y: 20 }

        // Key handling lives on a dedicated zero-size focus item — the
        // overlay has no text input to hang Keys off (cf. NotificationCenter).
        Item {
            id: keyHandler
            width: 0
            height: 0
            focus: true

            Keys.onEscapePressed: {
                if (menu._confirmIndex >= 0) menu._confirmIndex = -1;
                else menu._close();
            }

            Keys.onPressed: (event) => {
                switch (event.key) {
                case Qt.Key_Left:
                case Qt.Key_H:
                    if (menu._selectedIndex > 0) menu._selectedIndex--;
                    menu._confirmIndex = -1;
                    event.accepted = true;
                    break;
                case Qt.Key_Right:
                case Qt.Key_L:
                    if (menu._selectedIndex < menu.actions.length - 1)
                        menu._selectedIndex++;
                    menu._confirmIndex = -1;
                    event.accepted = true;
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    menu._activate(menu._selectedIndex);
                    event.accepted = true;
                    break;
                }
            }
        }

        // Main panel.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: actionRow.implicitWidth + 48
            height: 52
            color: Theme.base
            border.color: menu._failed ? Theme.urgent : Theme.border
            border.width: 1

            Row {
                id: actionRow
                anchors.centerIn: parent
                spacing: 12

                Repeater {
                    model: menu.actions

                    delegate: Row {
                        id: actionDelegate

                        required property var modelData
                        required property int index

                        spacing: 12

                        Text {
                            text: actionDelegate.index === menu._confirmIndex
                                ? "confirm " + actionDelegate.modelData.name + "?"
                                : actionDelegate.modelData.name
                            color: actionDelegate.index === menu._confirmIndex
                                ? Theme.urgent
                                : actionDelegate.index === menu._selectedIndex
                                    ? Theme.text1 : Theme.text3
                            font.family: Theme.monoFont
                            font.pixelSize: 14
                            font.bold: actionDelegate.index === menu._selectedIndex

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    menu._selectedIndex = actionDelegate.index;
                                    menu._activate(actionDelegate.index);
                                }
                            }
                        }

                        // Separator dot between actions.
                        Text {
                            visible: actionDelegate.index < menu.actions.length - 1
                            text: "\u00b7"
                            color: Theme.text4
                            font.family: Theme.monoFont
                            font.pixelSize: 14
                        }
                    }
                }
            }
        }

        HintLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Esc close  \u00b7  \u2190\u2192 select  \u00b7  \u21b5 confirm"
        }
    }
}

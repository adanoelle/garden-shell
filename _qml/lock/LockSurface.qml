import QtQuick
import Quickshell.Wayland
import ".."
import "../overlays"

/// Per-screen lock surface (spec §7). Instantiated by LockScreen's
/// WlSessionLock, once per connected screen. All auth state lives on
/// `context` (the LockScreen Scope) so surfaces stay in sync.
WlSessionLockSurface {
    id: surface

    required property var context

    color: Theme.baseDeep

    // Sparse cream dither texture — the "lock" density preset.
    // Dimmed: full-opacity cream dots compete with the (same-colored) text.
    DitherOverlay {
        density: "lock"
        baseColor: Theme.text1
        opacity: 0.4
    }

    // Clearing card behind the clock/login block — surface-colored fill
    // masks dither dots where text needs to be read; subtle border makes
    // it read as a panel.
    Rectangle {
        anchors.fill: contentColumn
        anchors.margins: -48
        color: Theme.baseDeep
        border.color: Theme.borderSub
        border.width: 1
    }

    // ── Clock state ─────────────────────────────────────────────────

    property string _timeStr: ""
    property string _secStr: ""
    property string _dateStr: ""

    Timer {
        running: true
        repeat: true
        interval: 1000
        triggeredOnStart: true
        onTriggered: surface._updateTime()
    }

    function _updateTime() {
        const now = new Date();
        surface._timeStr = String(now.getHours()).padStart(2, "0")
            + ":" + String(now.getMinutes()).padStart(2, "0");
        surface._secStr = String(now.getSeconds()).padStart(2, "0");

        const days = ["sunday", "monday", "tuesday", "wednesday",
                      "thursday", "friday", "saturday"];
        const months = ["january", "february", "march", "april", "may",
                        "june", "july", "august", "september", "october",
                        "november", "december"];
        surface._dateStr = days[now.getDay()] + " \u00b7 "
            + months[now.getMonth()] + " " + now.getDate();
    }

    // ── Failure feedback state ──────────────────────────────────────

    property bool _showFailed: false

    Connections {
        target: surface.context
        function onAuthFailed() {
            surface._showFailed = true;
            shakeAnim.restart();
            failedClear.restart();
        }
    }

    Timer {
        id: failedClear
        interval: 1200
        onTriggered: surface._showFailed = false
    }

    // ── Content ─────────────────────────────────────────────────────

    Column {
        id: contentColumn
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: -40
        spacing: 0

        // Clock: 96px mono w300 text-1 @ 0.9; seconds 40px text-3 @ 0.4.
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 12

            Text {
                id: clockText
                text: surface._timeStr
                color: Theme.text1
                opacity: 0.9
                font.family: Theme.monoFont
                font.pixelSize: 96
                font.weight: 300
            }

            Text {
                anchors.baseline: clockText.baseline
                text: surface._secStr
                color: Theme.text3
                opacity: 0.4
                font.family: Theme.monoFont
                font.pixelSize: 40
                font.weight: 300
            }
        }

        // Date: 13px, wide letter-spacing, lowercase.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: surface._dateStr
            color: Theme.text2
            font.family: Theme.monoFont
            font.pixelSize: 13
            font.letterSpacing: 3
        }

        Item { width: 1; height: 72 }

        // Login block: ada@nix → bordered input → "press enter" hint.
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "ada@nix"
            color: Theme.text3
            font.family: Theme.monoFont
            font.pixelSize: 12
        }

        Item { width: 1; height: 12 }

        Rectangle {
            id: inputBox
            anchors.horizontalCenter: parent.horizontalCenter
            width: 240
            height: 34
            color: "transparent"
            border.width: 1
            border.color: surface._showFailed ? Theme.urgent : Theme.border

            transform: Translate { id: shakeT }

            SequentialAnimation {
                id: shakeAnim
                NumberAnimation { target: shakeT; property: "x"; to: -8; duration: 40 }
                NumberAnimation { target: shakeT; property: "x"; to: 8;  duration: 70 }
                NumberAnimation { target: shakeT; property: "x"; to: -5; duration: 70 }
                NumberAnimation { target: shakeT; property: "x"; to: 5;  duration: 70 }
                NumberAnimation { target: shakeT; property: "x"; to: 0;  duration: 50 }
            }

            TextInput {
                id: passwordField
                anchors.fill: parent
                anchors.leftMargin: 10
                anchors.rightMargin: 10
                focus: true
                echoMode: TextInput.Password
                passwordCharacter: "\u00b7"
                readOnly: surface.context.authenticating
                color: Theme.text1
                font.family: Theme.monoFont
                font.pixelSize: 14
                verticalAlignment: TextInput.AlignVCenter
                clip: true

                onTextChanged: {
                    if (surface.context.password !== text)
                        surface.context.password = text;
                }

                onAccepted: surface.context.submit()

                // Programmatic clears (PAM completion) propagate back in.
                Connections {
                    target: surface.context
                    function onPasswordChanged() {
                        if (passwordField.text !== surface.context.password)
                            passwordField.text = surface.context.password;
                    }
                }
            }
        }

        Item { width: 1; height: 10 }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: surface.context.authenticating ? "checking\u2026" : "press enter"
            color: Theme.text4
            font.family: Theme.monoFont
            font.pixelSize: 11
        }
    }

    // Footer: nixos · niri · garden shell.
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 48
        text: "nixos \u00b7 niri \u00b7 garden shell"
        color: Theme.text4
        font.family: Theme.monoFont
        font.pixelSize: 11
        font.letterSpacing: 2
    }

    Component.onCompleted: passwordField.forceActiveFocus()
}

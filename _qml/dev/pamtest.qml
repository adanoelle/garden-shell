import QtQuick
import Quickshell
import Quickshell.Services.Pam

/// Throwaway PAM auth test (Phase D lockout-safety step 1).
///
/// Exercises the exact PamContext flow LockScreen will use, WITHOUT
/// any session lock — if auth is broken here, nothing is stranded.
///
///   qs -p _qml/dev/pamtest.qml                 # interactive window
///   PAMTEST_AUTO=bad qs -p _qml/dev/pamtest.qml  # non-interactive wrong-password probe
///
/// Not part of the shell — never imported by shell.qml. Like probe.qml,
/// Qt.quit() has no receiver under ShellRoot; kill the process manually
/// (or run under `timeout`).
ShellRoot {
    id: root

    readonly property bool auto: (Quickshell.env("PAMTEST_AUTO") || "") === "bad"

    property string status: "idle — type password, press enter"

    PamContext {
        id: pam

        // Auth-only stack (pam_unix), same service swaylock uses.
        config: "swaylock"

        onPamMessage: {
            console.info("pamtest: message='" + pam.message
                + "' isError=" + pam.messageIsError
                + " responseRequired=" + pam.responseRequired);
            if (pam.responseRequired) {
                pam.respond(root.auto ? "definitely-wrong-password" : passwordField.text);
            }
        }

        onCompleted: result => {
            const name = result === PamResult.Success ? "SUCCESS"
                       : result === PamResult.Failed   ? "FAILED"
                       : result === PamResult.MaxTries ? "MAX_TRIES"
                       : "ERROR(" + result + ")";
            console.info("pamtest: completed -> " + name);
            root.status = name;
            passwordField.text = "";
            if (root.auto) Qt.quit();
        }

        onError: error => {
            console.warn("pamtest: pam error " + error);
            root.status = "PAM_ERROR";
            if (root.auto) Qt.quit();
        }
    }

    Component.onCompleted: {
        console.info("pamtest: config=swaylock user=" + pam.user
            + (root.auto ? " (auto bad-password probe)" : " (interactive)"));
        if (root.auto) pam.start();
    }

    FloatingWindow {
        visible: !root.auto
        implicitWidth: 360
        implicitHeight: 120
        color: "#222222"

        Column {
            anchors.centerIn: parent
            spacing: 8

            Rectangle {
                width: 240
                height: 30
                color: "transparent"
                border.color: "#484848"
                border.width: 1

                TextInput {
                    id: passwordField
                    anchors.fill: parent
                    anchors.margins: 6
                    focus: true
                    echoMode: TextInput.Password
                    passwordCharacter: "*"
                    color: "#d4c4a0"
                    font.family: "IBM Plex Mono"
                    font.pixelSize: 13
                    verticalAlignment: TextInput.AlignVCenter

                    onAccepted: {
                        if (pam.active) return;
                        root.status = "authenticating…";
                        pam.start();
                    }
                }
            }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.status
                color: root.status === "SUCCESS" ? "#7a9470"
                     : root.status.indexOf("FAIL") === 0 ? "#bf7565"
                     : "#9a9a8e"
                font.family: "IBM Plex Mono"
                font.pixelSize: 11
            }
        }
    }
}

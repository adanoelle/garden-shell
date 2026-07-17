import QtQuick
import ".."
import "../components"
import "../services"

/// A single notification popup card (02-shell-design.md §6).
///
/// base-raised, 1 px border (urgent for critical), app name bold
/// text-1, body text-2, timestamp mono text-4. A progress line
/// depletes over the expiry window; expiry (or click / action) runs
/// the vertical-compress dismiss, then closes the notification.
/// Removal from the model flows through the notification's `closed`
/// signal via NotificationService.
Rectangle {
    id: root

    /// The Quickshell Notification object.
    required property var notification

    /// Entrance stagger in ms, set by NotificationPopups per burst.
    property int entranceDelay: 0

    /// Auto-expiry window in ms; 0 = never (critical).
    readonly property int timeoutMs: NotificationService.timeoutFor(root.notification)

    readonly property bool critical: root.notification.urgency === 2 // NotificationUrgency.Critical

    /// Arrival time, stamped once for the timestamp label.
    readonly property string arrived: Qt.formatTime(new Date(), "hh:mm")

    property bool _closing: false

    implicitHeight: content.implicitHeight + 24
    radius: 2
    color: Theme.baseRaised
    border.width: 1
    border.color: root.critical ? Theme.urgent : Theme.border
    clip: true

    // Entrance: slide from right + fade, staggered per burst.
    opacity: 0
    transform: Translate { id: slide; x: 24 }

    SequentialAnimation {
        id: entrance
        running: true

        PauseAnimation { duration: root.entranceDelay }
        ParallelAnimation {
            NumberAnimation {
                target: root; property: "opacity"
                to: 1; duration: 200; easing.type: Easing.OutCubic
            }
            NumberAnimation {
                target: slide; property: "x"
                to: 0; duration: 200; easing.type: Easing.OutCubic
            }
        }
    }

    // ── Dismissal: vertical compress, then close ────────────────────

    function dismiss(expired: bool) {
        if (root._closing) return;
        root._closing = true;
        compress.expired = expired;
        compress.start();
    }

    SequentialAnimation {
        id: compress

        property bool expired: false

        ParallelAnimation {
            NumberAnimation {
                target: root; property: "implicitHeight"
                to: 0; duration: 150; easing.type: Easing.InCubic
            }
            NumberAnimation {
                target: root; property: "opacity"
                to: 0; duration: 150; easing.type: Easing.InCubic
            }
        }

        // Triggers `closed` → NotificationService removes it → delegate
        // is destroyed.
        ScriptAction {
            script: {
                if (compress.expired) root.notification.expire();
                else root.notification.dismiss();
            }
        }
    }

    // Auto-expiry (0 = never; critical notifications wait for the user).
    Timer {
        interval: root.timeoutMs > 0 ? root.timeoutMs : 1
        running: root.timeoutMs > 0 && !root._closing
        onTriggered: root.dismiss(true)
    }

    // Click anywhere on the card dismisses it. Synthetic cards (e.g.
    // the queue-release summary) also invoke their primary action —
    // `synthetic` is undefined/falsy on real Notification QObjects.
    MouseArea {
        anchors.fill: parent
        onClicked: {
            if (root.notification.synthetic && root.notification.actions.length > 0)
                root.notification.actions[0].invoke();
            root.dismiss(false);
        }
    }

    // ── Content ─────────────────────────────────────────────────────

    Column {
        id: content

        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: 12
        spacing: 6

        // Header: app name + timestamp.
        Item {
            width: parent.width
            height: appName.implicitHeight

            Text {
                id: appName
                anchors.left: parent.left
                anchors.right: stamp.left
                anchors.rightMargin: 8
                text: root.notification.appName || "notification"
                color: Theme.text1
                font.family: Theme.sansFont
                font.pixelSize: 13
                font.bold: true
                elide: Text.ElideRight
            }

            Text {
                id: stamp
                anchors.right: parent.right
                anchors.baseline: appName.baseline
                text: root.arrived
                color: Theme.text4
                font.family: Theme.monoFont
                font.pixelSize: 10
            }
        }

        // Summary.
        Text {
            width: parent.width
            visible: text.length > 0
            text: root.notification.summary
            color: Theme.text2
            font.family: Theme.sansFont
            font.pixelSize: 12
            font.bold: true
            wrapMode: Text.Wrap
            maximumLineCount: 2
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }

        // Body.
        Text {
            width: parent.width
            visible: text.length > 0
            text: root.notification.body
            color: Theme.text2
            font.family: Theme.sansFont
            font.pixelSize: 12
            wrapMode: Text.Wrap
            maximumLineCount: 4
            elide: Text.ElideRight
            textFormat: Text.PlainText
        }

        // Actions: invoke + dismiss.
        Row {
            visible: root.notification.actions.length > 0
            spacing: 6

            Repeater {
                model: root.notification.actions

                // NOTE: handlers inside this nested delegate run in an
                // invalid QML context at click time (id lookups and QML
                // function calls both fail) — so the click is wired up
                // from the card's own scope via onItemAdded instead.
                delegate: GButton {
                    property var action: modelData
                    label: action.text
                }

                onItemAdded: (index, item) => {
                    item.clicked.connect(() => {
                        item.action.invoke();
                        root.dismiss(false);
                    });
                }
            }
        }
    }

    // Progress line depleting over the expiry window (absent for
    // critical — no auto-expiry to count down).
    Rectangle {
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        height: 2
        width: parent.width
        color: Theme.accent
        visible: root.timeoutMs > 0

        NumberAnimation on width {
            running: root.timeoutMs > 0
            from: root.width
            to: 0
            duration: root.timeoutMs
        }
    }
}

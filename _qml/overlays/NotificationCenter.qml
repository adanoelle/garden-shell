import QtQuick
import ".."
import "../components"
import "../services"

/// Notification history center (Super+Shift+M).
///
/// Reviews the session-only notification history kept by
/// NotificationService — everything that arrived this session, shown
/// or queued, newest first. Toggled via
/// `qs ipc call garden toggleNotificationCenter` or the summary card's
/// "open" action after a suppressed stretch.
OverlayBase {
    id: center

    _namespace:    "garden-notification-center"
    animDuration:  200
    contentTarget: content
    slideTarget:   contentSlide

    // ── Toggle ────────────────────────────────────────────────────────

    Connections {
        target: HookService
        function onNotificationCenterToggled() { center._toggle(); }
    }

    // ── Show-init hook ────────────────────────────────────────────────

    function _onBeforeShow() {
        historyList.currentIndex = NotificationService.history.length > 0 ? 0 : -1;
        keyHandler.forceActiveFocus();
    }

    // ── Content ───────────────────────────────────────────────────────

    Column {
        id: content
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: 480
        spacing: 8
        opacity: 0

        transform: Translate { id: contentSlide; y: 20 }

        // Key handling lives on a dedicated focus item — the overlay
        // has no text input to hang Keys off (cf. Launcher's TextInput).
        Item {
            id: keyHandler
            width: 0
            height: 0
            focus: true

            Keys.onEscapePressed: center._close()

            Keys.onPressed: (event) => {
                switch (event.key) {
                case Qt.Key_J:
                case Qt.Key_Down:
                    if (historyList.currentIndex < historyList.count - 1)
                        historyList.currentIndex++;
                    event.accepted = true;
                    break;
                case Qt.Key_K:
                case Qt.Key_Up:
                    if (historyList.currentIndex > 0)
                        historyList.currentIndex--;
                    event.accepted = true;
                    break;
                case Qt.Key_C:
                    NotificationService.clearHistory();
                    historyList.currentIndex = -1;
                    event.accepted = true;
                    break;
                }
            }
        }

        // Main panel.
        Rectangle {
            width: parent.width
            height: panelColumn.height + 2
            color: Theme.base
            border.color: Theme.border
            border.width: 1

            Column {
                id: panelColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 1

                // Header.
                Item {
                    width: parent.width
                    height: 36

                    Text {
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "notifications"
                        color: Theme.text1
                        font.family: Theme.sansFont
                        font.pixelSize: 13
                        font.bold: true
                    }

                    Text {
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: NotificationService.history.length + " this session"
                        color: Theme.text4
                        font.family: Theme.monoFont
                        font.pixelSize: 10
                    }
                }

                Rectangle {
                    width: parent.width
                    height: 1
                    color: Theme.borderSub
                }

                // Empty state.
                Item {
                    width: parent.width
                    height: 64
                    visible: NotificationService.history.length === 0

                    Text {
                        anchors.centerIn: parent
                        text: "no notifications"
                        color: Theme.text4
                        font.family: Theme.monoFont
                        font.pixelSize: 12
                    }
                }

                // History list.
                ListView {
                    id: historyList
                    width: parent.width
                    height: Math.min(contentHeight, 400)
                    visible: NotificationService.history.length > 0
                    clip: true
                    model: NotificationService.history
                    currentIndex: 0
                    highlightMoveDuration: 60
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: entryRow

                        required property var modelData
                        required property int index

                        width: historyList.width
                        height: entryContent.implicitHeight + 16
                        color: index === historyList.currentIndex
                            ? Theme.baseHl : "transparent"

                        Rectangle {
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            width: 2
                            color: Theme.urgent
                            visible: entryRow.modelData.urgency === 2
                        }

                        Column {
                            id: entryContent
                            anchors.top: parent.top
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.margins: 8
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 2

                            Item {
                                width: parent.width
                                height: entryApp.implicitHeight

                                Text {
                                    id: entryApp
                                    anchors.left: parent.left
                                    anchors.right: entryStamp.left
                                    anchors.rightMargin: 8
                                    text: entryRow.modelData.appName || "notification"
                                    color: Theme.text1
                                    font.family: Theme.sansFont
                                    font.pixelSize: 12
                                    font.bold: true
                                    elide: Text.ElideRight
                                }

                                Text {
                                    id: entryStamp
                                    anchors.right: parent.right
                                    anchors.baseline: entryApp.baseline
                                    text: entryRow.modelData.time
                                    color: Theme.text4
                                    font.family: Theme.monoFont
                                    font.pixelSize: 10
                                }
                            }

                            Text {
                                width: parent.width
                                visible: text.length > 0
                                text: {
                                    const s = entryRow.modelData.summary || "";
                                    const b = entryRow.modelData.body || "";
                                    return b.length > 0 ? s + " — " + b : s;
                                }
                                color: Theme.text2
                                font.family: Theme.sansFont
                                font.pixelSize: 12
                                wrapMode: Text.Wrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                                textFormat: Text.PlainText
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: historyList.currentIndex = entryRow.index
                        }
                    }
                }
            }
        }

        HintLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Esc close  \u00b7  j/k navigate  \u00b7  c clear"
        }
    }
}

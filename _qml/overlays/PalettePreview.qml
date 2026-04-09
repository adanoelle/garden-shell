import QtQuick
import ".."

/// Live preview of the current theme colors.
///
/// Shows a miniature bar, terminal snippet, code block, notification,
/// and a 13-swatch color strip. All colors bind to Theme.* so they
/// update instantly during live editing.
Item {
    id: root
    width: parent ? parent.width : 400
    height: previewCol.height

    Column {
        id: previewCol
        width: parent.width
        spacing: 8

        // ── Mini bar ────────────────────────────────────────────────

        Rectangle {
            width: parent.width
            height: 24
            color: Theme.baseDeep

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                // Dot indicators.
                Repeater {
                    model: 3
                    Rectangle {
                        required property int index
                        width: 6; height: 6; radius: 3
                        color: index === 0 ? Theme.text2 : Theme.borderSub
                    }
                }

                Text {
                    text: "studio"
                    color: Theme.text1
                    font.family: Theme.sansFont
                    font.pixelSize: 11
                    font.bold: true
                }

                Text {
                    text: "\u00b7"
                    color: Theme.text4
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                }

                Text {
                    text: "kitty"
                    color: Theme.text2
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                }
            }

            Text {
                anchors.right: parent.right
                anchors.rightMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                text: "12:34"
                color: Theme.text1
                font.family: Theme.monoFont
                font.pixelSize: 11
            }
        }

        // ── Terminal snippet ─────────────────────────────────────────

        Rectangle {
            width: parent.width
            height: termCol.height + 16
            color: Theme.base
            border.color: Theme.borderSub
            border.width: 1

            Column {
                id: termCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                spacing: 2

                Text {
                    text: "~/src/garden-shell"
                    color: Theme.accent
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                }

                Row {
                    spacing: 0
                    Text {
                        text: "$ "
                        color: Theme.text3
                        font.family: Theme.monoFont
                        font.pixelSize: 11
                    }
                    Text {
                        text: "cargo build"
                        color: Theme.text1
                        font.family: Theme.monoFont
                        font.pixelSize: 11
                    }
                }

                Text {
                    text: "   Compiling garden-core v0.1.0"
                    color: Theme.ok
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                }

                Text {
                    text: "warning: unused variable `x`"
                    color: Theme.urgent
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                }
            }
        }

        // ── Code block ──────────────────────────────────────────────

        Rectangle {
            width: parent.width
            height: codeCol.height + 16
            color: Theme.baseRaised
            border.color: Theme.borderSub
            border.width: 1

            Column {
                id: codeCol
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 8
                spacing: 2

                Row {
                    spacing: 0
                    Text { text: "fn "; color: Theme.text3; font { family: Theme.monoFont; pixelSize: 11 } }
                    Text { text: "apply"; color: Theme.accent; font { family: Theme.monoFont; pixelSize: 11 } }
                    Text { text: "(name: &str) {"; color: Theme.text2; font { family: Theme.monoFont; pixelSize: 11 } }
                }
                Row {
                    spacing: 0
                    Text { text: "    "; color: Theme.text4; font { family: Theme.monoFont; pixelSize: 11 } }
                    Text { text: "println!"; color: Theme.text1; font { family: Theme.monoFont; pixelSize: 11 } }
                    Text { text: "(\"switching\")"; color: Theme.ok; font { family: Theme.monoFont; pixelSize: 11 } }
                }
                Text { text: "}"; color: Theme.text2; font { family: Theme.monoFont; pixelSize: 11 } }
            }
        }

        // ── Notification ────────────────────────────────────────────

        Rectangle {
            width: parent.width
            height: 28
            color: Theme.baseHl
            border.color: Theme.border
            border.width: 1

            Row {
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6

                Text {
                    text: "\u25cf"
                    color: Theme.accent
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                }
                Text {
                    text: "palette applied"
                    color: Theme.text1
                    font.family: Theme.sansFont
                    font.pixelSize: 11
                }
                Text {
                    text: "just now"
                    color: Theme.text4
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                }
            }
        }

        // ── Swatch strip (all 13 roles) ─────────────────────────────

        Row {
            spacing: 2

            Repeater {
                model: [
                    Theme.baseDeep, Theme.base, Theme.baseRaised, Theme.baseHl,
                    Theme.borderSub, Theme.border,
                    Theme.text4, Theme.text3, Theme.text2, Theme.text1,
                    Theme.accent, Theme.urgent, Theme.ok
                ]

                Rectangle {
                    required property color modelData
                    width: (root.width - 24) / 13
                    height: 12
                    color: modelData
                }
            }
        }
    }
}

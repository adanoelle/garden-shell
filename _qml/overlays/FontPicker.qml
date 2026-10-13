import QtQuick
import ".."
import "../services"

/// A labelled row of typeface choices for one role (sans or mono).
///
/// Each choice is drawn in its own face so the row doubles as a preview.
/// Only installed families are offered. Picking one calls
/// ConfigService.setFont(role, family), which persists it to
/// settings.json and re-styles the shell immediately.
Column {
    id: root
    spacing: 6

    /// Section header text (e.g. "interface", "mono").
    property string sectionLabel: ""

    /// "sans" or "mono" — the settings.json key under `fonts`.
    property string role: "sans"

    /// Candidate family names (filtered to the installed ones).
    property var choices: []

    /// The family currently in use for this role.
    property string current: ""

    /// Sample text shown under the chips, in the current face.
    property string sample: ""

    readonly property var _installed: {
        const have = Qt.fontFamilies();
        return root.choices.filter(f => have.indexOf(f) >= 0);
    }

    // ── Header ──────────────────────────────────────────────────────

    Text {
        text: root.sectionLabel
        color: Theme.text2
        font.family: Theme.sansFont
        font.pixelSize: 12
        font.weight: Font.DemiBold
        bottomPadding: 2
    }

    // ── Choices ─────────────────────────────────────────────────────

    Flow {
        width: parent.width
        spacing: 8

        Repeater {
            model: root._installed

            Rectangle {
                id: chip
                required property string modelData
                readonly property bool selected: modelData === root.current

                width: chipLabel.width + 24
                height: 30
                radius: 2
                color: chip.selected ? Theme.baseHl
                    : (chipArea.containsMouse ? Theme.baseRaised : Theme.base)
                border.width: 1
                border.color: chip.selected ? Theme.accent : Theme.border

                Text {
                    id: chipLabel
                    anchors.centerIn: parent
                    text: chip.modelData
                    color: chip.selected ? Theme.text1 : Theme.text2
                    font.family: chip.modelData
                    font.pixelSize: 13
                }

                MouseArea {
                    id: chipArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: {
                        if (!chip.selected) ConfigService.setFont(root.role, chip.modelData);
                    }
                }
            }
        }
    }

    // ── Sample in the current face ──────────────────────────────────

    Text {
        visible: root.sample.length > 0
        width: parent.width
        text: root.sample
        color: Theme.text3
        font.family: root.current
        font.pixelSize: 13
        elide: Text.ElideRight
    }
}

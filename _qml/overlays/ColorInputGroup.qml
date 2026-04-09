import QtQuick
import ".."

/// A labeled section of ColorInput delegates.
///
/// Takes a `sectionLabel`, `colorKeys` array, and `colorValues` object.
/// Emits `colorEdited(key, hex)` when any child input changes.
Column {
    id: root
    width: parent ? parent.width : 200
    spacing: 4

    /// Section header text (e.g. "surfaces", "borders").
    property string sectionLabel: ""

    /// Ordered list of TOML color keys for this section.
    property var colorKeys: []

    /// Object mapping color key → hex string (the working palette).
    property var colorValues: ({})

    /// Bubbled from child ColorInput delegates.
    signal colorEdited(string key, string hex)

    // ── Header ──────────────────────────────────────────────────────

    Text {
        text: root.sectionLabel
        color: Theme.text2
        font.family: Theme.sansFont
        font.pixelSize: 12
        font.weight: Font.DemiBold
        bottomPadding: 4
    }

    // ── Color inputs ────────────────────────────────────────────────

    Repeater {
        model: root.colorKeys

        ColorInput {
            required property string modelData

            colorKey: modelData
            colorValue: root.colorValues[modelData] ?? "#000000"
            onColorEdited: (key, hex) => root.colorEdited(key, hex)
        }
    }
}

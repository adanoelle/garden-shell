import QtQuick
import ".."

/// Single color editor: swatch rectangle + hex TextInput + validation.
///
/// Emits `colorEdited(string key, string hex)` only when the input is a
/// valid 7-character hex color (#RRGGBB). Invalid input shows an urgent
/// border on the swatch.
Item {
    id: root
    width: parent ? parent.width : 200
    height: 28

    /// TOML key for this color (e.g. "base-deep").
    property string colorKey: ""

    /// Current hex value (set externally, read from working palette).
    property string colorValue: "#000000"

    /// Emitted when the user types a valid hex color.
    signal colorEdited(string key, string hex)

    // ── Internal: suppress signals during programmatic text updates ─

    property bool _updating: false

    // ── Validation ──────────────────────────────────────────────────

    readonly property bool _valid: /^#[0-9a-fA-F]{6}$/.test(hexInput.text)

    // ── Layout ──────────────────────────────────────────────────────

    Row {
        anchors.fill: parent
        spacing: 8

        // Color swatch.
        Rectangle {
            width: 28
            height: 28
            color: root._valid ? hexInput.text : root.colorValue
            border.color: root._valid ? Theme.borderSub : Theme.urgent
            border.width: 1
        }

        // Key label.
        Text {
            anchors.verticalCenter: parent.verticalCenter
            width: 80
            text: root.colorKey
            color: Theme.text3
            font.family: Theme.monoFont
            font.pixelSize: 11
            elide: Text.ElideRight
        }

        // Hex input field.
        Rectangle {
            width: 80
            height: 28
            color: Theme.baseDeep
            border.color: root._valid ? Theme.borderSub : Theme.urgent
            border.width: 1

            TextInput {
                id: hexInput
                anchors.fill: parent
                anchors.leftMargin: 6
                anchors.rightMargin: 6
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.text1
                selectionColor: Theme.baseHl
                selectedTextColor: Theme.text1
                font.family: Theme.monoFont
                font.pixelSize: 12
                maximumLength: 7
                clip: true

                onTextChanged: {
                    // Test the text directly rather than reading root._valid:
                    // that binding may not have re-evaluated yet when this
                    // handler runs, so it can be stale (e.g. backspacing from
                    // a valid color would emit the now-invalid text).
                    if (!root._updating && /^#[0-9a-fA-F]{6}$/.test(text)) {
                        root.colorEdited(root.colorKey, text);
                    }
                }
            }
        }
    }

    // ── Sync external value into the input field ────────────────────

    onColorValueChanged: {
        if (!hexInput.activeFocus) {
            root._updating = true;
            hexInput.text = root.colorValue;
            root._updating = false;
        }
    }
    Component.onCompleted: {
        root._updating = true;
        hexInput.text = root.colorValue;
        root._updating = false;
    }
}

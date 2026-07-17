import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../components"
import "../services"

/// Palette editor panel: selector tabs, hex editors, preview, save/discard/fork.
///
/// Data flow:
///   Theme.allPaletteData (Connections) → _palettesData → _workingColors
///   → Theme.applyColorPreview() (live preview)
///
/// Save flow:
///   deep-copy _palettesData → update colors + active → serialize TOML
///   → write to palettes.toml → garden-themes apply → Theme FileView reloads
Item {
    id: root
    width: parent ? parent.width : 520
    height: editorCol.height

    // ── Popup / dropdown support ─────────────────────────────────────

    /// Item to reparent the dropdown popup into (escapes Flickable clip).
    property Item popupParent: null

    /// Whether the palette dropdown is currently open.
    readonly property bool dropdownOpen: selector.dropdownOpen

    /// Close the palette dropdown.
    function closeDropdown() { selector.close(); }

    // ── Palette data (loaded from palettes.json) ────────────────────

    /// Full parsed palette JSON. Set by parent (Settings.qml).
    property var _palettesData: ({})

    /// Name of the palette being edited.
    property string _editingPalette: ""

    /// Mutable copy of the editing palette's 13 colors.
    /// Replaced (not mutated) so QML detects property changes.
    property var _workingColors: ({})

    /// Whether any color has been modified since last load/save.
    property bool _dirty: false

    /// Whether the selected palette differs from the currently active one.
    readonly property bool _needsApply: root._editingPalette !== ""
        && root._editingPalette !== (root._palettesData.active || "")

    // ── Color role ordering ─────────────────────────────────────────

    readonly property var _surfaceKeys: ["base-deep", "base", "base-raised", "base-hl"]
    readonly property var _borderKeys:  ["border-sub", "border"]
    readonly property var _textKeys:    ["text-4", "text-3", "text-2", "text-1"]
    readonly property var _semanticKeys: ["accent", "urgent", "ok"]

    // ── File paths ──────────────────────────────────────────────────

    readonly property string _configHome: ConfigService.configHome
    readonly property string _palettesTomlPath: _configHome + "/garden/palettes.toml"

    // ── Sync from Theme (single FileView lives in Theme, not here) ──

    /// Sync when Theme loads or reloads palettes.json.
    Connections {
        target: Theme
        function onAllPaletteDataChanged() {
            root._palettesData = Theme.allPaletteData;
            // Select the active palette if we don't have one yet.
            if (!root._editingPalette || !root._palettesData.palettes?.[root._editingPalette]) {
                root._editingPalette = root._palettesData.active || Theme.activePalette;
            }
            root._loadWorkingColors();
        }
    }

    function _loadWorkingColors() {
        const palette = root._palettesData.palettes?.[root._editingPalette];
        if (!palette?.colors) return;
        // Deep copy so we don't mutate the cache.
        root._workingColors = JSON.parse(JSON.stringify(palette.colors));
        root._dirty = false;
        root._pushToTheme();
    }

    // ── Select a different palette ──────────────────────────────────

    function selectPalette(name: string) {
        if (root._dirty) root._discardEdits();
        root._editingPalette = name;
        root._loadWorkingColors();
    }

    // ── Live preview: push working colors into Theme ────────────────

    function _pushToTheme() {
        Theme.applyColorPreview(root._workingColors);
    }

    // ── Handle a color edit from a ColorInput ───────────────────────

    function _onColorEdited(key: string, hex: string) {
        if (root._workingColors[key] === hex) return;
        // Replace the whole object so QML detects the change.
        const copy = JSON.parse(JSON.stringify(root._workingColors));
        copy[key] = hex;
        root._workingColors = copy;
        root._dirty = true;
        root._pushToTheme();
    }

    // ── Discard: reload from cached data ────────────────────────────

    function _discardEdits() {
        root._editingPalette = root._palettesData.active || Theme.activePalette;
        root._loadWorkingColors();
    }

    // ── Save: serialize TOML and write to disk ──────────────────────

    /// Validates that every color role in the working set is a #rrggbb hex
    /// string. Returns true if all are valid.
    function _validateWorkingColors(): bool {
        const re = /^#[0-9a-fA-F]{6}$/;
        for (let i = 0; i < root._colorOrder.length; i++) {
            const key = root._colorOrder[i];
            const value = root._workingColors[key];
            if (typeof value !== "string" || !re.test(value)) {
                console.warn("PaletteEditor: invalid color for '" + key
                    + "': " + JSON.stringify(value) + " — save aborted");
                return false;
            }
        }
        return true;
    }

    /// TOML content pending write; consumed by saveProcess.onStarted.
    property string _pendingToml: ""

    function save() {
        // Refuse to write invalid data to the palette source of truth.
        if (!root._validateWorkingColors()) return;

        // Build updated data with new active palette and colors.
        const data = JSON.parse(JSON.stringify(root._palettesData));
        data.active = root._editingPalette;
        if (data.palettes?.[root._editingPalette]) {
            data.palettes[root._editingPalette].colors = JSON.parse(
                JSON.stringify(root._workingColors));
        }

        // Update local state optimistically so _needsApply clears
        // even if garden-themes isn't available.
        root._palettesData = data;
        root._dirty = false;

        // Serialize to TOML and write via tee's stdin: the content never
        // passes through a shell, so no quoting/heredoc pitfalls.
        root._pendingToml = root._serializeToml(data);
        saveProcess.command = ["tee", root._palettesTomlPath];
        saveProcess.running = true;
    }

    Process {
        id: saveProcess
        running: false
        stdinEnabled: true
        onStarted: {
            saveProcess.write(root._pendingToml);
            // Close stdin so tee sees EOF and exits.
            saveProcess.stdinEnabled = false;
        }
        onExited: (exitCode, exitStatus) => {
            // Re-arm stdin for the next save.
            saveProcess.stdinEnabled = true;
            if (exitCode !== 0) {
                console.warn("PaletteEditor: failed to write palettes.toml");
                return;
            }
            // Trigger garden-themes apply so all apps pick up the change.
            Theme.switchPalette(root._editingPalette);
        }
    }

    // ── Fork: create a custom palette from the current one ──────────

    function fork() {
        const srcName = root._editingPalette;
        const newName = srcName + "-custom";
        const data = JSON.parse(JSON.stringify(root._palettesData));

        // Don't overwrite an existing custom palette.
        if (data.palettes?.[newName]) {
            root._editingPalette = newName;
            root._loadWorkingColors();
            return;
        }

        const src = data.palettes?.[srcName];
        if (!src) return;

        data.palettes[newName] = {
            name: newName,
            subtitle: "custom -- forked from " + srcName,
            icon: "\u25c7",
            builtin: false,
            forked_from: srcName,
            colors: JSON.parse(JSON.stringify(root._workingColors))
        };

        root._palettesData = data;
        root._editingPalette = newName;
        root._loadWorkingColors();
        root._dirty = true;
    }

    // ── Delete a custom palette ─────────────────────────────────────

    function deletePalette(name: string) {
        const palette = root._palettesData.palettes?.[name];
        if (!palette || palette.builtin !== false) return;

        const data = JSON.parse(JSON.stringify(root._palettesData));
        delete data.palettes[name];

        // If we're deleting the currently edited palette, switch to active.
        if (root._editingPalette === name) {
            root._editingPalette = data.active || Theme.activePalette;
        }

        root._palettesData = data;
        root._loadWorkingColors();
        root.save();
    }

    // ── TOML serialization ──────────────────────────────────────────

    readonly property var _colorOrder: Theme.colorKeyOrder

    /// Escapes a string for use inside a TOML basic (double-quoted) string.
    function _tomlEscape(s: string): string {
        return s.replace(/\\/g, "\\\\").replace(/"/g, '\\"');
    }

    function _serializeToml(data: var): string {
        let out = 'active = "' + root._tomlEscape(data.active || "sumi") + '"\n';
        const palettes = data.palettes || {};
        const names = Object.keys(palettes).sort();
        for (let i = 0; i < names.length; i++) {
            const name = names[i];
            const p = palettes[name];
            out += "\n[palettes." + name + "]\n";
            out += 'name = "' + root._tomlEscape(p.name || name) + '"\n';
            out += 'subtitle = "' + root._tomlEscape(p.subtitle || "") + '"\n';
            out += 'icon = "' + root._tomlEscape(p.icon || "\u25cf") + '"\n';
            out += "builtin = " + (p.builtin ? "true" : "false") + "\n";
            if (p.forked_from) {
                out += 'forked_from = "' + root._tomlEscape(p.forked_from) + '"\n';
            }
            out += "\n[palettes." + name + ".colors]\n";
            const colors = p.colors || {};
            for (let j = 0; j < root._colorOrder.length; j++) {
                const key = root._colorOrder[j];
                out += key + ' = "' + (colors[key] || "#000000") + '"\n';
            }
        }
        return out;
    }

    // ── UI layout ───────────────────────────────────────────────────

    Column {
        id: editorCol
        width: parent.width
        spacing: 12

        // Palette selector dropdown.
        PaletteSelector {
            id: selector
            width: parent.width
            palettesData: root._palettesData
            selectedPalette: root._editingPalette
            popupParent: root.popupParent
            onPaletteSelected: name => root.selectPalette(name)
            onPaletteDeleteRequested: name => root.deletePalette(name)
        }

        // Editing palette title.
        Row {
            spacing: 8
            Text {
                text: root._palettesData.palettes?.[root._editingPalette]?.icon || "\u25cf"
                color: Theme.text1
                font.family: Theme.monoFont
                font.pixelSize: 16
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root._editingPalette
                color: Theme.text1
                font.family: Theme.sansFont
                font.pixelSize: 16
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                visible: root._dirty
                text: "(unsaved)"
                color: Theme.urgent
                font.family: Theme.monoFont
                font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // Two-column layout: color inputs left, preview right.
        Row {
            width: parent.width
            spacing: 16

            // Left column: color groups.
            Column {
                width: (parent.width - 16) * 0.5
                spacing: 16

                ColorInputGroup {
                    width: parent.width
                    sectionLabel: "surfaces"
                    colorKeys: root._surfaceKeys
                    colorValues: root._workingColors
                    onColorEdited: (key, hex) => root._onColorEdited(key, hex)
                }

                ColorInputGroup {
                    width: parent.width
                    sectionLabel: "borders"
                    colorKeys: root._borderKeys
                    colorValues: root._workingColors
                    onColorEdited: (key, hex) => root._onColorEdited(key, hex)
                }

                ColorInputGroup {
                    width: parent.width
                    sectionLabel: "text"
                    colorKeys: root._textKeys
                    colorValues: root._workingColors
                    onColorEdited: (key, hex) => root._onColorEdited(key, hex)
                }

                ColorInputGroup {
                    width: parent.width
                    sectionLabel: "semantic"
                    colorKeys: root._semanticKeys
                    colorValues: root._workingColors
                    onColorEdited: (key, hex) => root._onColorEdited(key, hex)
                }
            }

            // Right column: preview.
            Column {
                width: (parent.width - 16) * 0.5
                spacing: 12

                Text {
                    text: "preview"
                    color: Theme.text2
                    font.family: Theme.sansFont
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                PalettePreview {
                    width: parent.width
                }
            }
        }

        // ── Action buttons ──────────────────────────────────────────

        Row {
            spacing: 8

            // Save/Apply button (accent fill when there's something to act on).
            GButton {
                label:  root._dirty ? "save" : "apply"
                active: root._dirty || root._needsApply
                onClicked: { if (root._dirty || root._needsApply) root.save(); }
            }

            GButton {
                label: "reset"
                onClicked: { if (root._dirty || root._needsApply) root._discardEdits(); }
            }

            GButton {
                label: "fork"
                onClicked: root.fork()
            }
        }
    }
}

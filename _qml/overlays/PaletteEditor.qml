import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../services"

/// Palette editor panel: selector tabs, hex editors, preview, save/discard/fork.
///
/// Data flow:
///   palettes.json (FileView) → _palettesData → _workingColors → Theme.*
///
/// Save flow:
///   deep-copy _palettesData → update colors + active → serialize TOML
///   → write to palettes.toml → garden-themes apply → FileView picks up change
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

    // ── Load palette data from JSON ─────────────────────────────────

    FileView {
        id: palettesFile
        path: Theme.themesDir + "/palettes.json"
        watchChanges: true
        blockLoading: true

        onLoaded: root._reloadFromFile()
        onFileChanged: palettesFile.reload()
    }

    function _reloadFromFile() {
        const content = palettesFile.text();
        if (content.length === 0) return;
        try {
            root._palettesData = JSON.parse(content);
        } catch (e) {
            console.warn("PaletteEditor: failed to parse palettes.json:", e);
            return;
        }
        // Select the active palette if we don't have one yet.
        if (!root._editingPalette || !root._palettesData.palettes?.[root._editingPalette]) {
            root._editingPalette = root._palettesData.active || Theme.activePalette;
        }
        root._loadWorkingColors();
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
        const c = root._workingColors;
        if (!c || Object.keys(c).length === 0) return;
        Theme.baseDeep   = c["base-deep"]   ?? Theme.baseDeep;
        Theme.base       = c["base"]        ?? Theme.base;
        Theme.baseRaised = c["base-raised"] ?? Theme.baseRaised;
        Theme.baseHl     = c["base-hl"]     ?? Theme.baseHl;
        Theme.borderSub  = c["border-sub"]  ?? Theme.borderSub;
        Theme.border     = c["border"]      ?? Theme.border;
        Theme.text4      = c["text-4"]      ?? Theme.text4;
        Theme.text3      = c["text-3"]      ?? Theme.text3;
        Theme.text2      = c["text-2"]      ?? Theme.text2;
        Theme.text1      = c["text-1"]      ?? Theme.text1;
        Theme.accent     = c["accent"]      ?? Theme.accent;
        Theme.urgent     = c["urgent"]      ?? Theme.urgent;
        Theme.ok         = c["ok"]          ?? Theme.ok;
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

    function save() {
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

        // Serialize to TOML and write.
        const toml = root._serializeToml(data);
        saveProcess.command = [
            "bash", "-c",
            "cat > '" + root._palettesTomlPath + "' << 'GARDEN_EOF'\n" + toml + "\nGARDEN_EOF"
        ];
        saveProcess.running = true;
    }

    Process {
        id: saveProcess
        running: false
        onExited: (exitCode, exitStatus) => {
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

    readonly property var _colorOrder: [
        "base-deep", "base", "base-raised", "base-hl",
        "border-sub", "border",
        "text-4", "text-3", "text-2", "text-1",
        "accent", "urgent", "ok"
    ]

    function _serializeToml(data: var): string {
        let out = 'active = "' + (data.active || "sumi") + '"\n';
        const palettes = data.palettes || {};
        const names = Object.keys(palettes).sort();
        for (let i = 0; i < names.length; i++) {
            const name = names[i];
            const p = palettes[name];
            out += "\n[palettes." + name + "]\n";
            out += 'name = "' + (p.name || name) + '"\n';
            out += 'subtitle = "' + (p.subtitle || "") + '"\n';
            out += 'icon = "' + (p.icon || "\u25cf") + '"\n';
            out += "builtin = " + (p.builtin ? "true" : "false") + "\n";
            if (p.forked_from) {
                out += 'forked_from = "' + p.forked_from + '"\n';
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

            // Save/Apply button.
            Rectangle {
                width: saveLabel.width + 24
                height: 32
                color: (root._dirty || root._needsApply) ? Theme.accent : Theme.baseRaised
                border.color: Theme.border
                border.width: 1

                Text {
                    id: saveLabel
                    anchors.centerIn: parent
                    text: root._dirty ? "save" : "apply"
                    color: (root._dirty || root._needsApply) ? Theme.baseDeep : Theme.text3
                    font.family: Theme.monoFont
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: (root._dirty || root._needsApply) ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: { if (root._dirty || root._needsApply) root.save(); }
                }
            }

            // Reset button.
            Rectangle {
                width: resetLabel.width + 24
                height: 32
                color: Theme.baseRaised
                border.color: Theme.border
                border.width: 1

                Text {
                    id: resetLabel
                    anchors.centerIn: parent
                    text: "reset"
                    color: (root._dirty || root._needsApply) ? Theme.text1 : Theme.text4
                    font.family: Theme.monoFont
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: (root._dirty || root._needsApply) ? Qt.PointingHandCursor : Qt.ArrowCursor
                    onClicked: { if (root._dirty || root._needsApply) root._discardEdits(); }
                }
            }

            // Fork button.
            Rectangle {
                width: forkLabel.width + 24
                height: 32
                color: Theme.baseRaised
                border.color: Theme.border
                border.width: 1

                Text {
                    id: forkLabel
                    anchors.centerIn: parent
                    text: "fork"
                    color: Theme.text2
                    font.family: Theme.monoFont
                    font.pixelSize: 12
                }

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.fork()
                }
            }
        }
    }
}

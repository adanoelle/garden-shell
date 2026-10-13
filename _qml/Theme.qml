pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "services"

/// Global theme singleton providing the 13 semantic color roles.
///
/// Reads the palette cache (palettes.json) written by `garden-themes`
/// via FileView with watchChanges. When `garden-themes apply` runs,
/// the cache is regenerated and all color properties update reactively.
///
/// Default values are sumi so the shell works before first apply.
Singleton {
    id: root

    // ── Resolved config path ────────────────────────────────────────

    readonly property string themesDir: ConfigService.configHome + "/garden/themes"

    // ── Surface colors ──────────────────────────────────────────────

    property color baseDeep:   "#222222"
    property color base:       "#282828"
    property color baseRaised: "#313131"
    property color baseHl:     "#3a3a3a"

    // ── Border colors ───────────────────────────────────────────────

    property color borderSub:  "#383838"
    property color border:     "#484848"

    // ── Text hierarchy ──────────────────────────────────────────────

    property color text4:      "#545450"
    property color text3:      "#706f68"
    property color text2:      "#9a9a8e"
    property color text1:      "#d4c4a0"

    // ── Semantic colors ─────────────────────────────────────────────

    property color accent:     "#c2a86a"
    property color urgent:     "#bf7565"
    property color ok:         "#7a9470"

    // ── Palette metadata ────────────────────────────────────────────

    property string activePalette: "sumi"
    property string paletteIcon:   "●"
    property var paletteNames:     []

    // ── Color key ordering (single source of truth) ─────────────────

    /// Canonical ordered list of the 13 dash-case color keys.
    /// Adding a new color role requires: new property above, entry here,
    /// and an assignment in _applyColorMap below.
    readonly property var colorKeyOrder: [
        "base-deep", "base", "base-raised", "base-hl",
        "border-sub", "border",
        "text-4", "text-3", "text-2", "text-1",
        "accent", "urgent", "ok"
    ]

    // ── Full palette data (for PaletteEditor) ───────────────────────

    /// Full parsed palettes.json, updated by _loadPalette.
    /// PaletteEditor reads from here instead of its own FileView.
    property var allPaletteData: ({})

    // ── Fonts ───────────────────────────────────────────────────────
    //
    // Sans for human-facing text (names, actions, labels); mono for
    // data and metadata (numbers, times, keys, ids).
    //
    // M PLUS 1 (the default sans) gives U+00B7 (·) zero advance width —
    // it collides with the next word. Separators in sans text use
    // U+2022 (•), which it draws at the same visual weight; mono text
    // keeps ·.

    /// Chosen in Settings → palette → typography; stored in
    /// settings.json (ConfigService). Defaults: M PLUS 1, IBM Plex Mono.
    readonly property string sansFont: ConfigService.sansFont
    readonly property string monoFont: ConfigService.monoFont

    // ── Type scale (px) ─────────────────────────────────────────────

    readonly property int fontCaption: 10   // section labels, timestamps
    readonly property int fontMeta:    11   // data, metadata, hints
    readonly property int fontBody:    12   // rows, body text, buttons
    readonly property int fontTitle:   13   // bar channel, card titles
    readonly property int fontLarge:   14   // inputs, switcher, power menu
    readonly property int fontHeading: 16   // section headings

    // ── Spacing (4 px grid) ─────────────────────────────────────────

    readonly property int space1: 4
    readonly property int space2: 8
    readonly property int space3: 12
    readonly property int space4: 16

    // ── Motion (ms) ─────────────────────────────────────────────────
    //
    // The design spec's timing hierarchy: Launcher fast, ChannelSwitcher
    // and Settings base. Intentional — do not normalise.

    readonly property int motionQuick: 120   // hover expansions, chips
    readonly property int motionFast:  150   // launcher, ambient brighten
    readonly property int motionBase:  200   // overlays, cards

    // ── Palette cache watcher ───────────────────────────────────────

    FileView {
        id: paletteFile
        path: root.themesDir + "/palettes.json"
        watchChanges: true
        blockLoading: true

        onLoaded: {
            const content = paletteFile.text();
            if (content.length > 0) root._loadPalette(content);
        }
        onFileChanged: {
            paletteFile.reload();
        }
    }

    // ── Switch palette (triggers garden-themes apply) ───────────────

    /// Resolved path to garden-themes binary.
    /// Checks $GARDEN_THEMES_BIN first, then falls back to bare name on PATH.
    readonly property string _themesBin: {
        const env = Quickshell.env("GARDEN_THEMES_BIN");
        return (env && env.length > 0) ? env : "garden-themes";
    }

    function switchPalette(name: string) {
        applyProcess.command = [root._themesBin, "apply", "--name", name];
        applyProcess.running = true;
    }

    Process {
        id: applyProcess
        running: false
        stdout: SplitParser {
            onRead: data => console.log("garden-themes:", data)
        }
        stderr: SplitParser {
            onRead: data => console.warn("garden-themes stderr:", data)
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.warn("garden-themes apply failed with exit code", exitCode);
            }
            // FileView will pick up the change automatically.
        }
    }

    // ── Internal: canonical color key → property mapping ───────────

    /// Apply a color dict (dash-case keys) to the Theme properties.
    /// This is the single source of truth for the mapping — never
    /// duplicate this block elsewhere.
    function _applyColorMap(c) {
        root.baseDeep   = c["base-deep"]   ?? root.baseDeep;
        root.base       = c["base"]        ?? root.base;
        root.baseRaised = c["base-raised"] ?? root.baseRaised;
        root.baseHl     = c["base-hl"]     ?? root.baseHl;
        root.borderSub  = c["border-sub"]  ?? root.borderSub;
        root.border     = c["border"]      ?? root.border;
        root.text4      = c["text-4"]      ?? root.text4;
        root.text3      = c["text-3"]      ?? root.text3;
        root.text2      = c["text-2"]      ?? root.text2;
        root.text1      = c["text-1"]      ?? root.text1;
        root.accent     = c["accent"]      ?? root.accent;
        root.urgent     = c["urgent"]      ?? root.urgent;
        root.ok         = c["ok"]          ?? root.ok;
    }

    /// Apply a preview color set (called by PaletteEditor for live preview).
    /// Does not update metadata — preview only.
    function applyColorPreview(colors) {
        if (!colors || Object.keys(colors).length === 0) return;
        root._applyColorMap(colors);
    }

    // ── Internal: parse JSON and update colors ──────────────────────

    function _loadPalette(jsonStr: string) {
        let data;
        try {
            data = JSON.parse(jsonStr);
        } catch (e) {
            console.warn("Theme: failed to parse palettes.json:", e);
            return;
        }

        const activeName = data.active || "sumi";
        const palette = data.palettes?.[activeName];
        if (!palette) {
            console.warn("Theme: active palette", activeName, "not found in cache");
            return;
        }

        const c = palette.colors;
        if (!c) return;

        // Update all 13 colors (hard cut, no animation).
        root._applyColorMap(c);

        // Update metadata.
        root.activePalette = activeName;
        root.paletteIcon   = palette.icon || root.paletteIcon;

        // Collect palette names.
        const names = [];
        if (data.palettes) {
            for (const name in data.palettes) {
                names.push(name);
            }
        }
        root.paletteNames = names;

        // Expose full data for PaletteEditor (no second FileView needed).
        root.allPaletteData = data;
    }
}

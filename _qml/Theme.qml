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
/// Default values are mokume so the shell works before first apply.
Singleton {
    id: root

    // ── Resolved config path ────────────────────────────────────────

    readonly property string themesDir: ConfigService.configHome + "/garden/themes"

    // ── Surface colors ──────────────────────────────────────────────

    property color baseDeep:   "#252d3b"
    property color base:       "#2c3444"
    property color baseRaised: "#343d4f"
    property color baseHl:     "#3d4759"

    // ── Border colors ───────────────────────────────────────────────

    property color borderSub:  "#3a4456"
    property color border:     "#4a5568"

    // ── Text hierarchy ──────────────────────────────────────────────

    property color text4:      "#505e70"
    property color text3:      "#6b7a8d"
    property color text2:      "#8b9bb0"
    property color text1:      "#d4c5a9"

    // ── Semantic colors ─────────────────────────────────────────────

    property color accent:     "#c9b88c"
    property color urgent:     "#c4796b"
    property color ok:         "#7c9a7c"

    // ── Palette metadata ────────────────────────────────────────────

    property string activePalette: "mokume"
    property string paletteIcon:   "◐"
    property var paletteNames:     []

    // ── Fonts ───────────────────────────────────────────────────────

    readonly property string sansFont: "M PLUS 1p"
    readonly property string monoFont: "IBM Plex Mono"

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

    // ── Internal: parse JSON and update colors ──────────────────────

    function _loadPalette(jsonStr: string) {
        let data;
        try {
            data = JSON.parse(jsonStr);
        } catch (e) {
            console.warn("Theme: failed to parse palettes.json:", e);
            return;
        }

        const activeName = data.active || "mokume";
        const palette = data.palettes?.[activeName];
        if (!palette) {
            console.warn("Theme: active palette", activeName, "not found in cache");
            return;
        }

        const c = palette.colors;
        if (!c) return;

        // Update all 13 colors (hard cut, no animation).
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
    }
}

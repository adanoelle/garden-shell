pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/// Reads and exposes settings.json configuration.
///
/// Provides bar position, per-channel mode configuration, and other
/// shell settings. Watches the file for live updates.
Singleton {
    id: root

    // ── Resolved config path ────────────────────────────────────────

    readonly property string configHome: Quickshell.env("XDG_CONFIG_HOME")
        || (Quickshell.env("HOME") + "/.config")
    readonly property string settingsPath: configHome + "/garden/settings.json"

    // ── Exposed settings ────────────────────────────────────────────

    /// Active palette name (read from settings, authoritative source is palettes.toml).
    property string palette: "mokume"

    /// Bar position: "top" or "bottom".
    property string barPosition: "top"

    /// Per-channel mode configuration.
    /// Map of channel name → { modes: string[] }
    property var channels: ({})

    // ── Typography ──────────────────────────────────────────────────
    //
    // Shell-wide faces (not per palette), from settings.json's
    // `fonts: { sans, mono }`. Theme.sansFont / Theme.monoFont follow
    // these; Settings → palette → typography writes them via setFont().

    readonly property string defaultSansFont: "M PLUS 1"
    readonly property string defaultMonoFont: "IBM Plex Mono"

    property string sansFont: defaultSansFont
    property string monoFont: defaultMonoFont

    /// Faces offered in the settings panel (it shows only the installed
    /// ones). Family names as fontconfig reports them: Commit Mono's
    /// family is "CommitMono".
    readonly property var sansFontChoices: ["M PLUS 1", "Liberation Sans", "IBM Plex Sans"]
    readonly property var monoFontChoices: ["IBM Plex Mono", "CommitMono"]

    // ── Settings file watcher ───────────────────────────────────────

    FileView {
        id: settingsFile
        path: root.settingsPath
        watchChanges: true
        blockLoading: true
        atomicWrites: true

        onLoaded: {
            const content = settingsFile.text();
            if (content.length > 0) root._loadSettings(content);
        }
        onFileChanged: {
            settingsFile.reload();
        }
    }

    // ── Parse settings ──────────────────────────────────────────────

    function _loadSettings(jsonStr: string) {
        let data;
        try {
            data = JSON.parse(jsonStr);
        } catch (e) {
            console.warn("ConfigService: failed to parse settings.json:", e);
            return;
        }

        root.palette     = data.palette        || root.palette;
        root.barPosition = data.bar?.position   || root.barPosition;
        root.channels    = data.channels        || root.channels;
        root.sansFont    = data.fonts?.sans     || root.defaultSansFont;
        root.monoFont    = data.fonts?.mono     || root.defaultMonoFont;
    }

    // ── Write ───────────────────────────────────────────────────────

    /// Set a UI face and persist it to settings.json.
    /// role: "sans" or "mono". Applies immediately; other keys in the
    /// file are preserved.
    function setFont(role: string, family: string) {
        if (role !== "sans" && role !== "mono") return;
        let data = {};
        const content = settingsFile.text();
        if (content.length > 0) {
            try {
                data = JSON.parse(content);
            } catch (e) {
                console.warn("ConfigService: settings.json is not valid JSON; not writing fonts:", e);
                return;
            }
        }
        data.fonts = Object.assign({}, data.fonts, { [role]: family });
        if (role === "sans") root.sansFont = family;
        else root.monoFont = family;
        settingsFile.setText(JSON.stringify(data, null, 2) + "\n");
    }
}

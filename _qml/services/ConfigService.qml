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

    // ── Settings file watcher ───────────────────────────────────────

    FileView {
        id: settingsFile
        path: root.settingsPath
        watchChanges: true
        blockLoading: true

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
    }
}

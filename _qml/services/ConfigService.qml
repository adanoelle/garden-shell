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
    /// family is "CommitMono". Mono choices must be monospaced: they also
    /// drive the terminals (see _syncTerminalFonts), which lay text out
    /// on a fixed cell grid — hence Liberation Mono, not Liberation Sans.
    readonly property var sansFontChoices: ["M PLUS 1", "Liberation Sans", "IBM Plex Sans"]
    readonly property var monoFontChoices: ["IBM Plex Mono", "CommitMono", "Liberation Mono"]

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
        root._syncTerminalFonts();
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
        root._syncTerminalFonts();
    }

    // ── Terminal fonts ──────────────────────────────────────────────
    //
    // The mono choice also drives the terminals. These small files are
    // included by the terminal configs (kitty: `globinclude
    // ../garden/fonts/kitty.conf` from garden.terminal; Ghostty:
    // `config-file = ?…/garden/fonts/ghostty` from the consumer), so a
    // missing file is harmless. They are rewritten only when their content
    // changes, and only then are running terminals told to reload
    // (kitty: SIGUSR1, Ghostty: SIGUSR2). New terminal windows always use
    // the chosen face; kitty keeps the font of windows that are already
    // open across a config reload (verified on kitty 0.47), so those
    // change when reopened.

    readonly property string fontsDir: configHome + "/garden/fonts"

    function _kittyFontConf(): string {
        return "# garden mono face — written by garden-shell"
            + " (Settings → palette → typography)\n"
            + "font_family " + root.monoFont;
    }

    function _ghosttyFontConf(): string {
        return "# garden mono face — written by garden-shell"
            + " (Settings → palette → typography)\n"
            + "font-family =\n"
            + "font-family = " + root.monoFont + "\n"
            + "font-family = FiraCode Nerd Font";
    }

    property bool _fontSyncPending: false

    function _syncTerminalFonts() {
        if (fontSync.running) {
            root._fontSyncPending = true;
            return;
        }
        fontSync.command = [
            "sh", "-c", root._fontSyncScript, "garden-fonts",
            root.fontsDir, root._kittyFontConf(), root._ghosttyFontConf()
        ];
        fontSync.running = true;
    }

    // $1 dir, $2 kitty.conf content, $3 ghostty content. Content arrives
    // as arguments, never through shell text, so no quoting pitfalls.
    readonly property string _fontSyncScript: '
        dir=$1; mkdir -p "$dir" || exit 1
        changed=0
        put() {
            if [ "$(cat "$dir/$1" 2>/dev/null)" != "$2" ]; then
                printf "%s\\n" "$2" > "$dir/$1.tmp" && mv "$dir/$1.tmp" "$dir/$1" && changed=1
            fi
        }
        put kitty.conf "$2"
        put ghostty "$3"
        if [ "$changed" = 1 ]; then
            pkill -USR1 kitty
            pkill -USR2 ghostty
            echo "terminal fonts updated"
        fi
        exit 0'

    Process {
        id: fontSync
        running: false
        stdout: SplitParser {
            onRead: data => console.log("ConfigService:", data)
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) console.warn("ConfigService: writing terminal font files failed");
            if (root._fontSyncPending) {
                root._fontSyncPending = false;
                root._syncTerminalFonts();
            }
        }
    }
}

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications
import ".."
import "."

/// Screenshot pipelines: region (slurp → grim -g), window (niri
/// builtin), output (grim -o). Save + copy always; success surfaces as
/// a rich notification card with thumbnail + actions.
///
/// Window mode delegates to `niri msg action screenshot-window`
/// because niri's focused-window JSON is workspace-relative with
/// `tile_pos_in_workspace_view` sometimes null — coordinate math for
/// `grim -g` is unreliable. Niri writes into `screenshot-path`
/// (= `dir` below, set in fern niri.nix) and we adopt the newest file
/// via snapshot-diff polling.
///
/// Hot-reload mid-capture resets state; an orphaned slurp stays up
/// until Esc — cosmetic only.
Singleton {
    id: root

    readonly property string dir: Quickshell.env("HOME") + "/media/screenshots"

    /// Single-flight latch; `capture` refuses while set.
    property bool _busy: false
    property string _mode: ""
    property string _file: ""

    /// Window mode: newest file in dir before the capture.
    property string _preNewest: ""
    property int _pollTicks: 0

    // ── Public API ──────────────────────────────────────────────────

    /// IPC entry point (`screenshot <mode>`).
    function capture(mode: string): string {
        if (root._busy) return "screenshot busy";
        if (mode !== "region" && mode !== "window" && mode !== "output")
            return "unknown mode " + mode + " (region|window|output)";

        root._busy = true;
        root._mode = mode;
        root._file = "";

        if (mode === "region") {
            // Fixed dark scrim (a themed light base is invisible on a
            // light desktop); only the selection border is themed.
            // stdin MUST be /dev/null: with a non-tty stdin (Process
            // gives a pipe) slurp blocks reading predefined boxes
            // until EOF and never maps its overlay.
            slurpProcess.command = ["sh", "-c",
                'exec slurp -b "$1" -c "$2" -s "#00000000" -w 2 < /dev/null',
                "garden-slurp",
                "#00000066",                          // dim unselected
                root._hex8(Theme.accent, "ff")];      // selection border
            slurpProcess.running = true;
        } else if (mode === "output") {
            outputQuery.running = true;
        } else {
            snapshotQuery.phase = "pre";
            snapshotQuery.running = true;
        }
        return "screenshot " + mode;
    }

    // ── Helpers ─────────────────────────────────────────────────────

    /// QML colors stringify as #rrggbb or #aarrggbb; slurp wants
    /// #rrggbbaa. Strip any leading alpha, append the given one.
    function _hex8(c, alpha) {
        const s = String(c);
        const rgb = s.length === 9 ? s.slice(3) : s.slice(1);
        return "#" + rgb + alpha;
    }

    function _stamp(): string {
        return Qt.formatDateTime(new Date(), "yyyy-MM-dd_hh-mm-ss");
    }

    /// Card-sized stderr snippet: first line, sans "Error:" prefix,
    /// clamped to 60 chars (NetworkService idiom).
    function _clamp(text): string {
        let msg = String(text).split("\n")[0]
            .replace(/^Error:\s*/, "").trim();
        if (msg.length > 60) msg = msg.slice(0, 60) + "\u2026";
        return msg;
    }

    /// Sole terminal — every path (success / cancel / error / timeout)
    /// ends here. Non-empty err → urgent card (never auto-expires).
    function _finish(err) {
        root._busy = false;
        if (err) NotificationService.sendSynthetic("screenshot failed", err,
                                                   NotificationUrgency.Critical);
    }

    // wl-copy daemonizes (forks, parent exits) so a reusable Process
    // is fine. Data passed as positional args, never interpolated.
    function _copyFile(f) {
        copyProcess.command = ["sh", "-c", 'wl-copy --type image/png < "$1"',
                               "garden-shot", f];
        copyProcess.running = true;
    }

    function _notifySuccess() {
        const f = root._file;   // closures capture by value
        NotificationService.sendRich(
            "screenshot", root._mode + " \u00b7 " + f.split("/").pop(),
            [   // order is load-bearing: card click-anywhere invokes [0]
                { text: "copy",   invoke: () => root._copyFile(f) },
                { text: "open",   invoke: () => Quickshell.execDetached(["xdg-open", f]) },
                { text: "edit",   invoke: () => Quickshell.execDetached(
                      ["satty", "--filename", f, "--output-filename", f, "--early-exit"]) },
                { text: "delete", invoke: () => Quickshell.execDetached(["rm", "--", f]) }
            ],
            "file://" + f);
        root._finish("");
    }

    // ── Region: slurp → grim -g ─────────────────────────────────────

    Process {
        id: slurpProcess
        stdout: StdioCollector { id: slurpOut }
        stderr: StdioCollector { id: slurpErr }
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                // Esc/cancel exits nonzero with empty stderr → silent.
                root._finish(root._clamp(slurpErr.text));
                return;
            }
            const geometry = slurpOut.text.trim();
            if (geometry === "") { root._finish(""); return; }
            root._file = root.dir + "/" + root._stamp() + "-region.png";
            captureProcess.command = ["sh", "-c",
                'mkdir -p "$(dirname "$2")" && grim -g "$1" "$2"'
                + ' && wl-copy --type image/png < "$2"',
                "garden-shot", geometry, root._file];
            captureProcess.running = true;
        }
    }

    // ── Output: focused-output name → grim -o ───────────────────────

    Process {
        id: outputQuery
        command: ["niri", "msg", "-j", "focused-output"]
        stdout: StdioCollector { id: outputOut }
        stderr: StdioCollector { id: outputErr }
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                root._finish(root._clamp(outputErr.text)
                             || "focused-output query failed");
                return;
            }
            let name = "";
            try { name = JSON.parse(outputOut.text).name || ""; } catch (e) {}
            if (name === "") {
                root._finish("could not determine focused output");
                return;
            }
            root._file = root.dir + "/" + root._stamp() + "-output.png";
            captureProcess.command = ["sh", "-c",
                'mkdir -p "$(dirname "$2")" && grim -o "$1" "$2"'
                + ' && wl-copy --type image/png < "$2"',
                "garden-shot", name, root._file];
            captureProcess.running = true;
        }
    }

    // Shared capture+copy failure domain for region and output.
    Process {
        id: captureProcess
        stderr: StdioCollector { id: captureErr }
        onExited: (exitCode) => {
            if (exitCode !== 0)
                root._finish(root._clamp(captureErr.text) || "capture failed");
            else
                root._notifySuccess();
        }
    }

    // ── Window: niri builtin + snapshot-diff adoption ───────────────

    // Newest file in dir; runs once before the capture ("pre") and
    // then per poll tick ("poll") until the answer changes.
    Process {
        id: snapshotQuery
        property string phase: "pre"
        command: ["sh", "-c", 'ls -1t "$1" 2>/dev/null | head -1',
                  "garden-ls", root.dir]
        stdout: StdioCollector { id: snapshotOut }
        onExited: {
            const newest = snapshotOut.text.trim();
            if (snapshotQuery.phase === "pre") {
                root._preNewest = newest;   // empty dir → ""
                windowShot.running = true;
                return;
            }
            if (newest !== "" && newest !== root._preNewest) {
                pollTimer.stop();
                root._file = root.dir + "/" + newest;
                root._copyFile(root._file);   // uniform even if niri copied
                root._notifySuccess();
            }
        }
    }

    Process {
        id: windowShot
        command: ["niri", "msg", "action", "screenshot-window"]
        stderr: StdioCollector { id: windowErr }
        onExited: (exitCode) => {
            if (exitCode !== 0) {
                root._finish(root._clamp(windowErr.text)
                             || "screenshot-window failed");
                return;
            }
            root._pollTicks = 0;
            pollTimer.start();
        }
    }

    Timer {
        id: pollTimer
        interval: 250
        repeat: true
        onTriggered: {
            root._pollTicks++;
            if (root._pollTicks > 12) {   // ≈3 s budget
                pollTimer.stop();
                root._finish("screenshot-window produced no file");
                return;
            }
            snapshotQuery.phase = "poll";
            snapshotQuery.running = true;
        }
    }

    Process {
        id: copyProcess
    }
}

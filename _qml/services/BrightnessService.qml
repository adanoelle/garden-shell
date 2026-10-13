pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/// Reactive display brightness (read-only — keybinds own writes).
///
/// Two backends, picked once at startup:
///
///   backlight — laptop panels. Reads /sys/class/backlight/<dev>/
///               brightness every 500 ms (sysfs attributes don't
///               deliver inotify events). Prefers a native device
///               (intel_backlight, amdgpu_bl0) over acpi_video*.
///   ddc       — external monitors over DDC/CI. Polls
///               `ddcutil getvcp 10` every 3 s ("VCP code 0x10
///               (Brightness): current value = 50, max value = 100").
///               Needs hardware.i2c.enable and the i2c group; gives up
///               after 3 failures if it never succeeded once.
///
/// `available` is false until a backend has produced a reading, so the
/// bar slot stays hidden on machines with neither.
Singleton {
    id: root

    /// Current brightness, 0.0–1.0.
    property real brightness: 1.0

    /// A backend is producing readings.
    property bool available: false

    /// "backlight" | "ddc" | "" (none / still detecting).
    property string backend: ""

    /// Emitted on brightness changes after the first successful read —
    /// the OSD trigger. The initial read on login does not fire this.
    signal stateChanged()

    /// True once the first successful read has landed.
    property bool _settled: false

    /// Guard for setSilently — suppresses stateChanged for optimistic
    /// updates whose caller shows the OSD itself.
    property bool _silent: false

    onBrightnessChanged: if (root._settled && !root._silent) root.stateChanged()

    /// Update brightness state from an optimistic external source (IPC)
    /// without firing stateChanged. Keeps the next poll from re-showing
    /// the OSD when it confirms the same value.
    function setSilently(value) {
        root._silent = true;
        root.brightness = Math.max(0, Math.min(1, value));
        root._silent = false;
    }

    function _accept(current, max) {
        if (isNaN(current) || isNaN(max) || max <= 0) return;
        root.brightness = Math.max(0, Math.min(1, current / max));
        root.available = true;
        root._settled = true;
    }

    // ── Backend detection ───────────────────────────────────────────

    property string _device: ""

    Process {
        id: detect
        running: true
        command: ["sh", "-c", "ls -1 /sys/class/backlight 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const devs = text.split("\n").filter(d => d.length > 0);
                const dev = devs.find(d => !d.startsWith("acpi_video")) ?? devs[0] ?? "";
                root._device = dev;
                root.backend = dev ? "backlight" : "ddc";
            }
        }
    }

    // ── backlight ───────────────────────────────────────────────────

    readonly property string _sysDir: "/sys/class/backlight/" + root._device

    property int _max: 0

    FileView {
        id: maxFile
        path: root.backend === "backlight" ? root._sysDir + "/max_brightness" : ""
        onLoaded: root._max = parseInt(maxFile.text(), 10)
    }

    FileView {
        id: curFile
        path: root.backend === "backlight" ? root._sysDir + "/brightness" : ""
        onLoaded: root._accept(parseInt(curFile.text(), 10), root._max)
    }

    Timer {
        interval: 500
        repeat: true
        running: root.backend === "backlight" && root._max > 0
        onTriggered: curFile.reload()
    }

    // ── ddc ─────────────────────────────────────────────────────────

    /// Consecutive failed polls; persistent failure is logged once.
    property int _ddcFailures: 0

    Timer {
        interval: 3000
        repeat: true
        triggeredOnStart: true
        running: root.backend === "ddc" && (root.available || root._ddcFailures < 3)
        onTriggered: ddcPoll.running = true
    }

    Process {
        id: ddcPoll
        command: ["ddcutil", "getvcp", "10"]
        stdout: SplitParser {
            onRead: data => {
                const m = data.match(/current value =\s*(\d+),\s*max value =\s*(\d+)/);
                if (m) root._accept(parseInt(m[1], 10), parseInt(m[2], 10));
            }
        }
        stderr: StdioCollector { id: ddcErr }
        onExited: (exitCode, exitStatus) => {
            if (exitCode === 0) {
                root._ddcFailures = 0;
                return;
            }
            root._ddcFailures++;
            if (root._ddcFailures === 3) {
                console.warn("BrightnessService: ddcutil failing (exit " + exitCode + ")"
                    + (root.available ? " \u2014 brightness state may be stale"
                                      : " \u2014 no brightness backend, giving up")
                    + ": " + ddcErr.text.split("\n")[0]);
            }
        }
    }
}

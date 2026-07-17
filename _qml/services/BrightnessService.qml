pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/// Reactive brightness state via DDC/CI (ddcutil).
///
/// Polls `ddcutil getvcp 10` every 3s to read monitor brightness.
/// Output: "VCP code 0x10 (Brightness): current value = 50, max value = 100"
///
/// Requires: hardware.i2c.enable = true in NixOS, user in i2c group.
Singleton {
    id: root

    /// Current brightness, 0.0–1.0.
    property real brightness: 1.0

    /// Emitted on brightness changes after the first successful read —
    /// the OSD trigger. The initial read on login does not fire this.
    signal stateChanged()

    /// True once the first successful read has landed.
    property bool _settled: false

    /// Tracks whether we already warned about a failing poll, so a
    /// persistent failure doesn't spam the log every 3s.
    property bool _warned: false

    onBrightnessChanged: if (root._settled) root.stateChanged()

    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: _poll.running = true
    }

    Process {
        id: _poll
        command: ["ddcutil", "getvcp", "10"]
        stdout: SplitParser {
            onRead: data => {
                const m = data.match(/current value =\s*(\d+),\s*max value =\s*(\d+)/)
                if (m) {
                    const current = parseInt(m[1], 10)
                    const max = parseInt(m[2], 10)
                    if (!isNaN(current) && !isNaN(max) && max > 0) {
                        root.brightness = Math.max(0, Math.min(1, current / max))
                        root._settled = true
                    }
                }
            }
        }
        stderr: SplitParser {
            onRead: data => {
                if (!root._warned) console.warn("BrightnessService: ddcutil:", data)
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                if (!root._warned) {
                    console.warn("BrightnessService: ddcutil exited with code", exitCode,
                                 "— brightness state may be stale")
                    root._warned = true
                }
            } else {
                root._warned = false
            }
        }
    }
}

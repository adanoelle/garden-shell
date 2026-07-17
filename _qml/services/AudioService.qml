pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/// Reactive volume and mute state via wpctl polling.
///
/// Polls `wpctl get-volume @DEFAULT_AUDIO_SINK@` every 500ms.
/// Output format: "Volume: 0.70" or "Volume: 0.70 [MUTED]"
Singleton {
    id: root

    /// Current volume, 0.0–1.0.
    property real volume: 0.0

    /// Whether the sink is muted.
    property bool muted: false

    /// Tracks whether we already warned about a failing poll, so a
    /// persistent failure doesn't spam the log every 500ms.
    property bool _warned: false

    Timer {
        interval: 500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: _poll.running = true
    }

    Process {
        id: _poll
        command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]
        stdout: SplitParser {
            onRead: data => {
                const m = data.match(/Volume:\s*([\d.]+)(\s+\[MUTED\])?/)
                if (m) {
                    const v = parseFloat(m[1])
                    if (!isNaN(v)) {
                        root.volume = Math.max(0, Math.min(1, v))
                        root.muted  = !!m[2]
                    }
                }
            }
        }
        stderr: SplitParser {
            onRead: data => {
                if (!root._warned) console.warn("AudioService: wpctl:", data)
            }
        }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                if (!root._warned) {
                    console.warn("AudioService: wpctl exited with code", exitCode,
                                 "— volume state may be stale")
                    root._warned = true
                }
            } else {
                root._warned = false
            }
        }
    }
}

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../compositor"

/// Signal hub and external IPC API for the Garden shell.
///
/// Emits signals when shell events occur. Exposes an IPC handler so
/// external tools can control the shell via `qs ipc call garden <method>`.
Singleton {
    id: root

    // ── Signals ─────────────────────────────────────────────────────

    signal channelSwitched(string name)
    signal paletteChanged(string name)

    // ── IPC handler ─────────────────────────────────────────────────

    IpcHandler {
        target: "garden"

        function switchPalette(name: string): string {
            Theme.switchPalette(name);
            root.paletteChanged(name);
            return "switching to " + name;
        }

        function switchChannel(name: string): string {
            CompositorService.focusWorkspace(name);
            root.channelSwitched(name);
            return "switching to " + name;
        }

        function getChannel(): string {
            return CompositorService.activeWorkspace;
        }

        function getPalette(): string {
            return Theme.activePalette;
        }
    }
}

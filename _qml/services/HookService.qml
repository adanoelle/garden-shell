pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import "."
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
    signal launcherToggled()
    signal switcherToggled()
    signal settingsToggled()
    signal notificationsSuppressed(bool suppressed)
    signal notificationCenterToggled()
    signal focusSessionChanged(bool active)

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

        function toggleLauncher(): string {
            root.launcherToggled();
            return "toggled launcher";
        }

        function toggleSwitcher(): string {
            root.switcherToggled();
            return "toggled switcher";
        }

        function toggleSettings(): string {
            root.settingsToggled();
            return "toggled settings";
        }

        function suppressNotifications(suppress: bool): string {
            NotificationService.setSuppressed(suppress);
            root.notificationsSuppressed(suppress);
            return suppress ? "notifications suppressed" : "notifications active";
        }

        function toggleNotifications(): string {
            NotificationService.toggleSuppressed();
            const on = NotificationService.globallySuppressed;
            root.notificationsSuppressed(on);
            return on ? "notifications suppressed" : "notifications active";
        }

        function toggleNotificationCenter(): string {
            root.notificationCenterToggled();
            return "toggled notification center";
        }

        function focusStart(): string {
            NotificationService.setFocus(true);
            root.focusSessionChanged(true);
            return "focus session started";
        }

        function focusEnd(): string {
            NotificationService.setFocus(false);
            root.focusSessionChanged(false);
            return "focus session ended";
        }
    }
}

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
    signal lockRequested()
    signal powerMenuToggled()
    signal brightnessOsdRequested(real value)
    signal trayToggled()

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

        function lock(): string {
            root.lockRequested();
            return "locking session";
        }

        function togglePowerMenu(): string {
            root.powerMenuToggled();
            return "toggled power menu";
        }

        function toggleTray(): string {
            root.trayToggled();
            return "toggled tray panel";
        }

        /// Show the brightness OSD immediately at an absolute percent
        /// (0–100) — optimistic path for external brightness changes.
        function showBrightnessOsd(value: real): string {
            const frac = Math.max(0, Math.min(1, value / 100));
            BrightnessService.setSilently(frac);
            root.brightnessOsdRequested(frac);
            return "brightness osd " + Math.round(frac * 100) + "%";
        }

        /// Relative variant for keybinds that step the hardware with
        /// ddcutil "+ 5"/"- 5": computes new value from the shell's
        /// known brightness, shows the OSD, returns the new percent.
        function stepBrightnessOsd(delta: real): string {
            const frac = Math.max(0, Math.min(1,
                BrightnessService.brightness + delta / 100));
            BrightnessService.setSilently(frac);
            root.brightnessOsdRequested(frac);
            return "brightness osd " + Math.round(frac * 100) + "%";
        }

        function focusEnd(): string {
            NotificationService.setFocus(false);
            root.focusSessionChanged(false);
            return "focus session ended";
        }
    }
}

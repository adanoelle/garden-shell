import Quickshell
import Quickshell.Wayland
import "bar"
import "compositor"
import "notifications"
import "overlays"
import "services"

/// Garden Shell — root entry point.
///
/// Creates a Bar instance for each connected screen and instantiates
/// overlay windows (launcher, channel switcher). Singletons
/// (Theme, CompositorService, NiriAdapter, ConfigService, HookService,
/// ModeService) are auto-loaded by Quickshell from their pragma
/// Singleton declarations.
ShellRoot {
    // Force singleton instantiation — QML singletons are lazy, so we
    // reference each one to ensure event streams and IPC handlers start.
    property var _hooks: HookService
    property var _niri: NiriAdapter
    property var _config: ConfigService
    property var _mode: ModeService
    property var _audio: AudioService
    property var _brightness: BrightnessService
    property var _notifications: NotificationService

    Variants {
        model: Quickshell.screens

        Bar {
            required property var modelData
            screen: modelData
        }
    }

    // Overlays (hidden until toggled via IPC).
    Launcher {}
    ChannelSwitcher {}
    Settings {}
    NotificationCenter {}

    // Non-modal windows (no focus grab, exclusiveZone 0).
    NotificationPopups {}
}

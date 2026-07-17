import QtQuick
import ".."
import "../services"

/// Ambient volume and brightness indicators for the bar.
///
/// Two compact slots — `v{n}` and `b{n}` — sit at near-invisible text-4
/// opacity at rest. When a value changes the affected slot brightens to
/// text-1 for 1.5s then fades back. Muted state shows `vm` in Theme.urgent.
/// Hidden entirely in minimal bar mode.
Row {
    id: root

    spacing: 8
    visible: ModeService.showContent

    BarStateSlot {
        id: volSlot
        prefix: "v"
        value: AudioService.muted
                   ? "m"
                   : Math.round(AudioService.volume * 100).toString()
        activeColor: AudioService.muted ? Theme.urgent : Theme.text1

        Connections {
            target: AudioService
            function onStateChanged() { volSlot._trigger() }
        }
    }

    BarStateSlot {
        id: briSlot
        prefix: "b"
        value: Math.round(BrightnessService.brightness * 100).toString()

        Connections {
            target: BrightnessService
            function onStateChanged() { briSlot._trigger() }
        }
    }
}

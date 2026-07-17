pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire

/// Reactive volume and mute state for the default audio sink.
///
/// Backed by Quickshell's native Pipewire service — state updates are
/// event-driven (no polling). The sink node must be bound via
/// PwObjectTracker before its properties populate.
Singleton {
    id: root

    /// The default audio sink node (may be null before Pipewire connects).
    readonly property var sink: Pipewire.defaultAudioSink

    /// Current volume, 0.0–1.0.
    readonly property real volume: {
        const v = root.sink?.audio?.volume ?? 0;
        return Math.max(0, Math.min(1, v));
    }

    /// Whether the sink is muted.
    readonly property bool muted: root.sink?.audio?.muted ?? false

    /// Whether the sink is bound and reporting real state.
    readonly property bool ready: root.sink?.ready ?? false

    /// Emitted on volume/mute changes after startup settles — the OSD
    /// trigger. Initial state population on login does not fire this.
    signal stateChanged()

    /// True once the sink's initial state has landed.
    property bool _settled: false

    // ── Control ─────────────────────────────────────────────────────

    function setVolume(v: real) {
        if (root.sink?.ready && root.sink.audio)
            root.sink.audio.volume = Math.max(0, Math.min(1, v));
    }

    function toggleMute() {
        if (root.sink?.ready && root.sink.audio)
            root.sink.audio.muted = !root.sink.audio.muted;
    }

    // ── Change tracking ─────────────────────────────────────────────

    onVolumeChanged: if (root._settled) root.stateChanged()
    onMutedChanged:  if (root._settled) root.stateChanged()

    // Settle one tick after the sink reports ready, so the initial
    // volume/mute population doesn't count as a state change.
    onReadyChanged: {
        if (root.ready && !root._settled)
            Qt.callLater(() => { root._settled = true; });
    }

    // Bind the sink node so volume/mute properties are populated.
    PwObjectTracker {
        objects: [ root.sink ]
    }
}

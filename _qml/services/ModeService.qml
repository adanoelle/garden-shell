pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "."
import "../compositor"

/// Per-channel mode management.
///
/// Maps each channel (workspace) to a stack of active modes read from
/// ConfigService. Bars are per output, so bar modes are looked up per
/// channel (`barModeFor`) — each bar follows the workspace visible on
/// its own output. The focused-channel properties (`activeModes`,
/// `currentHeight`, …) serve global consumers: notification suppression
/// and the anchored panels, which open on the focused output.
Singleton {
    id: root

    // ── Bar height constants ────────────────────────────────────────

    readonly property int fullHeight:     34
    readonly property int standardHeight: 30
    readonly property int minimalHeight:  2

    // ── Per-channel lookups ─────────────────────────────────────────

    /// Mode stack for a channel (empty array when unset).
    function modesFor(channel: string): var {
        const modes = ConfigService.channels?.[channel]?.modes;
        return Array.isArray(modes) ? modes : [];
    }

    /// First bar-related mode in a channel's stack, "standard-bar" if none.
    function barModeFor(channel: string): string {
        for (const m of root.modesFor(channel)) {
            if (m.endsWith("-bar")) return m;
        }
        return "standard-bar";
    }

    /// Bar height for a bar mode.
    function heightFor(barMode: string): int {
        switch (barMode) {
        case "full-bar":    return root.fullHeight;
        case "minimal-bar": return root.minimalHeight;
        default:            return root.standardHeight;
        }
    }

    // ── Focused channel ─────────────────────────────────────────────

    /// The focused channel's mode stack.
    readonly property var activeModes: root.modesFor(CompositorService.activeWorkspace)

    /// Whether the focused channel has the named mode
    /// (e.g. "suppress-notifications", "mpris-ambient").
    function hasMode(name: string): bool {
        return root.activeModes.includes(name);
    }

    /// The focused channel's bar mode.
    readonly property string barMode: root.barModeFor(CompositorService.activeWorkspace)

    /// The focused channel's bar height.
    readonly property int currentHeight: root.heightFor(root.barMode)

    /// Offset for cards dropping from the focused output's bar.
    ///
    /// Panel surfaces (exclusive zone 0) are already laid out below the
    /// bar's exclusive zone, so the bar's height must not be added again.
    /// A minimal bar reserves only 2 px but is expanded (hovered) when
    /// clicked, overlaying the top of that space — clear the expansion.
    readonly property int panelOffset: (root.barMode === "minimal-bar"
        ? root.standardHeight - root.minimalHeight : 0) + 4
}

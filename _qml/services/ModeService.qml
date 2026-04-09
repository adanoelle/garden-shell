pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import "."
import "../compositor"

/// Per-channel mode management.
///
/// Maps each channel (workspace) to a stack of active modes read from
/// ConfigService. The bar height and visibility of various elements
/// depend on the current channel's bar mode.
Singleton {
    id: root

    // ── Bar height constants ────────────────────────────────────────

    readonly property int fullHeight:     34
    readonly property int standardHeight: 30
    readonly property int minimalHeight:  2

    // ── Computed bar state ───────────────────────────────────────────

    /// Current bar height based on the active channel's mode.
    readonly property int currentHeight: {
        switch (root.barMode) {
        case "full-bar":     return root.fullHeight;
        case "standard-bar": return root.standardHeight;
        case "minimal-bar":  return root.minimalHeight;
        default:             return root.standardHeight;
        }
    }

    /// Whether the bar should show content (not minimal).
    readonly property bool showContent: barMode !== "minimal-bar"

    /// Whether to show extended info (date, etc.) — full mode only.
    readonly property bool showExtended: barMode === "full-bar"

    /// The bar mode string for the current channel.
    readonly property string barMode: {
        const channel = CompositorService.activeWorkspace;
        const config = ConfigService.channels?.[channel];
        const modes = config?.modes;

        if (Array.isArray(modes)) {
            // Find the first bar-related mode.
            for (const m of modes) {
                if (m.endsWith("-bar")) return m;
            }
        }

        return "standard-bar";
    }
}

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/// Compositor state, per output.
///
/// NiriAdapter populates these properties from the niri event stream;
/// views bind to them. Everything here is compositor-agnostic — a
/// Hyprland adapter would fill the same shapes.
///
/// Workspace entry (`workspaces[]`, `outputs[o].workspaces[]`):
///   { id, idx, name, label, output, active, focused, urgent,
///     windowCount, columns: [Column], floating: [Window] }
///
///   name     — compositor name, "" for unnamed workspaces
///   label    — name, or the index for unnamed workspaces
///   active   — the visible workspace on its output (one per output)
///   focused  — the workspace holding keyboard focus (one globally)
///
/// Column entry: { index, id, appId, title, tiles, focused, active, x, w }
///   id/appId/title — the column's most recently focused tile
///   tiles          — tile count (stacked windows in the column)
///   active         — holds its workspace's active window
///   x, w           — tile position/width in the workspace view (px),
///                    x is null when the compositor reports no position
///
/// Window entry (floating): { id, appId, title, focused }
Singleton {
    id: root

    /// All workspaces, ordered by output then index on that output.
    property var workspaces: []

    /// Map of output name → { name, focused, active, workspaces }.
    /// `active` is the output's visible workspace entry (or null).
    property var outputs: ({})

    /// Name of the output holding keyboard focus.
    property string focusedOutput: ""

    /// Name of the focused workspace / channel (label for unnamed ones).
    property string activeWorkspace: ""

    /// Emitted whenever the focused workspace changes.
    signal workspaceChanged(string name)

    /// State for one output, falling back to the focused output when
    /// the name is unknown (e.g. a placeholder screen during hotplug).
    function outputState(name: string): var {
        return root.outputs[name] ?? root.outputs[root.focusedOutput] ?? null;
    }

    /// Switch focus to a named workspace.
    function focusWorkspace(name: string) {
        NiriAdapter.focusWorkspace(name);
    }

    /// Switch focus to a workspace entry — works for unnamed workspaces
    /// and for workspaces on another output.
    function focusWorkspaceEntry(ws: var) {
        if (!ws) return;
        if (ws.name) NiriAdapter.focusWorkspace(ws.name);
        else NiriAdapter.focusWorkspaceOn(ws.output, ws.idx);
    }

    /// Focus a window by id.
    function focusWindow(id: int) {
        NiriAdapter.focusWindow(id);
    }

    /// Move focus one column to the left.
    function focusColumnLeft() {
        NiriAdapter.runAction("focus-column-left");
    }

    /// Move focus one column to the right.
    function focusColumnRight() {
        NiriAdapter.runAction("focus-column-right");
    }
}

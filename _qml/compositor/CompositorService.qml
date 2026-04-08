pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell

/// Compositor state exposing workspace and column properties.
///
/// NiriAdapter populates these properties from the Niri event stream.
/// Bar components bind to them for display.
Singleton {
    id: root

    /// Name of the currently focused workspace / channel.
    property string activeWorkspace: ""

    /// List of columns on the active workspace.
    /// Each entry: { id: int, title: string, appId: string, focused: bool, visible: bool }
    property var columns: []

    /// List of all workspaces.
    /// Each entry: { name: string, columnCount: int, active: bool }
    property var workspaces: []

    /// Emitted whenever the active workspace changes.
    signal workspaceChanged(string name)

    /// Switch focus to a named workspace.
    function focusWorkspace(name: string) {
        NiriAdapter.focusWorkspace(name);
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

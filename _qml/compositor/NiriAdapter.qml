pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/// Niri event stream consumer.
///
/// Connects to `niri msg -j event-stream` and parses the initial state
/// dump plus incremental events to keep CompositorService properties
/// in sync with the running compositor.
Singleton {
    id: root

    // ── Internal state ──────────────────────────────────────────────

    /// Workspace list: name → { name, active, windows: [id] }
    property var _workspaces: ({})

    /// Window list: id → { id, title, appId, workspaceName, isFocused }
    property var _windows: ({})

    /// Debounce timer for focus changes to prevent flicker.
    property int _pendingFocusWorkspace: -1

    // ── Public API ──────────────────────────────────────────────────

    function focusWorkspace(name: string) {
        _niriMsg(["action", "focus-workspace", name]);
    }

    function runAction(action: string) {
        _niriMsg(["action", action]);
    }

    /// Return all windows on the given workspace ID.
    function windowsForWorkspace(wsId: int): var {
        const result = [];
        for (const id in root._windows) {
            if (root._windows[id].workspaceId === wsId) {
                result.push(root._windows[id]);
            }
        }
        return result;
    }

    /// Look up a workspace ID by name. Returns -1 if not found.
    function workspaceId(name: string): int {
        const ws = root._workspaces[name];
        return ws ? ws.id : -1;
    }

    // ── Event stream process ────────────────────────────────────────

    Process {
        id: eventStream
        command: ["niri", "msg", "-j", "event-stream"]
        running: true

        stdout: SplitParser {
            onRead: message => root._handleEvent(message)
        }
    }

    // ── Debounce timer ──────────────────────────────────────────────

    Timer {
        id: focusDebounce
        interval: 80
        repeat: false
        onTriggered: root._applyFocusChange()
    }

    // ── Event handling ──────────────────────────────────────────────

    function _handleEvent(line: string) {
        let event;
        try {
            event = JSON.parse(line);
        } catch (e) {
            return;
        }

        // The event stream sends objects with a single key indicating the event type.
        const keys = Object.keys(event);
        if (keys.length === 0) return;
        const type = keys[0];
        const data = event[type];

        switch (type) {
        case "WorkspacesChanged":
            _handleWorkspacesChanged(data);
            break;
        case "WorkspaceActivated":
            _handleWorkspaceActivated(data);
            break;
        case "WindowsChanged":
            _handleWindowsChanged(data);
            break;
        case "WindowOpenedOrChanged":
            _handleWindowOpenedOrChanged(data);
            break;
        case "WindowClosed":
            _handleWindowClosed(data);
            break;
        case "WindowFocusChanged":
            _handleWindowFocusChanged(data);
            break;
        }
    }

    function _handleWorkspacesChanged(data) {
        const ws = {};
        if (Array.isArray(data.workspaces)) {
            for (const w of data.workspaces) {
                const name = w.name || `unnamed-${w.id}`;
                ws[name] = {
                    id: w.id,
                    name: name,
                    active: w.is_active || false,
                    output: w.output || "",
                    windows: []
                };
                if (w.is_active) {
                    root._pendingFocusWorkspace = w.id;
                }
            }
        }
        root._workspaces = ws;
        _syncWorkspaces();
    }

    function _handleWorkspaceActivated(data) {
        const id = data.id;
        const focused = data.focused;

        // Shallow-copy to ensure QML detects the property change.
        const ws = root._workspaces;
        const updated = {};
        for (const name in ws) {
            updated[name] = Object.assign({}, ws[name], { active: ws[name].id === id });
        }
        root._workspaces = updated;

        if (focused) {
            root._pendingFocusWorkspace = id;
            focusDebounce.restart();
        }
    }

    function _handleWindowsChanged(data) {
        const wins = {};
        if (Array.isArray(data.windows)) {
            for (const w of data.windows) {
                wins[w.id] = {
                    id: w.id,
                    title: w.title || "",
                    appId: w.app_id || "",
                    workspaceId: w.workspace_id,
                    isFocused: w.is_focused || false,
                    isVisible: true
                };
            }
        }
        root._windows = wins;
        _syncColumns();
        _syncWorkspaces();
    }

    function _handleWindowOpenedOrChanged(data) {
        const w = data.window || data;
        // Shallow-copy to ensure QML detects the property change.
        const wins = Object.assign({}, root._windows);
        wins[w.id] = {
            id: w.id,
            title: w.title || "",
            appId: w.app_id || "",
            workspaceId: w.workspace_id,
            isFocused: w.is_focused || false,
            isVisible: true
        };
        root._windows = wins;
        _syncColumns();
        _syncWorkspaces();
    }

    function _handleWindowClosed(data) {
        const id = data.id;
        // Shallow-copy to ensure QML detects the property change.
        const wins = Object.assign({}, root._windows);
        delete wins[id];
        root._windows = wins;
        _syncColumns();
        _syncWorkspaces();
    }

    function _handleWindowFocusChanged(data) {
        const focusedId = data.id; // null if no window focused
        // Shallow-copy to ensure QML detects the property change.
        const wins = {};
        for (const id in root._windows) {
            wins[id] = Object.assign({}, root._windows[id], {
                isFocused: parseInt(id, 10) === focusedId
            });
        }
        root._windows = wins;
        _syncColumns();
    }

    // ── Sync to CompositorService ───────────────────────────────────

    function _applyFocusChange() {
        const ws = root._workspaces;
        for (const name in ws) {
            if (ws[name].id === root._pendingFocusWorkspace) {
                if (CompositorService.activeWorkspace !== name) {
                    CompositorService.activeWorkspace = name;
                    CompositorService.workspaceChanged(name);
                }
                break;
            }
        }
        _syncColumns();
        _syncWorkspaces();
    }

    function _syncColumns() {
        // Find the active workspace ID.
        let activeWsId = -1;
        const ws = root._workspaces;
        for (const name in ws) {
            if (ws[name].active) {
                activeWsId = ws[name].id;
                break;
            }
        }

        // Collect windows on the active workspace as "columns".
        // Niri's scrollable layout means each top-level window is a column.
        const cols = [];
        const wins = root._windows;
        for (const id in wins) {
            const w = wins[id];
            if (w.workspaceId === activeWsId) {
                cols.push({
                    id: w.id,
                    title: w.title,
                    appId: w.appId,
                    focused: w.isFocused,
                    visible: w.isVisible
                });
            }
        }

        CompositorService.columns = cols;
    }

    function _syncWorkspaces() {
        const result = [];
        const ws = root._workspaces;
        const wins = root._windows;

        for (const name in ws) {
            let columnCount = 0;
            for (const id in wins) {
                if (wins[id].workspaceId === ws[name].id) {
                    columnCount++;
                }
            }
            result.push({
                name: name,
                columnCount: columnCount,
                active: ws[name].active
            });
        }

        CompositorService.workspaces = result;
    }

    // ── Helper ──────────────────────────────────────────────────────

    /// Reusable process for fire-and-forget niri commands.
    Process {
        id: actionProcess
        running: false
    }

    function _niriMsg(args: list<string>) {
        actionProcess.command = ["niri", "msg", "-j"].concat(args);
        actionProcess.running = true;
    }
}

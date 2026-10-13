pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/// Niri event stream consumer.
///
/// Mirrors niri's own workspace and window records (keyed by id) from
/// `niri msg -j event-stream`, applying each event with niri's
/// documented semantics, then derives the per-output shapes that
/// CompositorService exposes. Derivation is coalesced: a burst of
/// events (a workspace switch is several) produces one sync.
///
/// Semantics worth knowing (niri IPC docs):
///   - `is_active` is per output (every output has one active
///     workspace); `is_focused` is global. WorkspaceActivated only
///     deactivates workspaces on the *same* output.
///   - A focused WindowOpenedOrChanged unfocuses every other window.
///   - The initial dump is WorkspacesChanged + WindowsChanged only — no
///     WorkspaceActivated — so focus must be derived from the records.
///   - `layout.pos_in_scrolling_layout` is [column, tile] (1-based) for
///     tiled windows, null for floating ones.
Singleton {
    id: root

    /// Whether niri's built-in overview (Super+A) is currently open.
    property bool overviewOpen: false

    // ── Raw niri records (plain JS; nothing binds to these) ─────────

    property var _ws: ({})    // id → niri Workspace
    property var _win: ({})   // id → niri Window

    // ── Actions ─────────────────────────────────────────────────────
    //
    // Detached per call: a shared Process silently drops a command
    // issued while the previous one is still running (fast clicks).

    function focusWorkspace(name: string) {
        root._niriAction(["focus-workspace", name]);
    }

    /// Focus an (unnamed) workspace by its index on a given output.
    function focusWorkspaceOn(output: string, idx: int) {
        Quickshell.execDetached(["sh", "-c",
            'niri msg action focus-monitor "$1" && niri msg action focus-workspace "$2"',
            "garden-niri", output, String(idx)]);
    }

    function focusWindow(id: int) {
        root._niriAction(["focus-window", "--id", String(id)]);
    }

    function runAction(action: string) {
        root._niriAction([action]);
    }

    function _niriAction(args) {
        Quickshell.execDetached(["niri", "msg", "action"].concat(args));
    }

    // ── Event stream ────────────────────────────────────────────────

    Process {
        id: eventStream
        command: ["niri", "msg", "-j", "event-stream"]
        running: true

        stdout: SplitParser {
            onRead: message => root._handleEvent(message)
        }

        // The stream ends if niri restarts or the socket drops; respawn
        // so the bar doesn't silently freeze. The fresh stream opens
        // with a full WorkspacesChanged/WindowsChanged dump.
        onExited: respawn.restart()
    }

    Timer {
        id: respawn
        interval: 1000
        onTriggered: eventStream.running = true
    }

    // Coalesce event bursts into one derivation pass.
    Timer {
        id: syncTimer
        interval: 16
        onTriggered: root._sync()
    }

    function _handleEvent(line: string) {
        let event;
        try {
            event = JSON.parse(line);
        } catch (e) {
            return;
        }

        // Each event is an object with a single key naming its type.
        const type = Object.keys(event)[0];
        if (!type) return;
        const data = event[type];

        switch (type) {
        case "WorkspacesChanged":
            root._ws = root._byId(data.workspaces);
            break;
        case "WorkspaceActivated": {
            const target = root._ws[data.id];
            if (!target) return;
            for (const id in root._ws) {
                const w = root._ws[id];
                if (w.output === target.output) w.is_active = w.id === data.id;
                if (data.focused) w.is_focused = w.id === data.id;
            }
            break;
        }
        case "WorkspaceActiveWindowChanged": {
            const w = root._ws[data.workspace_id];
            if (w) w.active_window_id = data.active_window_id;
            break;
        }
        case "WorkspaceUrgencyChanged": {
            const w = root._ws[data.id];
            if (w) w.is_urgent = data.urgent;
            break;
        }
        case "WindowsChanged":
            root._win = root._byId(data.windows);
            break;
        case "WindowOpenedOrChanged": {
            const w = data.window;
            if (!w) return;
            if (w.is_focused)
                for (const id in root._win) root._win[id].is_focused = false;
            root._win[w.id] = w;
            break;
        }
        case "WindowClosed":
            delete root._win[data.id];
            break;
        case "WindowFocusChanged":
            for (const id in root._win)
                root._win[id].is_focused = root._win[id].id === data.id;
            break;
        case "WindowUrgencyChanged": {
            const w = root._win[data.id];
            if (w) w.is_urgent = data.urgent;
            break;
        }
        case "WindowLayoutsChanged":
            for (const [id, layout] of data.changes ?? []) {
                if (root._win[id]) root._win[id].layout = layout;
            }
            break;
        case "OverviewOpenedOrClosed":
            root.overviewOpen = !!data.is_open;
            return;
        default:
            return;
        }

        syncTimer.restart();
    }

    function _byId(list) {
        const map = {};
        for (const item of list ?? []) map[item.id] = item;
        return map;
    }

    // ── Derivation → CompositorService ──────────────────────────────

    function _sync() {
        const winsByWs = {};
        for (const id in root._win) {
            const w = root._win[id];
            if (w.workspace_id === null || w.workspace_id === undefined) continue;
            if (!winsByWs[w.workspace_id]) winsByWs[w.workspace_id] = [];
            winsByWs[w.workspace_id].push(w);
        }

        const list = [];
        for (const id in root._ws) {
            const ws = root._ws[id];
            list.push(root._workspaceEntry(ws, winsByWs[ws.id] ?? []));
        }
        list.sort((a, b) => a.output.localeCompare(b.output) || a.idx - b.idx);

        const outputs = {};
        let focused = null;
        for (const ws of list) {
            if (!outputs[ws.output]) outputs[ws.output] = {
                name: ws.output, focused: false, active: null, workspaces: []
            };
            const out = outputs[ws.output];
            out.workspaces.push(ws);
            if (ws.active) out.active = ws;
            if (ws.focused) { out.focused = true; focused = ws; }
        }

        CompositorService.workspaces = list;
        CompositorService.outputs = outputs;
        CompositorService.focusedOutput = focused ? focused.output : "";

        const name = focused ? focused.label : "";
        if (CompositorService.activeWorkspace !== name) {
            CompositorService.activeWorkspace = name;
            CompositorService.workspaceChanged(name);
        }
    }

    function _workspaceEntry(ws, wins) {
        const columns = {};
        const floating = [];

        for (const w of wins) {
            const pos = w.layout?.pos_in_scrolling_layout;
            if (w.is_floating || !pos) {
                floating.push({
                    id: w.id,
                    appId: w.app_id ?? "",
                    title: w.title ?? "",
                    focused: !!w.is_focused
                });
                continue;
            }
            if (!columns[pos[0]]) columns[pos[0]] = [];
            columns[pos[0]].push(w);
        }

        const cols = [];
        for (const index in columns) {
            const tiles = columns[index];
            // Label the column by its visible tile: the focused one, else
            // the workspace's active window, else the most recently focused.
            const rep = tiles.find(t => t.is_focused)
                ?? tiles.find(t => t.id === ws.active_window_id)
                ?? tiles.reduce((a, b) =>
                    root._focusTime(b) > root._focusTime(a) ? b : a);
            let x = null;
            let width = 0;
            for (const t of tiles) {
                const p = t.layout?.tile_pos_in_workspace_view;
                if (p) x = x === null ? p[0] : Math.min(x, p[0]);
                width = Math.max(width, t.layout?.tile_size?.[0] ?? 0);
            }
            cols.push({
                index: parseInt(index, 10),
                id: rep.id,
                appId: rep.app_id ?? "",
                title: rep.title ?? "",
                tiles: tiles.length,
                focused: tiles.some(t => t.is_focused),
                active: tiles.some(t => t.id === ws.active_window_id),
                x: x,
                w: width
            });
        }
        cols.sort((a, b) => a.index - b.index);

        return {
            id: ws.id,
            idx: ws.idx ?? 0,
            name: ws.name ?? "",
            label: ws.name || String(ws.idx ?? ""),
            output: ws.output ?? "",
            active: !!ws.is_active,
            focused: !!ws.is_focused,
            urgent: !!ws.is_urgent
                || wins.some(w => w.is_urgent),
            windowCount: wins.length,
            columns: cols,
            floating: floating
        };
    }

    function _focusTime(w) {
        const t = w.focus_timestamp;
        return t ? t.secs * 1e9 + t.nanos : 0;
    }
}

import QtQuick
import ".."
import "../compositor"
import "../services"

/// The channel visible on the bar's output: its name, then its pages
/// (niri columns) in strip order, then any floating windows.
///
///   active page  — base-hl chip; 1 px accent underline when it holds
///                  keyboard focus
///   on-screen    — text-2
///   off-screen   — text-4 (scrolled out of the strip's view)
///   stacked      — `label ×n` for columns holding several tiles
///
/// Full mode adds the active page's title. The name turns accent while
/// a focus session runs (spec §10), and dims on an unfocused output.
Row {
    id: root

    /// Workspace entry visible on this output (null before first sync).
    required property var workspace

    /// Whether the bar's output holds keyboard focus.
    property bool outputFocused: false

    /// Full-bar mode: show the active page's title.
    property bool showTitle: false

    /// Output width — pages outside [0, viewWidth) are off-screen.
    property real viewWidth: 0

    /// The owning bar's BarTooltip.
    property var tip: null

    readonly property var _columns: root.workspace?.columns ?? []
    readonly property var _floating: root.workspace?.floating ?? []

    // Positions are only reported for some windows; if none on this
    // workspace has one, treat every page as on-screen rather than
    // dimming them all.
    readonly property bool _hasPositions: root._columns.some(c => c.x !== null)

    readonly property var _activeColumn: root._columns.find(c => c.active) ?? null
    readonly property var _focusedFloating: root._floating.find(f => f.focused) ?? null

    function _onScreen(c): bool {
        if (!root._hasPositions) return true;
        return c.x !== null && c.x < root.viewWidth && c.x + c.w > 0;
    }

    function _pageColor(c): color {
        if (c.active) return root.outputFocused ? Theme.text1 : Theme.text2;
        return root._onScreen(c) ? Theme.text2 : Theme.text4;
    }

    // ── Channel name ────────────────────────────────────────────────

    BarSlot {
        text: root.workspace?.label || "\u2014"
        fontFamily: Theme.sansFont
        fontSize: Theme.fontTitle
        bold: true
        color: !root.outputFocused ? Theme.text3
            : NotificationService.focusActive ? Theme.accent : Theme.text1
        tip: root.tip
        tooltip: NotificationService.focusActive && root.outputFocused
            ? "focus session" : ""
    }

    // ── Pages ───────────────────────────────────────────────────────

    Repeater {
        model: root._columns

        delegate: BarSlot {
            required property var modelData

            text: ConfigService.appLabel(modelData.appId, modelData.title)
                + (modelData.tiles > 1 ? " \u00d7" + modelData.tiles : "")
            fontFamily: Theme.sansFont
            fontSize: Theme.fontBody
            maxTextWidth: 120
            color: root._pageColor(modelData)
            selected: modelData.active
            marked: modelData.focused && root.outputFocused
            interactive: true
            tip: root.tip
            tooltip: modelData.title
            onClicked: CompositorService.focusWindow(modelData.id)
        }
    }

    // ── Floating windows ────────────────────────────────────────────

    BarSlot {
        visible: root._floating.length > 0
        text: "+" + root._floating.length
        color: root._focusedFloating && root.outputFocused ? Theme.text1 : Theme.text3
        selected: root._focusedFloating !== null
        marked: root._focusedFloating !== null && root.outputFocused
        interactive: true
        tip: root.tip
        tooltip: "floating \u2022 " + root._floating
            .map(f => ConfigService.appLabel(f.appId, f.title)).join(", ")

        // Cycle through floating windows, starting after the focused one.
        onClicked: {
            const list = root._floating;
            const i = list.findIndex(f => f.focused);
            CompositorService.focusWindow(list[(i + 1) % list.length].id);
        }
    }

    // ── Title (full mode) ───────────────────────────────────────────

    BarSlot {
        readonly property var _source: root._focusedFloating ?? root._activeColumn
        visible: root.showTitle && text.length > 0
        text: _source?.title ?? ""
        fontFamily: Theme.sansFont
        fontSize: Theme.fontBody
        maxTextWidth: 280
        color: Theme.text3
    }
}

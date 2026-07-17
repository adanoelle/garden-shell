import QtQuick
import Quickshell
import Quickshell.Wayland

/// Base component for full-screen modal overlays (Launcher, ChannelSwitcher, Settings…).
///
/// Each overlay extends this component and binds its content Column and Translate:
///
///   OverlayBase {
///       contentTarget: content
///       slideTarget:   contentSlide
///       animDuration:  150        // optional, default 200
///       _namespace:    "garden-foo"
///
///       Column {
///           id: content
///           opacity: 0
///           transform: Translate { id: contentSlide; y: 20 }
///           // ... overlay content ...
///       }
///   }
///
/// Hooks for per-overlay logic:
///   _onBeforeShow()  — reset state before the window becomes visible
///   _onBeforeClose() — cleanup before the hide animation starts
///
/// All overlays share: dithered backdrop, click-outside-to-close, WlrLayer.Overlay,
/// and the standard fade+slide animation pair.
PanelWindow {
    id: root

    // ── Required bindings (set by each overlay) ─────────────────────

    /// The content Column whose opacity is animated.
    required property Item contentTarget

    /// The Translate on the content Column whose y is animated.
    required property Translate slideTarget

    // ── Configurable ─────────────────────────────────────────────────

    /// Animation duration in ms. 150 for Launcher, 200 for others.
    property int animDuration: 200

    /// WlrLayershell namespace. Override per overlay.
    property string _namespace: "garden-overlay"

    // ── State ─────────────────────────────────────────────────────────

    property bool _open: false

    // ── Overridable hooks ─────────────────────────────────────────────

    /// Called before the window becomes visible. Reset state, seed data, focus.
    function _onBeforeShow()  {}

    /// Called before the hide animation starts. Discard edits, cleanup.
    function _onBeforeClose() {}

    // ── Standard API ─────────────────────────────────────────────────

    function _toggle() {
        if (_open) _close();
        else _show();
    }

    function _show() {
        _open = true;
        contentTarget.opacity = 0;
        slideTarget.y = 20;
        _onBeforeShow();
        visible = true;
        _showAnim.start();
    }

    function _close() {
        if (!_open) return;
        _onBeforeClose();
        _hideAnim.start();
    }

    /// Close immediately without animation (e.g. before a palette switch).
    function _closeInstant() {
        if (!_open) return;
        _hideAnim.stop();
        contentTarget.opacity = 0;
        slideTarget.y = 20;
        _open = false;
        visible = false;
    }

    // ── Window setup ─────────────────────────────────────────────────

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    visible: false
    color: "transparent"
    focusable: true
    exclusiveZone: 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: root._namespace

    // ── Animations ───────────────────────────────────────────────────

    ParallelAnimation {
        id: _showAnim

        NumberAnimation {
            target: root.contentTarget; property: "opacity"
            to: 1; duration: root.animDuration; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: root.slideTarget; property: "y"
            to: 0; duration: root.animDuration; easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: _hideAnim

        NumberAnimation {
            target: root.contentTarget; property: "opacity"
            to: 0; duration: root.animDuration; easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: root.slideTarget; property: "y"
            to: 20; duration: root.animDuration; easing.type: Easing.InCubic
        }

        onFinished: {
            root._open = false;
            root.visible = false;
        }
    }

    // ── Backdrop ─────────────────────────────────────────────────────

    DitherOverlay { density: "dense" }

    // Click outside content to close.
    MouseArea {
        anchors.fill: parent
        onClicked: root._close()
    }
}

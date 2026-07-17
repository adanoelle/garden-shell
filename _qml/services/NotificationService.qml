pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import "."

/// Notification daemon state and suppression policy.
///
/// Owns the org.freedesktop.Notifications D-Bus name via
/// NotificationServer. Incoming notifications either become popups or
/// queue silently, per the three-layer suppression model:
///
///   1. Global toggle — IPC `suppressNotifications` / Super+Shift+N.
///   2. Per-channel — `"suppress-notifications"` in the active
///      channel's mode stack (ModeService.hasMode).
///   3. Focus sessions — IPC `focusStart` / `focusEnd` (`focusActive`).
///
/// urgency=critical BYPASSES all three layers and always pops up
/// immediately (GNOME/KDE DND convention; a battery warning must not
/// die silently during a focus session).
///
/// While suppressed, notifications queue and `queuedCount` drives the
/// bar dot. When suppression lifts, the queue is released: one held
/// notification returns as its real popup, more collapse into a single
/// summary card pointing at the notification center.
///
/// Expiry policy lives in `timeoutFor()`: 10 s default, notification
/// -specified timeouts respected, urgency=critical never auto-expires
/// (returns 0 = no auto-expiry). The popup card owns the actual timer
/// and progress line; removal always flows through the notification's
/// `closed` signal so there is a single cleanup path.
Singleton {
    id: root

    // ── Suppression ─────────────────────────────────────────────────

    /// Global toggle (IPC / keybind). Persisted only for the session.
    property bool globallySuppressed: false

    /// Focus session in progress (IPC focusStart/focusEnd) — the third
    /// suppression layer, global like the toggle (not per-channel).
    property bool focusActive: false

    /// Effective suppression for the active channel.
    readonly property bool suppressed: root.globallySuppressed
        || root.focusActive
        || ModeService.hasMode("suppress-notifications")

    // ── Tracked state ───────────────────────────────────────────────

    /// Notifications currently shown as popup cards.
    property var popups: []

    /// Notifications held silently while suppressed.
    property var queued: []

    /// Queue size — drives the bar dot indicator.
    readonly property int queuedCount: root.queued.length

    // ── History ─────────────────────────────────────────────────────

    /// Session-only history of real notifications, newest first.
    /// Plain JS snapshots ({time, appName, summary, body, urgency})
    /// captured at arrival — Notification QObjects die after close.
    /// Synthetic cards do not enter history.
    property var history: []

    readonly property int historyCap: 50

    function clearHistory() {
        root.history = [];
    }

    function _snapshot(n) {
        root.history = [{
            time: Qt.formatTime(new Date(), "hh:mm"),
            appName: n.appName,
            summary: n.summary,
            body: n.body,
            urgency: n.urgency
        }].concat(root.history).slice(0, root.historyCap);
    }

    // ── Expiry policy ───────────────────────────────────────────────

    readonly property int defaultTimeoutMs: 10000

    /// Auto-expiry window in ms for a notification; 0 = never.
    /// Untyped parameter: accepts real Notification objects AND plain
    /// JS synthetic shims (a typed param would coerce shims to null).
    function timeoutFor(n): int {
        if (n.urgency === NotificationUrgency.Critical) return 0;
        if (n.expireTimeout === 0) return 0;          // spec: 0 = never
        if (n.expireTimeout > 0) return n.expireTimeout;
        return root.defaultTimeoutMs;                 // -1 = server default
    }

    // ── Control ─────────────────────────────────────────────────────

    function setSuppressed(on: bool) {
        root.globallySuppressed = on;
    }

    function toggleSuppressed() {
        root.globallySuppressed = !root.globallySuppressed;
    }

    /// Idempotent focus-session switch. Ending a session releases the
    /// queue (via onSuppressedChanged, synchronously) and then shows a
    /// "take a break" synthetic. The break card deliberately bypasses
    /// the queue — it is a local, intentional signal (§6), shown even
    /// if the active channel's mode still suppresses notifications.
    function setFocus(on: bool) {
        if (root.focusActive === on) return;
        root.focusActive = on;

        if (!on) {
            root.popups = root.popups.concat([root._makeSynthetic(
                "focus session complete",
                "take a break",
                []
            )]);
        }
    }

    // Release the queue when suppression lifts (global toggle off,
    // focus session end, or switch to a channel without
    // suppress-notifications).
    //
    // Clearing `queued` FIRST makes the closed-signal `_remove`s no-ops
    // and rapid re-toggles idempotent. One held notification is shown
    // as its real popup (keeping its actions); more than one collapses
    // into a single summary synthetic pointing at the history center —
    // no popup bomb.
    onSuppressedChanged: {
        if (root.suppressed || root.queued.length === 0) return;

        const held = root.queued;
        root.queued = [];

        if (held.length === 1) {
            root.popups = root.popups.concat(held);
        } else {
            held.forEach(n => n.dismiss());   // proper D-Bus close
            root.popups = root.popups.concat([root._makeSummary(held.length)]);
        }
    }

    function _remove(n) {
        root.popups = root.popups.filter(p => p !== n);
        root.queued = root.queued.filter(p => p !== n);
    }

    // ── Synthetics ──────────────────────────────────────────────────

    /// Local, shell-generated pseudo-notification. Matches the API
    /// surface NotificationCard touches (appName/summary/body/urgency/
    /// actions/expireTimeout + expire()/dismiss()). Bypasses the D-Bus
    /// server and history; cleanup is solely via the closures below.
    function _makeSynthetic(summary, body, actions) {
        const n = {
            synthetic: true,
            appName: "garden",
            summary: summary,
            body: body,
            urgency: NotificationUrgency.Normal,
            actions: actions || [],
            expireTimeout: -1
        };
        n.expire = () => root._remove(n);
        n.dismiss = () => root._remove(n);
        return n;
    }

    function _makeSummary(count) {
        return root._makeSynthetic(
            count + " notifications while suppressed",
            "review them in the notification center",
            [{
                text: "open",
                invoke: () => HookService.notificationCenterToggled()
            }]
        );
    }

    // ── Server ──────────────────────────────────────────────────────

    NotificationServer {
        id: server

        // Clean slate on hot-reload; popup/queue arrays reset anyway.
        keepOnReload: false

        actionsSupported: true
        bodySupported: true
        imageSupported: true

        onNotification: (n) => {
            n.tracked = true;
            n.closed.connect(() => root._remove(n));

            // Single capture point — covers shown AND queued.
            root._snapshot(n);

            // Critical bypasses suppression entirely (see header).
            const critical = n.urgency === NotificationUrgency.Critical;

            if (root.suppressed && !critical)
                root.queued = root.queued.concat([n]);
            else
                root.popups = root.popups.concat([n]);
        }
    }
}

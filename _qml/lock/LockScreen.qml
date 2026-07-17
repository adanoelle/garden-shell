import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam
import "../services"

/// Session lock controller (third window kind — not OverlayBase, not the
/// non-modal PanelWindow pattern).
///
/// `WlSessionLock` speaks ext-session-lock-v1 to niri; its child acts as
/// a template instantiated once per screen as a `WlSessionLockSurface`
/// (LockSurface.qml). Auth state lives here, shared across surfaces, so
/// multi-monitor setups stay in sync.
///
/// Locking: `qs -c garden ipc call garden lock` → HookService.lockRequested.
/// Unlocking: PAM success only (config "swaylock" — auth-only pam_unix
/// stack, verified via _qml/dev/pamtest.qml before this was wired).
///
/// ⚠ Under ext-session-lock, if the lock client dies the compositor keeps
/// the screen locked. Do not iterate on lock QML via hot-reload while
/// locked; keep a spare TTY logged in when testing.
Scope {
    id: root

    // ── Shared auth state (all surfaces bind to this) ───────────────

    property string password: ""
    property bool authenticating: false

    /// Emitted on PAM failure — surfaces run the shake/urgent feedback.
    signal authFailed()

    // ── API ─────────────────────────────────────────────────────────

    function lock() {
        if (sessionLock.locked) return;
        root.password = "";
        root.authenticating = false;
        sessionLock.locked = true;
    }

    function submit() {
        if (root.authenticating || root.password.length === 0) return;
        root.authenticating = true;
        pam.start();
    }

    Connections {
        target: HookService
        function onLockRequested() { root.lock(); }
    }

    // ── Auth ────────────────────────────────────────────────────────

    PamContext {
        id: pam

        // Auth-only stack (pam_unix), same service swaylock uses.
        config: "swaylock"

        onPamMessage: {
            if (pam.responseRequired) pam.respond(root.password);
        }

        onCompleted: result => {
            root.authenticating = false;
            root.password = "";
            if (result === PamResult.Success) {
                sessionLock.locked = false;
            } else {
                root.authFailed();
            }
        }

        onError: error => {
            console.warn("lock: pam error", error);
            root.authenticating = false;
            root.password = "";
            root.authFailed();
        }
    }

    // ── Lock ────────────────────────────────────────────────────────

    WlSessionLock {
        id: sessionLock

        LockSurface {
            context: root
        }
    }
}

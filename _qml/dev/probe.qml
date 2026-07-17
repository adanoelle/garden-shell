import QtQuick
import Quickshell

/// One-shot platform probe (Phase 0, plan/core-services-plan.md).
///
/// Checks that each Quickshell service module the core-services track
/// depends on is present in the installed Quickshell build. Run via
/// `just qs-probe` — prints one line per module, then exits.
///
/// Not part of the shell — never imported by shell.qml. Quickshell only
/// loads this file when invoked directly with `qs -p`.
ShellRoot {
    id: root

    // Each check imports the module and instantiates a harmless type.
    // NotificationServer is deliberately NOT instantiated — creating one
    // grabs the org.freedesktop.Notifications D-Bus name from whatever
    // daemon currently owns it.
    readonly property var checks: [
        { mod: "Quickshell.Services.Pipewire",      body: "PwObjectTracker {}" },
        { mod: "Quickshell.Services.Notifications", body: "QtObject {}" },
        { mod: "Quickshell.Services.SystemTray",    body: "QtObject { property var t: SystemTray }" },
        { mod: "Quickshell.Services.UPower",        body: "QtObject { property var t: UPower }" },
        { mod: "Quickshell.Services.Mpris",         body: "QtObject { property var t: Mpris }" },
        { mod: "Quickshell.Services.Pam",           body: "PamContext {}" },
        { mod: "Quickshell.Wayland",                body: "WlSessionLock {}" }
    ]

    Component.onCompleted: {
        console.info("garden probe — service module availability");
        let missing = 0;

        for (const check of root.checks) {
            const src = "import QtQuick\nimport " + check.mod + "\n" + check.body;
            try {
                const obj = Qt.createQmlObject(src, root, "probe:" + check.mod);
                obj.destroy();
                console.info("  ok       " + check.mod);
            } catch (e) {
                missing++;
                console.warn("  MISSING  " + check.mod + " — " + e.message);
            }
        }

        console.info(missing === 0
            ? "probe done — all modules available"
            : "probe done — " + missing + " module(s) missing; see plan/core-services-plan.md step 0");
        Qt.quit();
    }
}

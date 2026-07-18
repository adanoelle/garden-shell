pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import Quickshell.Services.Notifications
import "."

/// Reactive battery state via UPower's aggregate DisplayDevice.
///
/// `available` is false on machines with no battery — UPower still
/// exposes a placeholder DisplayDevice (`power supply: no`,
/// isLaptopBattery false) on desktops, so the bar slot keys off this
/// and hides entirely.
///
/// Fires one critical "battery low" notification per discharge cycle
/// at ≤10%; the warning rearms when a charger is connected. Critical
/// urgency bypasses suppression and never auto-expires (see
/// NotificationService header).
Singleton {
    id: root

    readonly property var _device: UPower.displayDevice

    /// True when a real battery is present.
    readonly property bool available: root._device !== null
        && root._device.ready
        && root._device.isLaptopBattery

    /// Charge fraction, 0.0–1.0.
    readonly property real percentage: root.available ? root._device.percentage : 0

    /// On AC power (charging or fully charged).
    readonly property bool charging: root.available && !UPower.onBattery

    /// Urgent-display threshold for the bar (≤15%, discharging).
    readonly property bool low: root.available && !root.charging
        && root.percentage <= 0.15

    // ── Low-battery warning (once per discharge cycle) ──────────────

    property bool _warned: false

    readonly property bool _shouldWarn: root.available && !root.charging
        && root.percentage <= 0.10

    on_ShouldWarnChanged: {
        if (!root._shouldWarn || root._warned) return;
        root._warned = true;
        NotificationService.sendSynthetic(
            "battery low",
            Math.round(root.percentage * 100) + "% remaining — plug in soon",
            NotificationUrgency.Critical);
    }

    onChargingChanged: if (root.charging) root._warned = false
}

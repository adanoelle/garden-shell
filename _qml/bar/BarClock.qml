import QtQuick
import Quickshell
import ".."

/// Time display in the bar.
///
/// Full mode: date + time. Otherwise time only. SystemClock re-reads
/// wall time on its own, so the display is right after suspend/resume
/// and NTP steps (a minute-aligned Timer drifts across suspend).
Row {
    id: root

    /// Full-bar mode: show the date.
    property bool showDate: false

    /// The owning bar's BarTooltip.
    property var tip: null

    readonly property var _days: ["sunday", "monday", "tuesday", "wednesday",
                                  "thursday", "friday", "saturday"]
    readonly property var _months: ["january", "february", "march", "april",
                                    "may", "june", "july", "august",
                                    "september", "october", "november", "december"]

    SystemClock {
        id: clock
        precision: SystemClock.Minutes
    }

    BarSlot {
        visible: root.showDate
        text: root._months[clock.date.getMonth()].slice(0, 3) + " " + clock.date.getDate()
        color: Theme.text3
    }

    BarSlot {
        text: String(clock.hours).padStart(2, "0") + ":"
            + String(clock.minutes).padStart(2, "0")
        fontSize: Theme.fontTitle
        color: Theme.text1
        tip: root.tip
        tooltip: root._days[clock.date.getDay()] + " \u2022 "
            + root._months[clock.date.getMonth()] + " " + clock.date.getDate()
    }
}

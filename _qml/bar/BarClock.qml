import QtQuick
import ".."
import "../services"

/// Time display in the bar.
///
/// Full mode: time + date. Standard mode: time only. Minimal mode:
/// hidden (parent handles visibility).
Item {
    id: root

    implicitWidth: clockRow.implicitWidth
    implicitHeight: parent ? parent.height : ModeService.standardHeight

    // Update once per minute, synced to the minute boundary.
    Timer {
        id: clockTimer
        running: true
        repeat: false
        triggeredOnStart: true
        onTriggered: {
            root._updateTime();
            // Reschedule at the next minute boundary.
            clockTimer.interval = 60000 - (Date.now() % 60000);
            clockTimer.restart();
        }
    }

    property string _timeStr: ""
    property string _dateStr: ""

    function _updateTime() {
        const now = new Date();
        const h = String(now.getHours()).padStart(2, "0");
        const m = String(now.getMinutes()).padStart(2, "0");
        root._timeStr = h + ":" + m;

        const months = ["Jan","Feb","Mar","Apr","May","Jun",
                        "Jul","Aug","Sep","Oct","Nov","Dec"];
        const day = now.getDate();
        const mon = months[now.getMonth()];
        root._dateStr = mon + " " + day;
    }

    Row {
        id: clockRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8

        // Date (full mode only).
        Text {
            text: root._dateStr
            color: Theme.text3
            font.family: Theme.monoFont
            font.pixelSize: 11
            visible: ModeService.showExtended
        }

        // Time (always visible when bar has content).
        Text {
            text: root._timeStr
            color: Theme.text1
            font.family: Theme.monoFont
            font.pixelSize: 13
        }
    }
}

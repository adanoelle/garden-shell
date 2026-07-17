import QtQuick
import ".."
import "../services"

/// Single ambient state slot for the bar.
///
/// Displays `prefix + value` at text-4 opacity (nearly invisible).
/// When _trigger() is called, brightens to activeColor for 1.5s then
/// fades back. Uses an intermediate _displayColor property so the two
/// ColorAnimations don't conflict with QML's binding system.
Item {
    id: root

    property string prefix: ""
    property string value:  ""
    property color  activeColor: Theme.text1

    // Intermediate color property targeted by both animations.
    // Text binds here; animations write here directly.
    property color _displayColor: Theme.text4

    implicitWidth:  _label.implicitWidth
    implicitHeight: _label.implicitHeight

    /// Call when the underlying value changes to trigger the brighten/dim cycle.
    function _trigger() {
        _holdTimer.restart()
        _toDim.stop()
        _toActive.start()
    }

    Text {
        id: _label
        text: root.prefix + root.value
        font.family: Theme.monoFont
        font.pixelSize: 11
        color: root._displayColor
    }

    // Brighten: text-4 → activeColor (fast, 150ms)
    ColorAnimation {
        id: _toActive
        target: root
        property: "_displayColor"
        to: root.activeColor
        duration: 150
        easing.type: Easing.OutCubic
    }

    // Dim: activeColor → text-4 (slightly slower, 200ms)
    ColorAnimation {
        id: _toDim
        target: root
        property: "_displayColor"
        to: Theme.text4
        duration: 200
        easing.type: Easing.InCubic
    }

    // Hold at activeColor for 1.5s before dimming.
    Timer {
        id: _holdTimer
        interval: 1500
        onTriggered: _toDim.start()
    }
}

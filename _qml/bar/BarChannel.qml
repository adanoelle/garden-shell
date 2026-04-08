import QtQuick
import QtQuick.Layouts
import ".."
import "../compositor"
import "../services"

/// Active channel display with column indicators.
///
/// Shows the active workspace name in bold text, followed by indicators
/// for each column (window) on that workspace. Focused columns are
/// highlighted; visible but unfocused columns are dimmer; off-screen
/// columns are faintest.
Item {
    id: root

    implicitWidth: channelRow.implicitWidth
    implicitHeight: parent ? parent.height : ModeService.standardHeight

    RowLayout {
        id: channelRow
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6

        // Channel name.
        Text {
            text: CompositorService.activeWorkspace || "—"
            color: Theme.text1
            font.family: Theme.sansFont
            font.pixelSize: 13
            font.bold: true
        }

        // Separator when columns exist.
        Text {
            text: "·"
            color: Theme.text4
            font.family: Theme.monoFont
            font.pixelSize: 11
            visible: CompositorService.columns.length > 0
        }

        // Column indicators.
        Repeater {
            model: CompositorService.columns

            delegate: Rectangle {
                required property var modelData

                width: columnLabel.implicitWidth + 10
                height: 20
                radius: 3

                color: modelData.focused ? Theme.baseHl : "transparent"

                Text {
                    id: columnLabel
                    anchors.centerIn: parent
                    text: {
                        const appId = modelData.appId || "";
                        const title = modelData.title || "";
                        return appId || title.split(" ")[0] || "·";
                    }
                    maximumLineCount: 1
                    elide: Text.ElideRight
                    width: Math.min(implicitWidth, 90)
                    color: {
                        if (modelData.focused) return Theme.text1;
                        if (modelData.visible) return Theme.text2;
                        return Theme.text4;
                    }
                    font.family: Theme.monoFont
                    font.pixelSize: 11
                }
            }
        }
    }
}

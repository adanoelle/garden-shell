import QtQuick
import ".."

/// Dropdown palette selector with popup list and delete buttons.
///
/// The dropdown Rectangle is reparented to `popupParent` so it can
/// escape the Flickable's clip bounds.
Item {
    id: root
    width: parent ? parent.width : 400
    height: 36

    /// Full palette data object (from palettes.json).
    property var palettesData: ({})

    /// Currently selected palette name.
    property string selectedPalette: ""

    /// Item to reparent the dropdown into (escapes Flickable clip).
    property Item popupParent: null

    /// Whether the dropdown is currently open.
    readonly property bool dropdownOpen: dropdown.visible

    /// Emitted when a palette is clicked.
    signal paletteSelected(string name)

    /// Emitted when a palette's delete button is clicked.
    signal paletteDeleteRequested(string name)

    /// Close the dropdown.
    function close() {
        dropdown.visible = false;
    }

    // ── Trigger button ────────────────────────────────────────────────

    Rectangle {
        id: trigger
        anchors.left: parent.left
        width: triggerRow.width + 28
        height: 36
        color: dropdown.visible ? Theme.baseHl : "transparent"
        border.color: Theme.borderSub
        border.width: 1

        Row {
            id: triggerRow
            anchors.centerIn: parent
            spacing: 6

            Text {
                text: root.palettesData.palettes?.[root.selectedPalette]?.icon || "\u25cf"
                color: Theme.text1
                font.family: Theme.monoFont
                font.pixelSize: 12
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: root.selectedPalette || "---"
                color: Theme.text1
                font.family: Theme.monoFont
                font.pixelSize: 12
                font.weight: Font.DemiBold
                anchors.verticalCenter: parent.verticalCenter
            }

            Text {
                text: dropdown.visible ? "\u25b4" : "\u25be"
                color: Theme.text3
                font.family: Theme.monoFont
                font.pixelSize: 10
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                if (dropdown.visible) {
                    dropdown.visible = false;
                } else {
                    root._positionDropdown();
                    dropdown.visible = true;
                }
            }
        }
    }

    // ── Dropdown (reparented to popupParent) ──────────────────────────

    Rectangle {
        id: dropdown
        visible: false
        parent: root.popupParent || root
        x: root._dropdownX
        y: root._dropdownY
        width: 280
        height: Math.min(dropdownList.contentHeight + 2, 8 * 36 + 2)
        color: Theme.baseDeep
        border.color: Theme.border
        border.width: 1
        z: 200

        Flickable {
            id: dropdownList
            anchors.fill: parent
            anchors.margins: 1
            contentHeight: dropdownColumn.height
            clip: true
            flickableDirection: Flickable.VerticalFlick
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: dropdownColumn
                width: parent.width

                Repeater {
                    model: root._paletteList

                    Item {
                        id: rowDelegate
                        required property var modelData
                        width: dropdownColumn.width
                        height: 36

                        Rectangle {
                            anchors.fill: parent
                            color: rowDelegate.modelData.name === root.selectedPalette
                                ? Theme.baseHl
                                : rowHover.containsMouse ? Theme.baseRaised : "transparent"
                        }

                        // Selection area (stops before delete button).
                        MouseArea {
                            id: rowHover
                            anchors.top: parent.top
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: deleteBtn.visible ? deleteBtn.left : parent.right
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.paletteSelected(rowDelegate.modelData.name);
                                dropdown.visible = false;
                            }
                        }

                        Row {
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 8

                            // Checkmark for selected palette.
                            Text {
                                text: rowDelegate.modelData.name === root.selectedPalette ? "\u2713" : " "
                                color: Theme.accent
                                font.family: Theme.monoFont
                                font.pixelSize: 12
                                width: 14
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: rowDelegate.modelData.icon || "\u25cf"
                                color: rowDelegate.modelData.name === root.selectedPalette
                                    ? Theme.text1 : Theme.text3
                                font.family: Theme.monoFont
                                font.pixelSize: 12
                                anchors.verticalCenter: parent.verticalCenter
                            }

                            Text {
                                text: rowDelegate.modelData.name
                                color: rowDelegate.modelData.name === root.selectedPalette
                                    ? Theme.text1 : Theme.text2
                                font.family: Theme.monoFont
                                font.pixelSize: 12
                                font.weight: rowDelegate.modelData.name === root.selectedPalette
                                    ? Font.DemiBold : Font.Normal
                                anchors.verticalCenter: parent.verticalCenter
                            }
                        }

                        // Delete button (non-builtin only).
                        Rectangle {
                            id: deleteBtn
                            anchors.right: parent.right
                            anchors.rightMargin: 4
                            anchors.verticalCenter: parent.verticalCenter
                            width: 28
                            height: 28
                            visible: rowDelegate.modelData.builtin === false
                            color: deleteBtnHover.containsMouse ? Theme.urgent : "transparent"
                            radius: 2

                            Text {
                                anchors.centerIn: parent
                                text: "\u00d7"
                                color: deleteBtnHover.containsMouse ? Theme.baseDeep : Theme.text4
                                font.family: Theme.monoFont
                                font.pixelSize: 16
                            }

                            MouseArea {
                                id: deleteBtnHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.paletteDeleteRequested(rowDelegate.modelData.name);
                                }
                            }
                        }

                        // Bottom separator.
                        Rectangle {
                            anchors.bottom: parent.bottom
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.leftMargin: 10
                            anchors.rightMargin: 10
                            height: 1
                            color: Theme.borderSub
                            visible: rowDelegate.modelData.index < root._paletteList.length - 1
                        }
                    }
                }
            }
        }
    }

    // ── Position dropdown relative to popupParent ─────────────────────

    property real _dropdownX: 0
    property real _dropdownY: 0

    function _positionDropdown() {
        if (!root.popupParent) return;
        const mapped = root.mapToItem(root.popupParent, 0, root.height);
        root._dropdownX = mapped.x;
        root._dropdownY = mapped.y + 4;
    }

    // ── Build sorted palette list ─────────────────────────────────────

    readonly property var _paletteList: {
        const list = [];
        const palettes = root.palettesData.palettes;
        if (!palettes) return list;
        const builtin = [];
        const custom = [];
        for (const name in palettes) {
            const entry = {
                name: name,
                icon: palettes[name].icon || "\u25cf",
                builtin: palettes[name].builtin
            };
            if (palettes[name].builtin === false) {
                custom.push(entry);
            } else {
                builtin.push(entry);
            }
        }
        builtin.sort((a, b) => a.name.localeCompare(b.name));
        custom.sort((a, b) => a.name.localeCompare(b.name));
        const result = builtin.concat(custom);
        for (let i = 0; i < result.length; i++) {
            result[i].index = i;
        }
        return result;
    }
}

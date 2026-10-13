import QtQuick
import Quickshell
import ".."
import "../services"

/// Hover tooltip for bar items (spec §10 Tooltips): base-raised card,
/// 1 px border, no arrow, 200 px max width. One instance per bar;
/// items call show()/hide() — the 400 ms delay lives in BarSlot.
PopupWindow {
    id: root

    /// Item currently showing the tooltip (null when hidden).
    property Item _target: null

    readonly property bool _below: ConfigService.barPosition !== "bottom"
    readonly property int _gap: 4

    function show(item: Item, text: string) {
        if (!item || !text) return;
        label.text = text;
        root._target = item;
        root.anchor.item = item;
        root.anchor.rect.x = 0;
        root.anchor.rect.width = item.width;
        root.anchor.rect.y = root._below ? 0 : -root._gap;
        root.anchor.rect.height = item.height + root._gap;
        root.visible = true;
        root.anchor.updateAnchor();
    }

    /// Hide if `item` owns the tooltip (or unconditionally when null).
    function hide(item) {
        if (item && item !== root._target) return;
        root.visible = false;
        root._target = null;
    }

    anchor.edges: root._below ? Edges.Bottom : Edges.Top
    anchor.gravity: root._below ? Edges.Bottom : Edges.Top

    visible: false
    color: "transparent"
    implicitWidth: card.width
    implicitHeight: card.height

    Rectangle {
        id: card
        width: label.width + Theme.space3 * 2
        height: label.implicitHeight + Theme.space2 * 2
        color: Theme.baseRaised
        border.color: Theme.border
        border.width: 1

        Text {
            id: label
            x: Theme.space3
            y: Theme.space2
            width: Math.min(implicitWidth, 200)
            wrapMode: Text.Wrap
            color: Theme.text2
            font.family: Theme.sansFont
            font.pixelSize: Theme.fontBody
        }
    }
}

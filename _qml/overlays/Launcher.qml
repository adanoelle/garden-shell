import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import ".."
import "../compositor"
import "../services"

/// Universal command palette (Super+/).
///
/// Searches apps, channels, palettes, and inline calc. Triggered via
/// `qs ipc call garden toggleLauncher` or HookService.launcherToggled signal.
PanelWindow {
    id: launcher

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    visible: false
    color: "transparent"
    focusable: true
    exclusiveZone: 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "garden-launcher"

    // ── State ─────────────────────────────────────────────────────────

    property bool _open: false
    property var _results: []

    // ── Toggle ────────────────────────────────────────────────────────

    Connections {
        target: HookService
        function onLauncherToggled() { launcher._toggle(); }
    }

    function _toggle() {
        if (_open) _close();
        else _show();
    }

    function _show() {
        _open = true;
        content.opacity = 0;
        contentSlide.y = 20;
        searchInput.text = "";
        _results = _buildResults("");
        visible = true;
        searchInput.forceActiveFocus();
        showAnim.start();
    }

    function _close() {
        if (!_open) return;
        hideAnim.start();
    }

    // ── Animations ────────────────────────────────────────────────────

    ParallelAnimation {
        id: showAnim

        NumberAnimation {
            target: content; property: "opacity"
            to: 1; duration: 150; easing.type: Easing.OutCubic
        }
        NumberAnimation {
            target: contentSlide; property: "y"
            to: 0; duration: 150; easing.type: Easing.OutCubic
        }
    }

    ParallelAnimation {
        id: hideAnim

        NumberAnimation {
            target: content; property: "opacity"
            to: 0; duration: 150; easing.type: Easing.InCubic
        }
        NumberAnimation {
            target: contentSlide; property: "y"
            to: 20; duration: 150; easing.type: Easing.InCubic
        }

        onFinished: {
            launcher._open = false;
            launcher.visible = false;
        }
    }

    // ── Backdrop ──────────────────────────────────────────────────────

    DitherOverlay { density: "dense" }

    // Click outside to close.
    MouseArea {
        anchors.fill: parent
        onClicked: launcher._close()
    }

    // ── Content ───────────────────────────────────────────────────────

    Column {
        id: content
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        width: 460
        spacing: 8
        opacity: 0

        transform: Translate { id: contentSlide; y: 20 }

        // Main panel.
        Rectangle {
            width: parent.width
            height: panelColumn.height + 2
            color: Theme.base
            border.color: Theme.border
            border.width: 1

            Column {
                id: panelColumn
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: parent.top
                anchors.margins: 1

                // Search row.
                Item {
                    width: parent.width
                    height: 40

                    Text {
                        id: slashPrefix
                        anchors.left: parent.left
                        anchors.leftMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        text: "/"
                        color: Theme.text4
                        font.family: Theme.monoFont
                        font.pixelSize: 14
                    }

                    TextInput {
                        id: searchInput
                        anchors.left: slashPrefix.right
                        anchors.leftMargin: 4
                        anchors.right: parent.right
                        anchors.rightMargin: 12
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.text1
                        selectionColor: Theme.baseHl
                        selectedTextColor: Theme.text1
                        font.family: Theme.monoFont
                        font.pixelSize: 14
                        clip: true
                        focus: true

                        onTextChanged: {
                            launcher._results = launcher._buildResults(text);
                            resultList.currentIndex = launcher._results.length > 0 ? 0 : -1;
                        }

                        Keys.onEscapePressed: launcher._close()

                        Keys.onUpPressed: {
                            if (resultList.currentIndex > 0)
                                resultList.currentIndex--;
                        }

                        Keys.onDownPressed: {
                            if (resultList.currentIndex < resultList.count - 1)
                                resultList.currentIndex++;
                        }

                        Keys.onReturnPressed: launcher._executeSelected()
                    }
                }

                // Separator (hidden when no results).
                Rectangle {
                    width: parent.width
                    height: launcher._results.length > 0 ? 1 : 0
                    color: Theme.borderSub
                    visible: launcher._results.length > 0
                }

                // Result list.
                ListView {
                    id: resultList
                    width: parent.width
                    height: Math.min(contentHeight, 36 * 8)
                    clip: true
                    model: launcher._results
                    currentIndex: 0
                    highlightMoveDuration: 60
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: Rectangle {
                        id: resultDelegate
                        required property var modelData
                        required property int index

                        width: resultList.width
                        height: 36
                        color: index === resultList.currentIndex
                            ? Theme.baseHl : "transparent"

                        Text {
                            anchors.left: parent.left
                            anchors.leftMargin: 12
                            anchors.right: badgeText.left
                            anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            text: resultDelegate.modelData.name
                            color: Theme.text1
                            font.family: Theme.monoFont
                            font.pixelSize: 13
                            font.weight: resultDelegate.index === resultList.currentIndex
                                ? Font.DemiBold : Font.Normal
                            elide: Text.ElideRight
                        }

                        Text {
                            id: badgeText
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            text: "[" + resultDelegate.modelData.type + "]"
                            color: Theme.text4
                            font.family: Theme.monoFont
                            font.pixelSize: 11
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: {
                                resultList.currentIndex = resultDelegate.index;
                                launcher._executeSelected();
                            }
                        }
                    }
                }
            }
        }

        // Hint text with background for readability over dither.
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: hintText.width + 16
            height: hintText.height + 8
            radius: 3
            color: Theme.base
            border.color: Theme.borderSub
            border.width: 1

            Text {
                id: hintText
                anchors.centerIn: parent
                text: "Esc close  \u00b7  \u2191\u2193 navigate  \u00b7  \u21b5 run"
                color: Theme.text3
                font.family: Theme.monoFont
                font.pixelSize: 11
            }
        }
    }

    // ── Result building ───────────────────────────────────────────────

    function _buildResults(query: string): var {
        const q = query.trim().toLowerCase();
        const results = [];
        const cap = 20;

        // Apps (only when query is non-empty to avoid flooding).
        if (q.length > 0) {
            const apps = [...DesktopEntries.applications.values];
            for (let i = 0; i < apps.length && results.length < cap; i++) {
                const app = apps[i];
                const name = app.name || "";
                const kws = (app.keywords || []).join(" ").toLowerCase();
                if (name.toLowerCase().includes(q) || kws.includes(q)) {
                    results.push({
                        type: "app",
                        name: name,
                        _action: "app",
                        _entry: app
                    });
                }
            }
        }

        // Channels.
        const workspaces = CompositorService.workspaces;
        for (let i = 0; i < workspaces.length && results.length < cap; i++) {
            const ws = workspaces[i];
            if (q === "" || ws.name.toLowerCase().includes(q)) {
                results.push({
                    type: "channel",
                    name: ws.name,
                    _action: "channel",
                    _target: ws.name
                });
            }
        }

        // Palettes.
        const palettes = Theme.paletteNames;
        for (let i = 0; i < palettes.length && results.length < cap; i++) {
            const p = palettes[i];
            if (q === "" || p.toLowerCase().includes(q)) {
                results.push({
                    type: "palette",
                    name: p,
                    _action: "palette",
                    _target: p
                });
            }
        }

        // Calc: if the query looks like a math expression, evaluate it.
        if (q.length > 0 && /^[\d\s+\-*\/().%]+$/.test(q)) {
            try {
                const val = eval(q);
                if (val !== undefined && !isNaN(val)) {
                    results.push({
                        type: "calc",
                        name: "= " + val,
                        _action: "calc",
                        _target: String(val)
                    });
                }
            } catch (_e) { /* ignore parse errors */ }
        }

        return results;
    }

    // ── Execution ─────────────────────────────────────────────────────

    function _executeSelected() {
        if (resultList.currentIndex < 0
            || resultList.currentIndex >= _results.length) return;

        const result = _results[resultList.currentIndex];

        switch (result._action) {
        case "app":
            result._entry.execute();
            _close();
            break;
        case "channel":
            CompositorService.focusWorkspace(result._target);
            _close();
            break;
        case "palette":
            Theme.switchPalette(result._target);
            _close();
            break;
        case "calc":
            _clipProcess.command = ["wl-copy", "--", result._target];
            _clipProcess.running = true;
            _close();
            break;
        }
    }

    // ── Helpers ───────────────────────────────────────────────────────

    Process {
        id: _clipProcess
        running: false
    }
}

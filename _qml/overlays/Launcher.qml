import QtQuick
import Quickshell
import Quickshell.Io
import ".."
import "../components"
import "../compositor"
import "../services"

/// Universal command palette (Super+/).
///
/// Searches apps, channels, palettes, and inline calc. Triggered via
/// `qs ipc call garden toggleLauncher` or HookService.launcherToggled signal.
OverlayBase {
    id: launcher

    _namespace:    "garden-launcher"
    animDuration:  150
    contentTarget: content
    slideTarget:   contentSlide

    // ── State ─────────────────────────────────────────────────────────

    property var _results: []

    // ── Toggle ────────────────────────────────────────────────────────

    Connections {
        target: HookService
        function onLauncherToggled() { launcher._toggle(); }
    }

    // ── Show-init hook ────────────────────────────────────────────────

    function _onBeforeShow() {
        searchInput.text = "";
        launcher._results = launcher._buildResults("");
        searchInput.forceActiveFocus();
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
                    height: Math.min(contentHeight, 28 * 8)
                    clip: true
                    model: launcher._results
                    currentIndex: 0
                    highlightMoveDuration: 60
                    boundsBehavior: Flickable.StopAtBounds

                    delegate: ResultItem {
                        required property var modelData
                        required property int index

                        primary:   modelData.name
                        secondary: "[" + modelData.type + "]"
                        selected:  index === resultList.currentIndex
                        onActivated: {
                            resultList.currentIndex = index;
                            launcher._executeSelected();
                        }
                    }
                }
            }
        }

        HintLabel {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "Esc close  \u00b7  \u2191\u2193 navigate  \u00b7  \u21b5 run"
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
            const val = launcher._evalExpr(q);
            if (!isNaN(val)) {
                results.push({
                    type: "calc",
                    name: "= " + val,
                    _action: "calc",
                    _target: String(val)
                });
            }
        }

        return results;
    }

    // ── Calc ──────────────────────────────────────────────────────────

    /// Arithmetic evaluator: tokenize → shunting-yard → RPN. Replaces
    /// eval() (injection-adjacent even behind the regex gate). Supports
    /// + - * / %, parens, decimals, unary minus/plus. Any malformed
    /// input returns NaN → no calc row, matching the old catch-and-drop.
    function _evalExpr(expr) {
        // Tokenize: numbers and single-char operators.
        const tokens = [];
        let i = 0;
        while (i < expr.length) {
            const ch = expr[i];
            if (ch === " " || ch === "\t") { i++; continue; }
            if (/[\d.]/.test(ch)) {
                let j = i;
                while (j < expr.length && /[\d.]/.test(expr[j])) j++;
                const s = expr.slice(i, j);
                if ((s.match(/\./g) || []).length > 1) return NaN;
                const num = parseFloat(s);
                if (isNaN(num)) return NaN;
                tokens.push(num);
                i = j;
            } else if ("+-*/%()".includes(ch)) {
                tokens.push(ch);
                i++;
            } else {
                return NaN;
            }
        }

        // Shunting-yard. `prevWasValue` distinguishes binary from
        // unary +/- ("2-3" vs "-3", "2*-3"); unary minus ("u-") binds
        // tightest and is right-associative, unary plus is a no-op.
        const prec = { "u-": 3, "*": 2, "/": 2, "%": 2, "+": 1, "-": 1 };
        const out = [];
        const ops = [];
        let prevWasValue = false;

        for (const tok of tokens) {
            if (typeof tok === "number") {
                out.push(tok);
                prevWasValue = true;
            } else if (tok === "(") {
                if (prevWasValue) return NaN;   // "2(3)" — no implicit *
                ops.push(tok);
                prevWasValue = false;
            } else if (tok === ")") {
                while (ops.length && ops[ops.length - 1] !== "(")
                    out.push(ops.pop());
                if (!ops.length) return NaN;    // unbalanced
                ops.pop();
                prevWasValue = true;
            } else {
                let op = tok;
                if (!prevWasValue) {
                    if (op === "-") op = "u-";
                    else if (op === "+") continue;
                    else return NaN;            // "*3", "(/2" …
                }
                while (ops.length) {
                    const top = ops[ops.length - 1];
                    if (top === "(") break;
                    if (prec[top] > prec[op]
                            || (prec[top] === prec[op] && op !== "u-"))
                        out.push(ops.pop());
                    else break;
                }
                ops.push(op);
                prevWasValue = false;
            }
        }
        while (ops.length) {
            const op = ops.pop();
            if (op === "(") return NaN;         // unbalanced
            out.push(op);
        }

        // Evaluate the RPN stream.
        const st = [];
        for (const t of out) {
            if (typeof t === "number") {
                st.push(t);
            } else if (t === "u-") {
                if (!st.length) return NaN;
                st.push(-st.pop());
            } else {
                if (st.length < 2) return NaN;
                const b = st.pop();
                const a = st.pop();
                switch (t) {
                case "+": st.push(a + b); break;
                case "-": st.push(a - b); break;
                case "*": st.push(a * b); break;
                case "/": st.push(a / b); break;
                case "%": st.push(a % b); break;
                }
            }
        }
        return st.length === 1 ? st[0] : NaN;
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
            _closeInstant();
            Theme.switchPalette(result._target);
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

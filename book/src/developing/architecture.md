# Shell architecture

> The QML shell is a set of singletons and overlay windows composed by
> Quickshell.

Garden's desktop shell is a [Quickshell](https://quickshell.outfoxxed.me/)
configuration — a tree of QML components that Quickshell turns into Wayland
surfaces. This page maps the source tree, explains the major patterns, and shows
how they fit together.

## Directory layout

```
_qml/
├── shell.qml                   # Entry point — ShellRoot
├── Theme.qml                   # Singleton: palette colors + fonts
├── bar/
│   ├── Bar.qml                 # Per-screen status bar (Variants)
│   ├── BarChannel.qml          # Workspace/channel indicator
│   ├── BarClock.qml            # Clock display
│   └── BarDot.qml              # Minimal dot indicator
├── compositor/
│   ├── CompositorService.qml   # Singleton: workspace + window state
│   └── NiriAdapter.qml         # Singleton: niri event stream consumer
├── overlays/
│   ├── Launcher.qml            # Command palette (Super+/)
│   ├── ChannelSwitcher.qml     # Workspace switcher (Super+Tab)
│   ├── Settings.qml            # Settings panel (Super+,)
│   ├── DitherOverlay.qml       # Reusable dithered backdrop
│   ├── PaletteEditor.qml       # Color editor inside Settings
│   ├── PaletteSelector.qml     # Palette list inside Settings
│   ├── PalettePreview.qml      # Live color swatch grid
│   ├── ColorInput.qml          # Single hex color input field
│   ├── ColorInputGroup.qml     # Group of color inputs by category
│   └── KeybindsPlaceholder.qml # Placeholder for keybinds tab
└── services/
    ├── HookService.qml         # Singleton: signal hub + IPC handler
    ├── ConfigService.qml       # Singleton: settings.json watcher
    └── ModeService.qml         # Singleton: per-channel bar modes
```

The underscore prefix (`_qml/`) keeps this directory out of Nix's import-tree
scanner — it's read directly by Quickshell via a symlink from
`~/.config/quickshell/garden`.

## Singletons

QML singletons are lazy — they don't instantiate until something references
them. `shell.qml` forces all singletons to start by holding a property reference
to each:

```qml
ShellRoot {
    property var _hooks: HookService
    property var _niri: NiriAdapter
    property var _config: ConfigService
    property var _mode: ModeService
    // ...
}
```

Theme and CompositorService are referenced indirectly (every visual component
binds to `Theme.*`, and NiriAdapter writes to CompositorService), so they don't
need explicit references.

| Singleton | Module | Owns | Key properties | Key signals |
|-----------|--------|------|----------------|-------------|
| **Theme** | root | Palette colors, fonts, palette switching | 13 `color` props, `activePalette`, `paletteNames`, `sansFont`, `monoFont` | — |
| **HookService** | services | IPC handler, signal routing | — | `launcherToggled`, `switcherToggled`, `settingsToggled`, `paletteChanged`, `channelSwitched` |
| **ConfigService** | services | `settings.json` watcher | `palette`, `barPosition`, `channels` | — |
| **ModeService** | services | Per-channel bar height logic | `currentHeight`, `showContent`, `showExtended`, `barMode` | — |
| **CompositorService** | compositor | Workspace/window state (written by NiriAdapter) | `activeWorkspace`, `columns`, `workspaces` | `workspaceChanged` |
| **NiriAdapter** | compositor | Niri event stream, action dispatch | `overviewOpen` | — |

All singletons use `pragma Singleton` and `pragma ComponentBehavior: Bound`.

## The overlay pattern

Every overlay follows the same structure. Launcher.qml is the canonical
template — start there when creating a new overlay.

The skeleton:

```qml
PanelWindow {
    id: myOverlay

    // Full-screen, transparent, on the overlay layer.
    anchors { top: true; bottom: true; left: true; right: true }
    visible: false
    color: "transparent"
    focusable: true
    exclusiveZone: 0

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    WlrLayershell.namespace: "garden-myoverlay"

    // ── State ──────────────────────────────────────────
    property bool _open: false

    // ── Toggle (connected to HookService signal) ───────
    Connections {
        target: HookService
        function onMyOverlayToggled() { myOverlay._toggle(); }
    }

    function _toggle() {
        if (_open) _close(); else _show();
    }

    function _show() {
        _open = true;
        content.opacity = 0;
        contentSlide.y = 20;
        visible = true;
        showAnim.start();
    }

    function _close() {
        if (!_open) return;
        hideAnim.start();
    }

    // ── Fade + slide animations ────────────────────────
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
            myOverlay._open = false;
            myOverlay.visible = false;
        }
    }

    // ── Backdrop ───────────────────────────────────────
    DitherOverlay { density: "dense" }

    MouseArea {
        anchors.fill: parent
        onClicked: myOverlay._close()
    }

    // ── Content ────────────────────────────────────────
    Column {
        id: content
        anchors.centerIn: parent
        opacity: 0
        transform: Translate { id: contentSlide; y: 20 }

        // Your UI goes here.
    }
}
```

The key moving parts:

- **PanelWindow** — Quickshell's Wayland surface. `WlrLayer.Overlay` puts it
  above everything; `WlrKeyboardFocus.Exclusive` grabs input.
- **DitherOverlay** — a Bayer-dithered backdrop that tints the screen without a
  blur shader. Three density presets: `"dense"` (~88% fill), `"light"` (~50%),
  `"lock"` (~3%).
- **Fade + slide** — `showAnim` / `hideAnim` animate opacity and a Y translate
  simultaneously. The hide animation sets `visible = false` in `onFinished`.
- **Escape to close** — either via `Keys.onEscapePressed` on a FocusScope or on
  the input field itself.
- **Click-outside** — a MouseArea behind the content calls `_close()`.

## IPC

External tools control the shell via Quickshell's IPC mechanism. The flow:

```
qs ipc -c garden call garden toggleLauncher
    → IpcHandler.toggleLauncher()
        → HookService.launcherToggled()  (signal emitted)
            → Launcher's Connections { onLauncherToggled: _toggle() }
```

HookService acts as a signal hub. It declares signals for every shell-level
event and exposes an IpcHandler with the target `"garden"`. Each IPC method
emits the corresponding signal and returns a status string:

```qml
// In HookService.qml
IpcHandler {
    target: "garden"

    function toggleLauncher(): string {
        root.launcherToggled();
        return "toggled launcher";
    }
}
```

Overlays connect to HookService signals — they never reference each other
directly:

```qml
// In Launcher.qml
Connections {
    target: HookService
    function onLauncherToggled() { launcher._toggle(); }
}
```

This decoupling means adding a new IPC action is three edits: add the signal,
add the IPC method, add the Connections block in the target component.

## Theme reactivity

The live palette system uses a file-watch pipeline:

```
garden-themes apply --name yoru
    → writes ~/.config/garden/themes/palettes.json
        → Theme.qml FileView (watchChanges: true)
            → _loadPalette() updates all 13 color properties
                → every component binding to Theme.* updates instantly
```

Theme.qml watches `palettes.json` with a Quickshell `FileView`. When the file
changes, it reloads the JSON and updates each color property. Because QML
properties are reactive, every component that binds to (for example)
`Theme.accent` re-renders automatically.

### The binding-loop guard

When a component needs to write a property *and* read it reactively (common in
color editors), you risk a binding loop — QML detects a circular dependency and
logs a warning. The established pattern uses an `_updating` flag:

```qml
// From ColorInput.qml
property bool _updating: false

onColorValueChanged: {
    if (!hexInput.activeFocus) {
        root._updating = true;
        hexInput.text = root.colorValue;
        root._updating = false;
    }
}
```

The TextInput's `onTextChanged` handler checks `!root._updating` before emitting
signals, breaking the loop.

### Object replacement for change detection

QML's change detection on `var` properties (arrays, objects) only fires when the
reference changes, not when contents mutate. To trigger updates after modifying
an object, replace the entire reference:

```js
// Force QML to notice the change
root.myObject = JSON.parse(JSON.stringify(root.myObject));
```

Always guard this with a check that the value actually changed — otherwise you
get infinite re-evaluation.

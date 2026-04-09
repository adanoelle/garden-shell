# Development workflow

> Edit, save, see — most QML changes are live in under a second.

## The dev loop

The shell reads QML directly from the source tree via a symlink:

```
~/.config/quickshell/garden → ~/src/garden-shell/_qml/
```

Quickshell watches for file changes and hot-reloads automatically, so the
feedback loop is fast. How fast depends on what you changed:

| What changed | How it takes effect | What to check |
|---|---|---|
| Edit an existing QML file | **Automatic.** Quickshell hot-reloads on save. | `just qs-log` for errors |
| Add a new QML file or component | **Automatic.** Hot-reload picks up new files. | `just qs-log` — new files are the most common source of silent errors |
| Add or change a niri keybind | **Requires `nixos-rebuild switch` in fern.** Niri config is generated from Nix. | `just switch` from garden-shell, then test the keybind |

The first two tiers are where you'll spend almost all your time. Keybind changes
are rare and usually happen once at the end, when you're wiring a new overlay to
a keyboard shortcut.

## How the shell runs

Niri starts Quickshell at login via `spawn-at-startup`:

```
spawn-at-startup "quickshell" "-c" "garden"
```

Quickshell runs as a persistent daemon. It reads the `garden` configuration from
the symlink target (`_qml/shell.qml`), creates Bar surfaces for each monitor,
and keeps overlay windows hidden until toggled via IPC.

The symlink is the key development trick — Quickshell reads your working tree
directly, so there's no build step, no copy, no Home Manager generation. You
edit a `.qml` file, save, and see the result. The trade-off is that the shell
can break if you save a file mid-edit with syntax errors. It recovers on the
next valid save.

## Debugging QML

Quickshell runs daemonized with stderr connected to its own log system, not the
terminal. **`just qs-log` is the only way to see QML errors.** Get in the habit
of keeping it running in a terminal while developing:

```bash
just qs-log          # Follow logs (Ctrl-C to stop)
just qs-log-tail 50  # Last 50 lines, non-blocking
```

### Common error patterns

**Binding loops.** QML warns `Binding loop detected for property "X"`. These
cause infinite re-evaluation and can freeze rendering. The fix: guard
programmatic property writes with a flag so the write doesn't trigger itself
(see the `_updating` pattern in
[Shell architecture](architecture.md#the-binding-loop-guard)).

Example log output:

```
qml: Binding loop detected for property "text" — ColorInput.qml:80
```

**Silent failures.** An IPC call returns `"toggled settings"` but nothing
appears on screen. This almost always means the component has a QML error —
it loaded but didn't render. Check the log for the actual error; it's usually
a property type mismatch or a missing import.

**Import errors.** New singletons need their module imported. If you reference
`HookService` from an overlay but don't have `import "../services"` at the top,
you'll get an opaque "ReferenceError: HookService is not defined" in the log.

**Stale state after file moves.** If you rename or move a file, Quickshell's
file watcher may not pick up the change cleanly. This is the one situation where
you need a restart:

```bash
just qs-restart   # Kill process; niri auto-respawns it
```

## Adding a new overlay

The full checklist from blank file to working keybind:

1. **Create the QML file.** Add `_qml/overlays/NewOverlay.qml` following the
   PanelWindow pattern from [Shell architecture](architecture.md#the-overlay-pattern).

2. **Add a signal and IPC method.** In `_qml/services/HookService.qml`, add a
   signal (`signal newOverlayToggled()`) and an IPC method
   (`function toggleNewOverlay()`) that emits it.

3. **Wire it into shell.qml.** Add `NewOverlay {}` inside the ShellRoot block.

4. **Check logs.** Save everything and run `just qs-log`. The overlay is now
   loaded (but hidden). Fix any errors that appear.

5. **Test via IPC.** Toggle it from the terminal:

   ```bash
   just qs-ipc toggleNewOverlay
   ```

6. **Add a keybind in fern.** Edit
   `~/src/fern/modules/desktop/niri.nix` to add the keybind:

   ```nix
   "${mod}+SomeKey".action.spawn = [
     "sh" "-c" "qs -c garden ipc call garden toggleNewOverlay"
   ];
   ```

7. **Update the reference config.** Add the same keybind to
   `_config/niri.kdl` so the garden-shell repo documents it.

8. **Deploy.** Run `just switch` from garden-shell to rebuild fern with the
   new keybind. Test the keyboard shortcut.

Steps 1-5 are hot-reload territory — fast iteration, no rebuilds. Steps 6-8
happen once and require a NixOS rebuild.

## Fern integration

Garden Shell defines the QML shell and Nix aspects. Fern is the NixOS
configuration that consumes them. The relationship matters for deployment.

### Where keybinds live

Niri keybinds are declared in `~/src/fern/modules/desktop/niri.nix`:

```nix
"${mod}+Slash".action.spawn = [
  "sh" "-c" "qs -c garden ipc call garden toggleLauncher"
];
"${mod}+Tab".action.spawn = [
  "sh" "-c" "qs -c garden ipc call garden toggleSwitcher"
];
"${mod}+Comma".action.spawn = [
  "sh" "-c" "qs -c garden ipc call garden toggleSettings"
];
```

These become part of the niri config at NixOS eval time. They only change when
fern is rebuilt.

### When to rebuild where

- **`just switch` in garden-shell** — when you've changed garden-shell code
  (QML, Rust, Nix aspects). Uses `--override-input` so fern sees your local
  tree instead of the flake lock.
- **`just switch` in fern** — when you've only changed fern itself (niri
  settings, user packages) and garden-shell hasn't changed locally.

During active development, almost always run from garden-shell.

### Updating the lock

After pushing garden-shell changes, update fern's flake lock so both repos
agree:

```bash
cd ~/src/fern && nix flake update garden-shell
```

## Justfile recipes

All QML development recipes live under the `# QML / Quickshell` section of the
justfile.

| Recipe | What it does | Example |
|--------|-------------|---------|
| `qs-log` | Follow Quickshell logs in real time | `just qs-log` |
| `qs-log-tail [N]` | Show last N lines of logs (default 30) | `just qs-log-tail 50` |
| `qs-restart` | Kill Quickshell; niri respawns it | `just qs-restart` |
| `qs-ipc <method>` | Call a garden IPC method | `just qs-ipc toggleSettings` |
| `qs-ipc-show` | List available IPC methods | `just qs-ipc-show` |
| `dogfood` | Build, test, restart, and smoke-test IPC | `just dogfood` |
| `switch` | Rebuild fern with local garden-shell | `just switch` |
| `book-serve` | Serve the book with live reload | `just book-serve` |
| `book-build` | Build the book (also validates structure) | `just book-build` |

## Design rationale

### Why the symlink?

Home Manager could copy QML files into the Nix store on each rebuild. But that
turns a sub-second hot-reload into a multi-second `nixos-rebuild switch` for
every change. The symlink makes Quickshell read your working tree directly,
giving you the iteration speed of a web browser's dev tools. The cost is that
the shell can momentarily break on bad saves — a trade-off worth making during
active development.

### Why three tiers?

The tier system exists because different parts of the system have different
update mechanisms. QML files are watched by Quickshell's file watcher — free,
instant. Niri keybinds are generated by Nix at eval time — they require a
rebuild. Pretending these are the same would either mean unnecessary rebuilds
(slow) or would hide the rebuild requirement (confusing). Naming the tiers makes
the cost of each change explicit.

### Why `qs log` instead of stderr?

Quickshell runs as a daemon, started by niri at login with no controlling
terminal. There's no stderr to connect to. Quickshell provides its own log
system (`qs log -c garden`) that captures QML warnings, `console.log` output,
and framework diagnostics. The justfile recipes (`qs-log`, `qs-log-tail`) are
thin wrappers that set the right flags so you don't have to remember them.

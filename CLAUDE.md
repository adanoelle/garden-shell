# Garden Shell -- Claude Code Context

## Project Overview

Garden is a composable infrastructure and desktop environment for NixOS, built
as a den namespace provider. It exports aspects via `flake.denful.garden` that
consumers (like the fern NixOS config) can import.

## Architecture

- **Den namespace**: `garden` -- exported via
  `(inputs.den.namespace "garden" true)`
- **Aspects**: palette, terminal, toolkit, daemon, ctl, tui, observability,
  shell
- **Rust crates**: garden-core, garden-daemon, garden-ctl, garden-tui,
  garden-themes
- **QML**: Quickshell desktop shell

## Directory Structure

```
garden-shell/
├── flake.nix              # flake-parts + import-tree + den
├── Cargo.toml             # Rust workspace
├── justfile               # Build recipes
├── modules/               # Auto-imported by import-tree
│   ├── dendritic.nix      # Den bootstrap
│   ├── namespace.nix      # Garden namespace creation
│   ├── systems.nix        # Supported architectures
│   ├── packages.nix       # Nix package definitions
│   ├── devshell.nix       # Dev shell
│   └── aspects/           # Den aspects (garden.*)
│       ├── palette.nix    # Foundation: color palettes
│       ├── terminal.nix   # Kitty + fish + kakoune
│       ├── toolkit.nix    # CLI tool suite
│       ├── daemon.nix     # Infrastructure daemon
│       ├── ctl.nix        # CLI control tool
│       ├── tui.nix        # Terminal UI
│       ├── observability.nix  # SSH monitoring
│       └── shell.nix      # Full desktop bundle
├── crates/                # Rust workspace members
├── _qml/                  # QML shell (underscore = not auto-imported)
└── _config/               # Config files (palettes, settings)
```

## Quick Commands

```bash
cargo build          # Build all Rust crates
cargo test           # Run tests
just check           # nix flake check
just fmt             # Format Nix + Rust
just lint            # Format + check
nix develop          # Enter dev shell
just qs-log          # Follow Quickshell logs (QML errors show here)
just qs-restart      # Kill Quickshell; niri auto-respawns it
just qs-ipc toggleSettings   # Call a garden IPC method
```

## Den Patterns

- Aspects use `garden.<name>` syntax (namespaced, not `den.aspects.<name>`)
- `includes` composes aspects:
  `garden.terminal = { includes = [ garden.palette ]; ... }`
- Underscore directories (`_qml/`, `_config/`) are skipped by import-tree
- Consumer imports: `(inputs.den.namespace "garden" [ inputs.garden-shell ])`

## Safety Rules

1. **ALWAYS** run `nix flake check` before committing
2. **ALWAYS** run `cargo build` after modifying Rust code
3. **NEVER** modify Cargo.lock manually -- use `cargo update`
4. Format with `nixpkgs-fmt` and `cargo fmt` before committing

## QML Development Workflow

### How the shell runs

The QML shell is served to Quickshell via a symlink:

```
~/.config/quickshell/garden → /home/ada/src/garden-shell/_qml/
```

Quickshell reads directly from the source tree. It is started by niri
(`spawn-at-startup "quickshell" "-c" "garden"`) and runs as a daemon.

### Three tiers of change

| What changed | How it takes effect |
|---|---|
| Edit an existing QML file | **Automatic.** Quickshell watches files and hot-reloads on save. |
| Add a new QML file / component | **Automatic.** Hot-reload picks up new files. Check `just qs-log` for errors. |
| Add/change a niri keybind | **Requires `nixos-rebuild switch` in fern.** Niri config is generated from `~/src/fern/modules/desktop/niri.nix`. |

### Debugging QML

**Always check `just qs-log` after making QML changes.** Quickshell runs
daemonized with stderr to `/dev/null`, so QML errors are only visible via the
built-in log system.

```bash
just qs-log              # Follow logs (Ctrl-C to stop)
just qs-log-tail 50      # Last 50 lines (non-blocking)
```

Common issues:
- **Binding loops**: QML warns `Binding loop detected for property "X"`. These
  cause infinite updates and can prevent rendering. Break the loop by guarding
  programmatic property writes (see `ColorInput._updating` pattern).
- **Silent failures**: If an IPC call returns success but nothing renders, the
  component likely has a QML error. Check the log.
- **Import errors**: New singletons must be imported
  (`import "../services"`) -- `pragma Singleton` makes them available within
  their module but they still need the import path.

### Restarting Quickshell

When hot-reload isn't enough (rare -- usually only after moving/renaming files):

```bash
just qs-restart          # Kill process; niri respawns it automatically
```

### Fern integration

Niri keybinds and Home Manager config live in `~/src/fern`. Garden overlays are
wired in `~/src/fern/modules/desktop/niri.nix`:

```nix
"${mod}+Slash".action.spawn = [ "sh" "-c" "qs -c garden ipc call garden toggleLauncher" ];
"${mod}+Tab".action.spawn   = [ "sh" "-c" "qs -c garden ipc call garden toggleSwitcher" ];
"${mod}+Comma".action.spawn = [ "sh" "-c" "qs -c garden ipc call garden toggleSettings" ];
```

To rebuild fern with local garden-shell changes:

```bash
just switch              # In garden-shell: rebuilds fern with path override
```

**When to run from where:**
- **`just switch` in garden-shell** — when you've changed garden-shell code
  (QML, Rust, Nix aspects). Uses `--override-input` so fern sees your local
  tree instead of the flake lock.
- **`just switch` in fern** — when you've only changed fern itself (niri
  settings, user config, packages) and garden-shell hasn't changed locally.
- During active garden-shell development, almost always run from garden-shell.

After pushing garden-shell changes, update fern's lock so both work:

```bash
cd ~/src/fern && nix flake update garden-shell
```

### QML coding patterns

When writing new QML components, follow these patterns from the existing codebase:

- **Overlays**: Follow `Launcher.qml` exactly -- PanelWindow, WlrLayer.Overlay,
  DitherOverlay backdrop, fade+slide animation, Escape to close.
- **Singletons**: Use `pragma Singleton` + `pragma ComponentBehavior: Bound`.
  Reference singletons in `shell.qml` to force instantiation.
- **IPC**: Add signal to `HookService.qml`, add method to `IpcHandler`, connect
  in the overlay via `Connections { target: HookService }`.
- **Reactivity**: When replacing an object to trigger QML change detection
  (`JSON.parse(JSON.stringify(...))`), guard against binding loops by checking
  if the value actually changed before replacing.

### Checklist: adding a new overlay

1. Create `_qml/overlays/NewOverlay.qml` (PanelWindow pattern)
2. Add signal + IPC method in `_qml/services/HookService.qml`
3. Add `NewOverlay {}` in `_qml/shell.qml`
4. Check `just qs-log` for errors after hot-reload
5. Test via `just qs-ipc toggleNewOverlay`
6. Add keybind in `~/src/fern/modules/desktop/niri.nix`
7. Add keybind in `_config/niri.kdl` (reference config)
8. `just switch` to deploy the keybind

## Integration Rules

When adding theme/config integration with a new tool:

1. **Verify the target app supports the mechanism first.** Before writing any
   integration code (include directives, source commands, IPC calls), test that
   the app actually supports it. For example, run `<app> validate` on a minimal
   config with the proposed directive.

2. **Never replace a Home Manager symlink with a mutable file.** If HM manages
   `~/.config/foo/config`, treat it as read-only. Mutable content injection
   requires the app to support `include`/`source` directives, env vars, IPC, or
   XDG override dirs.

3. **Test one thing at a time.** Validate each approach independently before
   moving on. Don't stack untested workarounds.

4. **When something doesn't work, reassess the premise.** If the first approach
   fails, stop and ask whether the feature is actually supported rather than
   trying increasingly creative workarounds. Accepting a trade-off (e.g. "this
   app's colors only change on `nixos-rebuild switch`") is better than breaking
   the config.

### Niri-specific

Niri (as of 25.05) does **not** support `include` directives or runtime color
IPC. Niri colors are set at Nix eval time via `programs.niri.settings` in fern
and only change on `nixos-rebuild switch`. The `garden-themes` niri generator
exists as reference output only.

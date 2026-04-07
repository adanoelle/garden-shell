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
- **QML**: Quickshell desktop shell (stub)

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

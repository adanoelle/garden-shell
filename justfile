mod themes 'crates/garden-themes'

fern := env("FERN_DIR", home_directory() + "/src/fern")

# Show available recipes
help:
    @just --list
    @echo ""
    @echo "Submodules:"
    @echo "  just themes ...    theme generation & dogfooding"

# ── Rust ─────────────────────────────────────────────────────────

# Build all crates
build:
    cargo build

# Run all tests
test:
    cargo test

# Type-check all crates
check:
    cargo check

# Lint all crates
clippy:
    cargo clippy

# Format everything
fmt:
    cargo fmt
    find modules -name '*.nix' | xargs nixpkgs-fmt

# Check Nix flake
flake-check:
    nix flake check

# Build a specific package via Nix
nix-build pkg:
    nix build .#{{pkg}}

# Enter dev shell
dev:
    nix develop

# ── QML / Quickshell ────────────────────────────────────────────

# Follow Quickshell logs (QML errors, warnings, debug output)
qs-log:
    qs log -c garden -f --tail 1

# Show last N lines of Quickshell logs (default 30)
qs-log-tail lines="30":
    qs log -c garden --tail {{lines}}

# Restart Quickshell. Note: the nixpkgs binary's comm is
# ".quickshell-wrapped" so `pkill -x quickshell` never matched, and niri's
# spawn-at-startup does NOT respawn — so kill by cmdline and relaunch here.
# The [l] bracket keeps pkill -f from matching this recipe's own sh -c
# cmdline (which contains the pattern) and SIGTERMing itself; the
# ^[^ ]* anchor matches only processes whose argv[0] is quickshell, so a
# shell that merely mentions the command line is never killed.
# Relaunching via `niri msg action spawn` gives the shell niri's own
# environment, like spawn-at-startup — a plain launch from a `nix
# develop` shell would leak GARDEN_THEMES_BIN (palette switches would run
# target/debug/garden-themes) and IN_NIX_SHELL into every app it starts.
qs-restart:
    pkill -f "^[^ ]*quickshel[l] -c garden" || true
    pkill -f "^[^ ]*quickshel[l] -p {{justfile_directory()}}/_qml" || true
    sleep 1
    niri msg action spawn -- quickshell -c garden || setsid quickshell -c garden >/dev/null 2>&1 &
    @echo "quickshell restarted"

# For machines where ~/.config/quickshell/garden is a Home Manager copy
# (source edits don't hot-reload). Runs in the foreground; Ctrl-C (or
# the dev shell exiting) restores the deployed shell. While it runs,
# everything addressing the shell by name — niri keybinds and the
# before-sleep lock (`qs -c garden ipc …`) — gets "No running
# instances": the dev instance is keyed by its source path. Use
# `qs ipc -p _qml call garden …` to drive it.
# Run the shell from this source tree (foreground; Ctrl-C restores)
qs-dev:
    #!/usr/bin/env bash
    set -u
    dev="{{justfile_directory()}}/_qml"
    restore() {
        pkill -f "^[^ ]*quickshel[l] -p $dev" || true
        niri msg action spawn -- quickshell -c garden \
            || setsid quickshell -c garden >/dev/null 2>&1 &
        echo "deployed shell restored"
    }
    pkill -f "^[^ ]*quickshel[l] -c garden" || true
    pkill -f "^[^ ]*quickshel[l] -p $dev" || true
    sleep 1
    trap restore EXIT
    echo "running from $dev — niri keybinds and lock-before-sleep are INACTIVE until Ctrl-C"
    quickshell -p "$dev"

# Call a garden IPC method (e.g. just qs-ipc toggleSettings)
qs-ipc method *args:
    qs ipc -c garden call garden {{method}} {{args}}

# Show available IPC methods
qs-ipc-show:
    qs ipc -c garden show

# Probe native Bluetooth/Networking state (read-only, no scans)
qs-probe-netbt:
    qs -p _qml/dev/netbt-probe.qml

# Probe Quickshell service module availability (core-services plan, phase 0)
qs-probe:
    qs --version
    qs -p _qml/dev/probe.qml

# ── Dogfooding ──────────────────────────────────────────────────

# Build, test, restart Quickshell, and smoke-test IPC
dogfood:
    cargo build
    cargo test
    pkill -x quickshell || true
    @echo "waiting for quickshell to respawn..."
    @sleep 2
    qs ipc -c garden show
    @echo ""
    @echo "dogfood ready — check qs log if anything looks wrong:"
    @echo "  just qs-log"

# Rebuild fern NixOS config with local garden-shell (deploys keybinds, niri config)
switch:
    sudo nixos-rebuild switch --flake {{fern}}#fern \
        --override-input garden-shell path:$(pwd)

# ── Documentation ───────────────────────────────────────────────

# Serve the book with live reload
book-serve:
    mdbook serve book --open

# Build the book
book-build:
    mdbook build book

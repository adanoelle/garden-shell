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

# Kill Quickshell (niri auto-respawns it via spawn-at-startup)
qs-restart:
    pkill -x quickshell || true
    @echo "quickshell killed; niri will respawn it"

# Call a garden IPC method (e.g. just qs-ipc toggleSettings)
qs-ipc method *args:
    qs ipc -c garden call garden {{method}} {{args}}

# Show available IPC methods
qs-ipc-show:
    qs ipc -c garden show

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

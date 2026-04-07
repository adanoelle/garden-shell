mod themes 'crates/garden-themes'

# Show available recipes
help:
    @just --list
    @echo ""
    @echo "Submodules:"
    @echo "  just themes ...    theme generation & dogfooding"

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

# Serve the book with live reload
book-serve:
    mdbook serve book --open

# Build the book
book-build:
    mdbook build book

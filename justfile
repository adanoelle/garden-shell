# Build all Rust crates
build:
    cargo build

# Run tests
test:
    cargo test

# Check Nix flake
check:
    nix flake check

# Format everything
fmt:
    cargo fmt
    find modules -name '*.nix' | xargs nixpkgs-fmt

# Lint (format + check)
lint: fmt check

# Build a specific package via Nix
nix-build pkg:
    nix build .#{{pkg}}

# Enter dev shell
dev:
    nix develop

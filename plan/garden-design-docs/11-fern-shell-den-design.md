# fern-shell — Den Namespace Design

> A composable infrastructure and desktop environment, exported as
> a Den namespace. Each aspect is independently includable. Hosts
> choose what they need.

**Created:** 2026-04-04

---

## 1. What This Repository Is

fern-shell is a **Den namespace provider** called `garden`. It exports
composable aspects that the fern NixOS configuration (and any future
host configs) consume via `den.ful.garden`.

It is NOT just a desktop shell. It is a namespace containing:
- A Quickshell/QML desktop environment (for graphical workstations)
- A Rust infrastructure daemon (for any host)
- A CLI tool (for any host)
- A TUI control plane (for interactive hosts)
- An observability layer (for any host)
- A palette/theming system (shared by all visual components)

Each of these is an independent aspect. A headless server might include
only `garden.daemon` and `garden.observability`. A dev workstation
includes everything. A services node includes daemon + observability
+ ctl. The aspects compose via `includes` dependencies.

---

## 2. Repository Structure

```
fern-shell/
├── flake.nix                    # Den + import-tree, exports denful.garden
├── flake.lock
├── CLAUDE.md                    # Agent context
├── Cargo.toml                   # Rust workspace root
├── Cargo.lock
│
├── modules/                     # Den modules (auto-imported by import-tree)
│   ├── namespace.nix            # Creates + exports the "garden" namespace
│   ├── packages.nix             # Nix package definitions for all Rust crates
│   ├── devshell.nix             # Development environment
│   │
│   └── aspects/                 # One file per aspect
│       ├── palette.nix          # Color system — shared foundation
│       ├── shell.nix            # Quickshell desktop environment
│       ├── daemon.nix           # Infrastructure monitoring daemon
│       ├── ctl.nix              # CLI tool
│       ├── tui.nix              # Ratatui control plane
│       ├── observability.nix    # Host metrics + connection health
│       ├── terminal.nix         # Kitty + Fish + Kakoune stack
│       └── toolkit.nix          # CLI tools (bat, delta, fzf, yazi, etc.)
│
├── crates/                      # Rust workspace
│   ├── garden-core/             # Shared types, traits, event bus
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── lib.rs
│   │       ├── types.rs         # HostConfig, HostTier, ConnectionState
│   │       ├── events.rs        # GardenEvent enum
│   │       └── ports.rs         # StoragePort, RemoteExecutor, NotificationEmitter
│   │
│   ├── garden-daemon/           # Persistent systemd user service
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── main.rs
│   │       ├── server.rs        # Unix socket IPC server
│   │       ├── ssh.rs           # SSH ControlMaster monitoring
│   │       ├── health.rs        # Connection health checker
│   │       ├── jobs.rs          # Job tracker
│   │       └── storage.rs       # SQLite via StoragePort
│   │
│   ├── garden-ctl/              # CLI tool
│   │   ├── Cargo.toml
│   │   └── src/
│   │       └── main.rs          # status, jobs, connect, watch, health
│   │
│   ├── garden-tui/              # Ratatui control plane
│   │   ├── Cargo.toml
│   │   └── src/
│   │       ├── main.rs
│   │       ├── app.rs           # 4-panel dashboard
│   │       ├── widgets.rs       # Connection, jobs, agents, event log
│   │       └── theme.rs         # Reads palettes.json for Ratatui colors
│   │
│   └── garden-themes/           # Palette generator (17 outputs)
│       ├── Cargo.toml
│       └── src/
│           ├── main.rs          # garden-themes regenerate
│           ├── palette.rs       # Read/parse palettes.json
│           └── generators/      # One module per output target
│               ├── kitty.rs
│               ├── fish.rs
│               ├── kakoune.rs
│               ├── bat.rs
│               ├── fzf.rs
│               ├── lazygit.rs
│               ├── btop.rs
│               ├── yazi.rs
│               ├── obsidian.rs
│               ├── zathura.rs
│               ├── gtk.rs
│               └── niri.rs
│
├── _qml/                        # Quickshell QML sources (underscore = not a Den module)
│   ├── shell.qml                # Root ShellRoot
│   ├── Theme.qml                # Palette singleton
│   ├── ConfigService.qml        # Reads settings.json
│   │
│   ├── compositor/
│   │   ├── CompositorService.qml  # Abstract interface
│   │   ├── NiriAdapter.qml        # Niri IPC via $NIRI_SOCKET
│   │   └── ScratchpadService.qml  # Floating window toggle
│   │
│   ├── bar/
│   │   ├── Bar.qml              # Main bar container
│   │   ├── BarChannel.qml       # Channel tab with column indicators
│   │   ├── BarDot.qml           # Inactive channel dot
│   │   ├── BarClock.qml         # Time display
│   │   └── BarHost.qml          # Host tier indicator
│   │
│   ├── launcher/
│   │   ├── Launcher.qml         # Universal launcher
│   │   ├── AppSource.qml        # Desktop entry search
│   │   ├── ChannelSource.qml    # Workspace search
│   │   ├── CommandSource.qml    # Shell command source
│   │   └── CalcSource.qml       # Inline calculator
│   │
│   ├── overlays/
│   │   ├── ChannelSwitcher.qml
│   │   ├── DitherOverlay.qml    # PC-98 dithered backdrop
│   │   ├── Notifications.qml
│   │   ├── OSD.qml
│   │   ├── DesktopClock.qml
│   │   ├── LockScreen.qml
│   │   ├── PowerMenu.qml
│   │   └── MediaControls.qml
│   │
│   ├── settings/
│   │   ├── SettingsPanel.qml
│   │   ├── PaletteEditor.qml
│   │   └── KeybindEditor.qml
│   │
│   └── services/
│       ├── HookService.qml      # IPC handlers
│       ├── ModeService.qml      # Per-channel mode stacks
│       ├── NotificationService.qml  # D-Bus server
│       └── DaemonBridge.qml     # garden-ctl watch --json consumer
│
├── _config/                     # Config templates (underscore = not a Den module)
│   ├── palettes.json            # Four built-in palettes
│   ├── settings.json            # Default Garden settings
│   ├── niri/
│   │   └── config.kdl           # Niri compositor config
│   ├── kitty/
│   │   └── kitty.conf           # Kitty terminal config (mokume)
│   ├── fish/
│   │   ├── fish_prompt.fish     # ✧ prompt
│   │   ├── garden-theme.fish    # Fish color theme
│   │   └── garden-tools.fish    # Tool integration (fzf, bat, zoxide)
│   ├── kak/
│   │   ├── kakrc                # Kakoune base config
│   │   └── colors/
│   │       └── garden.kak       # Garden colorscheme
│   └── systemd/
│       └── garden-daemon.service  # Systemd unit template
│
├── _templates/                  # Typst templates (underscore = not a Den module)
│   ├── garden-paper.typ         # Academic paper template
│   └── garden-cv.typ            # CV template
│
└── tests/                       # Nix + Rust tests
    └── ...
```

### Why the underscore convention

Den uses import-tree to auto-discover modules. Any directory or file
starting with `_` is excluded. This means:
- `modules/` — every `.nix` file is a Den flake-parts module
- `_qml/` — QML sources, NOT modules (resources consumed by aspects)
- `_config/` — config file templates, NOT modules
- `_templates/` — Typst templates, NOT modules
- `crates/` — Rust source, NOT modules (but referenced by modules/packages.nix)

---

## 3. flake.nix

```nix
{
  description = "Garden — composable infrastructure and desktop environment";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    den.url = "github:vic/den";
    import-tree.url = "github:vic/import-tree";
    
    flake-parts.url = "github:hercules-ci/flake-parts";
    flake-parts.inputs.nixpkgs-lib.follows = "nixpkgs";
    
    quickshell = {
      url = "github:outfoxxed/quickshell";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    niri = {
      url = "github:sodiboo/niri-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    rust-overlay = {
      url = "github:oxalica/rust-overlay";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; }
    (inputs.import-tree ./modules);
}
```

---

## 4. The Namespace Module

```nix
# modules/namespace.nix
# Creates and exports the "garden" namespace
{ inputs, ... }: {
  imports = [
    inputs.den.flakeModules.default
    (inputs.den.namespace "garden" true)  # true = exported via flake.denful.garden
  ];
}
```

This creates:
- `den.ful.garden` — the namespace, usable internally
- `garden` — module argument alias (shorthand)
- `flake.denful.garden` — flake output for external consumers

---

## 5. Package Definitions

```nix
# modules/packages.nix
# Build all Rust crates and make them available
{ inputs, ... }: {
  perSystem = { pkgs, system, ... }:
  let
    rustPkgs = import inputs.nixpkgs {
      inherit system;
      overlays = [ inputs.rust-overlay.overlays.default ];
    };
    rustToolchain = rustPkgs.rust-bin.stable.latest.default;
  in {
    packages = {
      garden-daemon = pkgs.rustPlatform.buildRustPackage {
        pname = "garden-daemon";
        version = "0.1.0";
        src = ../.;  # workspace root
        cargoLock.lockFile = ../Cargo.lock;
        cargoBuildFlags = [ "-p" "garden-daemon" ];
      };
      
      garden-ctl = pkgs.rustPlatform.buildRustPackage {
        pname = "garden-ctl";
        version = "0.1.0";
        src = ../.;
        cargoLock.lockFile = ../Cargo.lock;
        cargoBuildFlags = [ "-p" "garden-ctl" ];
      };
      
      garden-tui = pkgs.rustPlatform.buildRustPackage {
        pname = "garden-tui";
        version = "0.1.0";
        src = ../.;
        cargoLock.lockFile = ../Cargo.lock;
        cargoBuildFlags = [ "-p" "garden-tui" ];
      };
      
      garden-themes = pkgs.rustPlatform.buildRustPackage {
        pname = "garden-themes";
        version = "0.1.0";
        src = ../.;
        cargoLock.lockFile = ../Cargo.lock;
        cargoBuildFlags = [ "-p" "garden-themes" ];
      };
      
      garden-shell = pkgs.stdenvNoCC.mkDerivation {
        pname = "garden-shell";
        version = "0.1.0";
        src = ../_qml;
        installPhase = ''
          mkdir -p $out/share/quickshell/garden
          cp -r . $out/share/quickshell/garden/
        '';
      };
    };
  };
}
```

---

## 6. Aspect Definitions

### 6.1 palette — Foundation

Everything visual depends on this. No other dependencies.

```nix
# modules/aspects/palette.nix
{
  garden.palette = {
    # Home Manager: install palettes.json and the theme generator
    homeManager = { pkgs, ... }: {
      xdg.configFile."garden/palettes.json".source = ../../_config/palettes.json;
      home.packages = [ self.packages.${pkgs.system}.garden-themes ];
    };
  };
}
```

### 6.2 terminal — Kitty + Fish + Kakoune

The terminal environment. Can be used without the desktop shell.

```nix
# modules/aspects/terminal.nix
{ garden, ... }: {
  garden.terminal = {
    includes = [ garden.palette ];
    
    nixos = { pkgs, ... }: {
      programs.fish.enable = true;
      fonts.packages = with pkgs; [ m-plus-1p ibm-plex ];
      environment.systemPackages = with pkgs; [
        kitty
        kakoune
        kak-lsp
        helix
        wl-clipboard
      ];
    };
    
    homeManager = { pkgs, ... }: {
      # Kitty
      xdg.configFile."kitty/kitty.conf".source = ../../_config/kitty/kitty.conf;
      
      # Fish prompt and theme
      xdg.configFile."fish/functions/fish_prompt.fish".source =
        ../../_config/fish/fish_prompt.fish;
      xdg.configFile."fish/conf.d/garden-theme.fish".source =
        ../../_config/fish/garden-theme.fish;
      xdg.configFile."fish/conf.d/garden-tools.fish".source =
        ../../_config/fish/garden-tools.fish;
      
      # Kakoune
      xdg.configFile."kak/kakrc".source = ../../_config/kak/kakrc;
      xdg.configFile."kak/colors/garden.kak".source =
        ../../_config/kak/colors/garden.kak;
      
      # Default editor
      home.sessionVariables = {
        EDITOR = "kak";
        VISUAL = "kak";
      };
    };
  };
}
```

### 6.3 toolkit — CLI tools

```nix
# modules/aspects/toolkit.nix
{ garden, ... }: {
  garden.toolkit = {
    includes = [ garden.palette ];
    
    nixos = { pkgs, ... }: {
      environment.systemPackages = with pkgs; [
        ripgrep fd bat delta zoxide jq yazi
        fzf lazygit btop glow xh jless chafa
      ];
    };
    
    homeManager = {
      # Git config with delta
      programs.git = {
        enable = true;
        delta.enable = true;
        delta.options = {
          line-numbers = true;
          side-by-side = false;
          syntax-theme = "ansi";
        };
      };
    };
  };
}
```

### 6.4 daemon — Infrastructure monitoring

Runs on ANY host — workstation, server, services node.

```nix
# modules/aspects/daemon.nix
{ garden, ... }: {
  garden.daemon = {
    nixos = { pkgs, ... }: {
      # Systemd user service
      systemd.user.services.garden-daemon = {
        description = "Garden infrastructure daemon";
        wantedBy = [ "default.target" ];
        serviceConfig = {
          ExecStart = "${self.packages.${pkgs.system}.garden-daemon}/bin/garden-daemon";
          Restart = "on-failure";
          RestartSec = "5s";
        };
      };
      
      # Create socket directory
      systemd.tmpfiles.rules = [
        "d /run/user/%U/garden 0700 - - -"
      ];
    };
    
    homeManager = {
      xdg.configFile."garden/daemon.toml".text = ''
        [storage]
        path = "~/.local/share/garden/state.db"
        
        [ssh]
        socket_dir = "~/.ssh/sockets"
        health_interval_secs = 30
        
        [ipc]
        socket = "/run/user/1000/garden/daemon.sock"
      '';
    };
  };
}
```

### 6.5 ctl — CLI tool

```nix
# modules/aspects/ctl.nix
{ garden, ... }: {
  garden.ctl = {
    includes = [ garden.daemon ];  # needs daemon running
    
    homeManager = { pkgs, ... }: {
      home.packages = [
        self.packages.${pkgs.system}.garden-ctl
      ];
      
      # Fish completions for garden-ctl
      # (generated by clap_complete or hand-written)
    };
  };
}
```

### 6.6 tui — Ratatui control plane

```nix
# modules/aspects/tui.nix
{ garden, ... }: {
  garden.tui = {
    includes = [ garden.ctl garden.palette ];
    
    homeManager = { pkgs, ... }: {
      home.packages = [
        self.packages.${pkgs.system}.garden-tui
      ];
    };
  };
}
```

### 6.7 observability — Host metrics

Different behavior depending on host context.

```nix
# modules/aspects/observability.nix
{ garden, ... }: {
  garden.observability = {
    includes = [ garden.daemon ];
    
    nixos = { pkgs, ... }: {
      # Lightweight system metrics for garden-daemon to consume
      environment.systemPackages = with pkgs; [ btop ];
      
      # Enable SSH monitoring (ControlMaster socket watching)
      programs.ssh.extraConfig = ''
        ControlMaster auto
        ControlPath ~/.ssh/sockets/%r@%h:%p
        ControlPersist 600
      '';
    };
    
    homeManager = {
      # Ensure socket directory exists
      home.file.".ssh/sockets/.keep".text = "";
    };
  };
}
```

### 6.8 shell — Quickshell desktop environment

The full desktop shell. Only for graphical workstations.

```nix
# modules/aspects/shell.nix
{ garden, inputs, ... }: {
  garden.shell = {
    includes = [
      garden.palette
      garden.terminal
      garden.toolkit
      garden.daemon
      garden.ctl
      garden.observability
    ];
    
    nixos = { pkgs, ... }: {
      # Niri compositor
      programs.niri.enable = true;
      
      # Quickshell
      environment.systemPackages = [
        inputs.quickshell.packages.${pkgs.system}.default
        self.packages.${pkgs.system}.garden-shell
      ];
      
      # XWayland for X11 apps
      programs.xwayland.enable = true;
    };
    
    homeManager = { pkgs, ... }: {
      # Niri config
      xdg.configFile."niri/config.kdl".source = ../../_config/niri/config.kdl;
      
      # Quickshell Garden Shell config
      xdg.configFile."quickshell/garden".source =
        "${self.packages.${pkgs.system}.garden-shell}/share/quickshell/garden";
      
      # Garden settings
      xdg.configFile."garden/settings.json".source = ../../_config/settings.json;
    };
  };
}
```

---

## 7. Aspect Dependency Graph

```
palette (foundation — no dependencies)
  │
  ├── terminal (kitty, fish, kakoune)
  ├── toolkit (bat, delta, fzf, yazi, ...)
  ├── tui (ratatui dashboard)
  │
  daemon (no dependencies — can run standalone)
  │
  ├── ctl (depends on daemon)
  │   └── tui (depends on ctl + palette)
  │
  └── observability (depends on daemon)

  shell (the big one — includes everything above)
    includes: palette, terminal, toolkit, daemon, ctl, observability
```

### Composition Examples

**Full workstation** (your garden dev machine):
```nix
den.aspects.garden-workstation = {
  includes = [
    garden.shell    # pulls in everything
    garden.tui      # add the TUI on top
  ];
};
```

**Headless services node** (homelab services machine):
```nix
den.aspects.services-node = {
  includes = [
    garden.daemon
    garden.ctl
    garden.observability
  ];
  # No shell, no terminal config, no toolkit
  # Just the infrastructure monitoring
};
```

**Remote HPC jumpbox** (minimal monitoring):
```nix
den.aspects.hpc-monitor = {
  includes = [
    garden.daemon
    garden.observability
  ];
};
```

**Dev machine without desktop shell** (SSH-only):
```nix
den.aspects.headless-dev = {
  includes = [
    garden.terminal
    garden.toolkit
    garden.daemon
    garden.ctl
    garden.tui
    garden.observability
  ];
  # Full terminal experience, no compositor
};
```

---

## 8. Consumer Side (fern NixOS config)

In the fern repo, the garden namespace is imported:

```nix
# fern: modules/garden-namespace.nix
{ inputs, ... }: {
  imports = [
    (inputs.den.namespace "garden" [ inputs.fern-shell ])
  ];
}
```

Then hosts include the aspects they need:

```nix
# fern: modules/hosts/garden.nix
{ garden, ... }: {
  den.hosts.x86_64-linux.garden = {
    aspect = "garden-workstation";
    users.ada = {};
  };
  
  den.aspects.garden-workstation = {
    includes = [
      garden.shell
      garden.tui
    ];
  };
}
```

```nix
# fern: modules/hosts/fern.nix
# The gaming machine keeps Hyprland, doesn't use garden.shell
{ garden, ... }: {
  den.hosts.x86_64-linux.fern = {
    aspect = "fern-gaming";
    users.ada = {};
  };
  
  den.aspects.fern-gaming = {
    includes = [
      garden.terminal     # Kitty + Fish + Kakoune
      garden.toolkit      # CLI tools
      garden.daemon       # infrastructure monitoring
      garden.ctl
      garden.observability
      # NO garden.shell — fern uses Hyprland, not Niri
    ];
    # Hyprland config lives in fern's own aspects, not in garden
  };
}
```

---

## 9. Rust Workspace

### Cargo.toml (workspace root)

```toml
[workspace]
resolver = "2"
members = [
  "crates/garden-core",
  "crates/garden-daemon",
  "crates/garden-ctl",
  "crates/garden-tui",
  "crates/garden-themes",
]

[workspace.dependencies]
tokio = { version = "1", features = ["full"] }
serde = { version = "1", features = ["derive"] }
serde_json = "1"
anyhow = "1"
clap = { version = "4", features = ["derive"] }
tracing = "0.1"
tracing-subscriber = "0.3"
```

### Crate Purposes

| Crate | Binary | Purpose | Key Dependencies |
|-------|--------|---------|-----------------|
| garden-core | — (lib) | Shared types, traits, event bus | serde, tokio |
| garden-daemon | garden-daemon | Persistent systemd service, SSH monitoring, IPC server | garden-core, tokio, rusqlite |
| garden-ctl | garden-ctl | CLI for querying daemon | garden-core, clap |
| garden-tui | garden-tui | Ratatui 4-panel dashboard | garden-core, ratatui, crossterm |
| garden-themes | garden-themes | Palette → 17 theme files | garden-core, serde_json, tera |

### garden-core types

```rust
// types.rs
pub enum HostTier { Critical, Standard, Local }
pub enum ConnectionState { Connected, Disconnected, Degraded, Unknown }

pub struct HostConfig {
    pub name: String,
    pub tier: HostTier,
    pub address: String,
    pub user: String,
}

pub struct ConnectionHealth {
    pub host: String,
    pub state: ConnectionState,
    pub latency_ms: Option<u64>,
    pub last_check: chrono::DateTime<chrono::Utc>,
}

// events.rs
pub enum GardenEvent {
    ConnectionChanged { host: String, state: ConnectionState },
    JobSubmitted { id: String, host: String },
    JobCompleted { id: String, exit_code: i32 },
    HealthCheck { host: String, healthy: bool },
}

// ports.rs (hexagonal architecture)
pub trait StoragePort { ... }
pub trait RemoteExecutor { ... }
pub trait NotificationEmitter { ... }
```

---

## 10. Development Workflow

```nix
# modules/devshell.nix
{ inputs, ... }: {
  perSystem = { pkgs, system, ... }: {
    devShells.default = pkgs.mkShell {
      buildInputs = with pkgs; [
        # Rust
        (rust-bin.stable.latest.default.override {
          extensions = [ "rust-src" "rust-analyzer" ];
        })
        
        # Nix
        nixpkgs-fmt
        
        # QML
        # quickshell for live reload testing
        inputs.quickshell.packages.${system}.default
        
        # Tools
        just
        cargo-watch
      ];
      
      shellHook = ''
        echo "garden dev shell"
        echo "  cargo build      — build all crates"
        echo "  cargo test       — run tests"
        echo "  qs -p _qml/shell.qml  — live reload QML"
        echo "  just             — list recipes"
      '';
    };
  };
}
```

### Justfile

```just
# Build all Rust crates
build:
    cargo build

# Run tests
test:
    cargo test

# Live reload QML shell
shell:
    quickshell -p _qml/shell.qml

# Regenerate themes from palettes.json
themes:
    cargo run -p garden-themes -- regenerate

# Check Nix
check:
    nix flake check

# Format everything
fmt:
    cargo fmt
    nixpkgs-fmt modules/**/*.nix
```

---

## 11. Binary Cache

Rust crates rebuild from source on every `nixos-rebuild switch`
where the source hash changes. On the dev machine this is fine —
you're building locally anyway. It becomes a problem when:
- Multiple hosts consume the garden namespace
- Clean rebuilds take minutes
- A low-power services node tries to compile Rust from scratch

### Phase 1: Cachix (immediate, free for open source)

Cachix is a hosted binary cache. Set up a GitHub Action that builds
all crates and pushes to Cachix on every commit to main. Any machine
with the cache configured pulls pre-built binaries instead of compiling.

```yaml
# .github/workflows/cache.yml
name: Build and cache
on:
  push:
    branches: [ main ]

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: cachix/install-nix-action@v30
        with:
          nix_path: nixpkgs=channel:nixos-unstable
      - uses: cachix/cachix-action@v15
        with:
          name: garden
          authToken: ${{ secrets.CACHIX_AUTH_TOKEN }}
      - run: |
          nix build .#garden-daemon
          nix build .#garden-ctl
          nix build .#garden-tui
          nix build .#garden-themes
          nix build .#garden-shell
```

Consumer machines add the cache to their Nix config:

```nix
# fern: modules/caches.nix
{
  nix.settings = {
    substituters = [
      "https://garden.cachix.org"
      "https://cache.nixos.org"
    ];
    trusted-public-keys = [
      "garden.cachix.org-1:XXXXX..."  # from cachix setup
      "cache.nixos.org-1:DnaN..."
    ];
  };
}
```

Now `nixos-rebuild switch` on the services node or gaming machine
pulls garden-daemon as a pre-built binary. Zero compilation.

### Phase 2: Attic (self-hosted, when services node is built)

Attic is a self-hosted binary cache written in Rust. It runs on
your homelab services node and serves binaries to all machines on
your network. No external dependency.

```nix
# On the services node:
services.atticd = {
  enable = true;
  settings = {
    listen = "0.0.0.0:8080";
    database.url = "sqlite:///var/lib/atticd/server.db";
    storage = {
      type = "local";
      path = "/var/lib/atticd/storage";
    };
  };
};
```

Your dev machine pushes after building:

```fish
# After a successful build on garden dev machine
attic push garden:main \
  (nix build .#garden-daemon --print-out-paths) \
  (nix build .#garden-ctl --print-out-paths) \
  (nix build .#garden-tui --print-out-paths) \
  (nix build .#garden-themes --print-out-paths)
```

### What happens without a cache

If no cache is configured and the source hasn't changed, Nix won't
rebuild — the store path already exists locally. The cache matters
for:
- First build on a new machine
- After a `nix-collect-garbage`
- When deploying to a different machine than where you developed

Start with Cachix. Migrate to Attic when your services node exists.

---

## 12. Agent Scaffolding Sessions

### Session S1: Repository Skeleton

**Goal:** Create the repo structure, flake.nix, namespace, empty
aspect files, Cargo workspace with stub crates.

**Tasks:**
- [ ] Initialize git repo
- [ ] Create `flake.nix` with all inputs
- [ ] Create `modules/namespace.nix` (garden namespace, exported)
- [ ] Create `modules/packages.nix` (stub package defs)
- [ ] Create `modules/devshell.nix`
- [ ] Create all aspect files as stubs under `modules/aspects/`
- [ ] Create `Cargo.toml` workspace with five member crates
- [ ] Create stub `lib.rs`/`main.rs` for each crate
- [ ] Create `_qml/shell.qml` minimal skeleton
- [ ] Create `_config/palettes.json` with four palettes
- [ ] Create `_config/` directory with all config templates
- [ ] Create `CLAUDE.md` with repo context
- [ ] Create `justfile`
- [ ] Verify: `nix flake check` passes
- [ ] Verify: `cargo build` succeeds (stubs compile)

**Estimated scope:** 2-3 hours

### Session S2: Palette Aspect + Theme Generator

**Goal:** Make `garden.palette` functional. Build garden-themes
crate that generates all 17 output files.

**Reference:** `03-palette-and-theming.md`

**Tasks:**
- [ ] Implement palettes.json parsing in garden-themes
- [ ] Implement generators for each target (kitty, fish, kakoune, etc.)
- [ ] Wire garden.palette aspect to install palettes.json + garden-themes
- [ ] Populate `_config/` with generated theme files for mokume palette
- [ ] Verify: `cargo run -p garden-themes -- regenerate` works

### Session S3: Terminal + Toolkit Aspects

**Goal:** Make `garden.terminal` and `garden.toolkit` functional
with all config files.

**Reference:** `02-shell-design.md` Sections 13-14

**Tasks:**
- [ ] Populate `_config/kitty/kitty.conf`
- [ ] Populate `_config/fish/` (prompt, theme, tools)
- [ ] Populate `_config/kak/` (kakrc, garden.kak)
- [ ] Wire aspects to install configs via xdg.configFile
- [ ] Wire aspects to install packages via nixos/homeManager

### Session S4: Daemon + Ctl + Observability

**Goal:** Build the infrastructure Rust crates and their aspects.

**Reference:** `04-infrastructure.md`

**Tasks:**
- [ ] Implement garden-core types and traits
- [ ] Implement garden-daemon (Unix socket IPC, SSH monitoring)
- [ ] Implement garden-ctl (status, watch, health commands)
- [ ] Wire daemon aspect (systemd service)
- [ ] Wire ctl aspect (user package)
- [ ] Wire observability aspect (SSH config, socket dir)

### Session S5: TUI

**Goal:** Build the Ratatui control plane.

**Reference:** `04-infrastructure.md` Section 9

**Tasks:**
- [ ] Implement garden-tui (4-panel dashboard)
- [ ] Read palette from palettes.json for Ratatui theme
- [ ] Connect to daemon via Unix socket
- [ ] Wire tui aspect

### Session S6: Compositor + Shell QML

**Goal:** Build the Quickshell components — NiriAdapter, bar,
launcher, channel switcher.

**Reference:** `02-shell-design.md`, `07-niri-migration.md`

**Tasks:**
- [ ] Implement CompositorService + NiriAdapter
- [ ] Implement Theme.qml (reads palettes.json)
- [ ] Implement Bar (channel indicators, clock, host awareness)
- [ ] Implement Launcher + ChannelSwitcher
- [ ] Implement DitherOverlay
- [ ] Wire shell aspect (Niri + Quickshell + QML sources)

### Session S7: Integration Test with fern

**Goal:** Import garden namespace into fern, build garden host.

**Tasks:**
- [ ] Add fern-shell as input to fern's flake.nix
- [ ] Create garden namespace import in fern
- [ ] Create garden-workstation aspect with garden.shell + garden.tui
- [ ] Build and test: `nix build .#nixosConfigurations.garden...`
- [ ] Deploy to MS-A2

---

## 13. Design Document References

These docs from the garden-design-docs archive specify every detail:

| Aspect | Primary Doc |
|--------|------------|
| palette | `03-palette-and-theming.md` |
| terminal | `02-shell-design.md` §13-14 |
| toolkit | `02-shell-design.md` §14 |
| shell (QML) | `02-shell-design.md` §2-12 |
| shell (Niri) | `07-niri-migration.md` |
| daemon | `04-infrastructure.md` §2-7 |
| ctl | `04-infrastructure.md` §10 |
| tui | `04-infrastructure.md` §9 |
| observability | `04-infrastructure.md` §3-4 |
| writing workflow | `08-research-workflow.md` |
| design philosophy | `01-design-philosophy.md` |

The `garden-palette-editor.jsx` mockup is the visual reference for
all Garden Shell aesthetics.

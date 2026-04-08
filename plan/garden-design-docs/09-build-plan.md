# Garden — Build Plan

> Everything that needs to happen, organized by phase and dependency.
> Each task references the design doc that specifies it.

**Created:** 2026-03-27
**Updated:** 2026-03-31

---

## Pre-Phase: Dendritic Pattern Migration

Before building anything new, both repositories need to migrate to
the dendritic pattern. This is the architectural foundation that
makes everything else clean.

### What Is the Dendritic Pattern

Every `.nix` file is a self-contained flake-parts module. No manual
import lists — `import-tree` automatically discovers all modules.
Files can be moved and nested freely. Adding a new concern means
adding a new file; `flake.nix` never changes. Files prefixed with
`_` are excluded from auto-import (for generated files like
hardware-configuration.nix, or non-module resources like QML sources).

**Key tools:**
- `flake-parts` — modular flake outputs
- `import-tree` (vic/import-tree) — automatic module discovery
- `_` prefix convention — exclude non-module files

**Key principle:** aspect-oriented modules. A single file like
`modules/fish.nix` configures Fish across both NixOS (package install)
and home-manager (user config) using `flake.modules.<class>.<aspect>`.

**Reference:** NixOS Discourse "The dendritic pattern" thread,
dendrix.oeiuwq.com documentation, github.com/mightyiam/dendritic

### Repository: adanoelle/fern (NixOS Configuration)

**Current state:** flake-parts with numbered files (`00-overlay.nix`
through `60-docs.nix`), manual imports in each flake-part file.
Open PR #15 lays out the migration plan.

**Migration tasks:**
- [ ] Add `import-tree` as flake input
- [ ] Simplify `flake.nix` to `(inputs.import-tree ./modules)`
- [ ] Convert `flake.parts/00-overlay.nix` → `modules/overlay.nix`
      (each becomes a standalone flake-parts module)
- [ ] Convert `flake.parts/10-core.nix` → `modules/core.nix`
- [ ] Convert `flake.parts/20-nixos-mods.nix` → individual aspect modules
      (each NixOS module becomes its own file: `modules/boot.nix`,
      `modules/audio.nix`, `modules/networking.nix`, etc.)
- [ ] Convert `flake.parts/30-home-mods.nix` → individual aspect modules
      (each home module: `modules/fish.nix`, `modules/kitty.nix`,
      `modules/kakoune.nix`, etc.)
- [ ] Convert `flake.parts/40-hosts.nix` → `modules/hosts.nix`
      (or per-host: `modules/host-fern.nix`, `modules/host-garden.nix`)
- [ ] Convert `flake.parts/50-dev.nix` → `modules/devshell.nix`
- [ ] Convert `flake.parts/60-docs.nix` → `modules/docs.nix`
- [ ] Move hardware configs to `_hardware/` (underscore prefix, excluded
      from import-tree — these are generated, not authored modules)
- [ ] Add new `garden` host for MS-A2 (AMD CPU + iGPU, no NVIDIA)
- [ ] Update CLAUDE.md with dendritic conventions

**New aspect modules needed for Garden Shell stack:**
- [ ] `modules/niri.nix` — Niri compositor (replaces Hyprland for garden host)
- [ ] `modules/quickshell.nix` — imports fern-shell flake, wires into session
- [ ] `modules/kitty.nix` — terminal emulator (replaces Ghostty)
- [ ] `modules/fish.nix` — shell config, ✧ prompt, channel integration
- [ ] `modules/kakoune.nix` — editor, kak-lsp, garden.kak theme
- [ ] `modules/toolkit.nix` — ripgrep, fd, bat, delta, zoxide, jq, yazi, etc.
- [ ] `modules/fonts.nix` — M PLUS 1p, IBM Plex Mono
- [ ] `modules/zotero.nix` — reference manager + Better BibTeX
- [ ] `modules/obsidian.nix` — knowledge management
- [ ] `modules/typst.nix` — typesetting + Pandoc + CSL styles
- [ ] `modules/radicale.nix` — CalDAV server (homelab service)
- [ ] `modules/super-productivity.nix` — task management

**Host-specific vs shared:** Use dendritic aspect modules that
conditionally apply per host. Example:

```nix
# modules/niri.nix — only applied to garden host
{
  flake.modules.nixos.niri = { config, lib, ... }: {
    config = lib.mkIf (config.networking.hostName == "garden") {
      programs.niri.enable = true;
      # ... niri config
    };
  };
  flake.modules.homeManager.niri = {
    # home-manager niri settings
  };
}
```

Or use a per-host module that enables the right set of aspects:

```nix
# modules/host-garden.nix
{
  flake.nixosConfigurations.garden = /* ... */;
  # enables: niri, quickshell, kitty, fish, kakoune
  # disables: hyprland, nvidia, ghostty, nushell
}
```

### Repository: adanoelle/fern-shell (Quickshell / Garden Shell)

**Current state:** Cargo workspace (Rust crates) + QML sources +
flake-parts. Targets Hyprland with Ghostty/Nushell. 86% Rust, 12% QML.
Exports `homeModules.fern-shell` and `nixosModules.fern-shell`.

**Migration tasks:**
- [ ] Add `import-tree` as flake input
- [ ] Simplify `flake.nix` to `(inputs.import-tree ./modules)`
- [ ] Convert `flake-parts/*.nix` → individual modules under `modules/`
- [ ] QML sources stay in `_qml/` or `fern/` (prefixed/excluded from
      import-tree — these are resources, not flake-parts modules)
- [ ] Rust crates stay in `crates/` (same — excluded or prefixed)
- [ ] Update module exports: `homeModules.garden-shell`,
      `nixosModules.garden-shell` (rename from fern-shell)

**Compositor migration within fern-shell:**
- [ ] Replace Hyprland-specific QML (`HyprlandService.qml`) with
      `CompositorService.qml` + `NiriAdapter.qml`
- [ ] Add `ScratchpadService.qml` for Niri floating window toggle
- [ ] Update all IPC calls from `hyprctl` to `niri msg`
- [ ] Update keybind handling for Niri's bind system
- [ ] Reference: `07-niri-migration.md` for all IPC mappings

**Terminal stack migration within fern-shell:**
- [ ] Any Ghostty/Nushell/Helix references → Kitty/Fish/Kakoune
- [ ] Update Rust CLI tooling (`fernctl`) if it references old stack

### Flake Input Relationship

```
fern (NixOS config)
  ├── inputs.nixpkgs
  ├── inputs.flake-parts
  ├── inputs.import-tree
  ├── inputs.home-manager
  ├── inputs.sops-nix
  ├── inputs.niri (sodiboo/niri-flake)
  ├── inputs.garden-shell (adanoelle/fern-shell)  ← renamed import
  ├── inputs.rust-overlay
  ├── inputs.claude-code
  └── ... other inputs

fern-shell (Garden Shell — Quickshell config)
  ├── inputs.nixpkgs
  ├── inputs.flake-parts
  ├── inputs.import-tree
  ├── inputs.quickshell (outfoxxed/quickshell)
  └── ... build dependencies
```

The NixOS config consumes fern-shell as an input. fern-shell is
independently buildable and testable. Both use the dendritic pattern
internally.

### Inputs to Remove/Update in fern

```nix
# REMOVE (not needed on MS-A2):
nixos-apple-silicon   # no Apple hardware

# RENAME:
fern.url = "github:adanoelle/fern-shell"
# → garden-shell.url = "github:adanoelle/fern-shell"
# (or rename the repo itself)

# ADD:
import-tree.url = "github:vic/import-tree"
niri.url = "github:sodiboo/niri-flake"
quickshell.url = "github:outfoxxed/quickshell"

# UPDATE references:
# Ghostty → Kitty
# Nushell → Fish
# Helix → Kakoune
# Hyprland → Niri (for garden host; keep Hyprland for fern host)
```

### Migration Order

1. **fern repo:** Merge PR #15 (dendritic migration of existing config)
2. **fern repo:** Add `garden` host with MS-A2 hardware config
3. **fern repo:** Add Garden Shell aspect modules (niri, kitty, fish, etc.)
4. **fern-shell repo:** Migrate to dendritic pattern
5. **fern-shell repo:** Compositor migration (Hyprland → Niri adapter)
6. **fern-shell repo:** Build out Garden Shell QML components per design docs
7. **fern repo:** Wire fern-shell into garden host via flake input

---

## Phase 0: Foundation — NixOS + Niri + Core Tools

These are the prerequisites. Nothing else works without them.
**Depends on:** Pre-Phase dendritic migration (at least steps 1-3).

### 0.1 NixOS Base Configuration
- [ ] NixOS install on new Minisforum MS-A2
- [ ] Dendritic flake structure with import-tree (from Pre-Phase)
- [ ] `garden` host module with MS-A2 hardware config
- [ ] niri-flake integration (sodiboo/niri-flake)
- [ ] Quickshell package (outfoxxed/quickshell flake)
- [ ] xwayland-satellite for X11 app support (Clip Studio Paint)
- **Doc:** `07-niri-migration.md`

### 0.2 Niri Configuration
- [ ] `config.kdl` with five named workspaces (studio, research, writing, music, system)
- [ ] Keybinds: Super+1-5 (channels), Super+H/L (scroll columns), Super+N (new), Super+Shift+Q (close)
- [ ] Layout: 2px gaps, 1px borders (palette colors), no rounded corners
- [ ] `center-focused-column "best-effort"`
- [ ] Animations: overdamped springs, 150-200ms, no bounce
- [ ] Window rules: column width presets per app (Kitty 40%, Nyxt 70%, creative apps 100%, Obsidian 60%)
- [ ] Window rules: floating for scratchpads (Garden app, terminal, music, lazygit)
- [ ] Window rules: host tier border colors for SSH terminals
- [ ] Startup programs: Kitty on research, btop on system
- [ ] Writing layout rules: Kakoune 50% + Zathura 50% on writing channel
- **Doc:** `07-niri-migration.md` (Niri Configuration section)

### 0.3 Terminal Stack
- [ ] Kitty install + config (palette colors, IBM Plex Mono 13px, no decoration, padding 16x12)
- [ ] Fish shell install + config
- [ ] Fish ✧ prompt (two-line, color states: text-1/urgent/accent/ok)
- [ ] Fish Garden channel integration ($GARDEN_CHANNEL via `niri msg`)
- [ ] Fish channel-specific abbreviations
- [ ] Fish long-command notification (>10s → Garden Shell notification)
- [ ] Kakoune install + Garden colorscheme (garden.kak)
- [ ] Kakoune LSP (kak-lsp) + tree-sitter
- [ ] Helix install as backup editor
- **Doc:** `02-shell-design.md` (Section 13)

### 0.4 Terminal Toolkit
- [ ] Install essentials: ripgrep, fd, bat, delta, zoxide, jq, yazi
- [ ] Install recommended: lazygit, btop, fzf/skim, glow, xh, jless, chafa
- [ ] bat Garden theme (garden.tmTheme)
- [ ] delta config (syntax-theme = garden, line-numbers)
- [ ] fzf/skim Garden colors (FZF_DEFAULT_OPTS)
- [ ] yazi Garden theme
- [ ] lazygit Garden theme
- [ ] btop Garden theme
- [ ] Fish tool integration (yazi cd-on-exit, bat as MANPAGER, zoxide init)
- **Doc:** `02-shell-design.md` (Section 14)

### 0.5 Fonts
- [ ] M PLUS 1p (UI text, prose)
- [ ] IBM Plex Mono (terminal, code, metrics)
- [ ] NixOS font packages + fontconfig

---

## Phase 1: Palette System — Single Source of Truth

This unlocks theming for everything else.

### 1.1 Palette File
- [ ] `~/.config/garden/palettes.json` with four built-in palettes (mokume, sumi, kinu, yoru)
- [ ] JSON schema: active palette, palette objects with 13 roles + metadata
- [ ] Custom palette support (unlimited, forked_from field)
- **Doc:** `03-palette-and-theming.md` (Sections 1-3)

### 1.2 Theme Generator
- [ ] Script/tool that reads `palettes.json` and generates all theme files
- [ ] Output targets (17 total):
  - Kitty config
  - Fish theme (garden-theme.fish)
  - Fish prompt (fish_prompt.fish)
  - Fish tools (garden-tools.fish — fzf colors, env vars)
  - Kakoune colorscheme (garden.kak)
  - bat theme (garden.tmTheme)
  - lazygit theme (garden.yml)
  - btop theme (garden.theme)
  - yazi theme (garden.toml)
  - Obsidian CSS snippet (garden.css)
  - Zathura config (gardenrc)
  - Nyxt theme (garden-theme.lisp)
  - Blender XML theme
  - GTK 3/4 theme (gtk.css)
  - Kvantum theme (garden.kvconfig)
  - Ratatui colors (for garden-tui)
  - Niri border colors (injected into config.kdl or supplementary)
- [ ] `garden-ctl themes regenerate` command (or standalone script)
- [ ] ANSI 16-color mapping: 13 semantic roles + 4 algorithmically derived complements
- **Doc:** `03-palette-and-theming.md` (Section 6)

### 1.3 Apply Themes
- [ ] Apply generated themes to all installed tools
- [ ] Verify visual consistency across Kitty, Fish, Kakoune, bat, fzf, yazi, lazygit, btop
- [ ] Test palette switching (hard cut) — regenerate + restart apps

---

## Phase 2: Garden Shell — Quickshell/QML

The desktop shell itself. Built iteratively, component by component.

### 2.1 Shell Skeleton
- [ ] `~/.config/quickshell/garden/shell.qml` — root ShellRoot with Variants per screen
- [ ] `Theme.qml` — palette singleton, reads palettes.json
- [ ] `CompositorService.qml` — abstract compositor interface
- [ ] `NiriAdapter.qml` — connects to $NIRI_SOCKET, event stream, reactive properties
- [ ] `ConfigService.qml` — reads settings.json
- [ ] Quickshell launch in niri config.kdl (`spawn-at-startup`)
- **Doc:** `02-shell-design.md` (Sections 12-13), `07-niri-migration.md`

### 2.2 Bar
- [ ] `Bar.qml` — PanelWindow anchored top, three density modes
- [ ] Active channel name (bold, text-1) + column indicators (text-2/text-3)
- [ ] Column order matches strip spatial order (Option H — non-negotiable)
- [ ] Visible/off-screen column distinction (Option C — try it)
- [ ] Inactive channel dots (text-3 occupied, border-sub empty)
- [ ] Clock (IBM Plex Mono, text-1)
- [ ] Mode system: per-channel mode stacks controlling bar density + content
- [ ] Channel-specific content via modes (Option F)
- [ ] Focus debounce (~100ms) for column indicator updates
- **Doc:** `02-shell-design.md` (Section 2), `07-niri-migration.md` (Bar Design Opportunities)

### 2.3 Host Awareness in Bar
- [ ] `HostDetector.qml` — window title matching against SSH host registry
- [ ] Host indicator between columns and clock (hostname in tier color)
- [ ] Connection health dots (▪ in tier colors, solid/hollow/absent)
- [ ] `DaemonBridge.qml` — consumes `garden-ctl watch --json` via Process + SplitParser
- **Doc:** `02-shell-design.md` (Section 2), `04-infrastructure.md` (Sections 3-4)

### 2.4 Launcher
- [ ] `Launcher.qml` — FloatingWindow, dithered backdrop, centered panel
- [ ] `/` prefix, flat result list with source labels (app/page/command/clip/calc)
- [ ] Sources: AppSource, CommandSource, ChannelSource, ClipboardSource, CalcSource
- [ ] Disambiguation: running pages ranked first, categorized results
- [ ] Slow sources appear asynchronously (no blocking)
- [ ] `write <filename>` command — spawns writing environment
- **Doc:** `02-shell-design.md` (Sections 3, 12)

### 2.5 Channel Switcher
- [ ] `ChannelSwitcher.qml` — dithered backdrop, channel list with columns
- [ ] Page name primary, truncated window title in text-3
- [ ] Arrow keys navigate channels, Enter switches, Escape closes
- **Doc:** `02-shell-design.md` (Section 4)

### 2.6 Notifications
- [ ] `NotificationService.qml` — D-Bus notification server
- [ ] `Notifications.qml` — slide from right, progress line, vertical-compress dismiss
- [ ] Global toggle (Super+Shift+N)
- [ ] Auto-suppress during focus sessions
- [ ] Long-command completion notifications from Fish
- **Doc:** `02-shell-design.md` (Section 6)

### 2.7 Overlays & Utilities
- [ ] `DitherOverlay.qml` — PC-98 dithered backdrop (dense/light/lock patterns)
- [ ] `ScratchpadService.qml` — floating window toggle via niri msg IPC
- [ ] `OSD.qml` — volume/brightness bar (280px, 4px progress, 1.5s dismiss)
- [ ] `LockScreen.qml` — dithered texture, typographic clock, 1px border frame
- [ ] `DesktopClock.qml` — always-visible 80px clock, very low opacity, staggered digit entrance
- [ ] `PowerMenu.qml` — horizontal text, destructive confirmation
- [ ] `Calendar.qml` — CalDAV read-only client (Radicale), typographic grid
- [ ] `ClipboardHistory.qml` — launcher extension (Super+Shift+V)
- [ ] `TrayPanel.qml` — text dropdown
- [ ] `NetworkPanel.qml` — text-based connection info
- [ ] `Tooltip.qml` — base-raised card, 400ms delay
- [ ] `MediaControls.qml` — MPRIS scratchpad with dithered album art
- **Doc:** `02-shell-design.md` (Sections 5-10)

### 2.8 Settings Panel
- [ ] `SettingsPanel.qml` — FloatingWindow with dithered backdrop (Super+,)
- [ ] Palette editor: mode selector tabs, 13 hex inputs, live preview
- [ ] Custom palette creation: fork → name → icon → subtitle
- [ ] Export/import palette JSON
- [ ] "Regenerate 17 themes" button
- [ ] Keybind remapper: flat list, click-to-capture, conflict detection
- [ ] Layer badges (niri/quickshell) per keybind
- **Doc:** `02-shell-design.md` (Section 11), palette editor JSX mockup as reference

### 2.9 Extension Architecture
- [ ] `HookService.qml` — signals + IpcHandler (`qs ipc call garden ...`)
- [ ] `ModeService.qml` — per-channel composable mode stacks
- [ ] IPC targets: switchPalette, switchChannel, suppressNotifications,
      focusStart, focusEnd, getChannel, getPalette, warmChannel, devMode, toggleMode
- **Doc:** `02-shell-design.md` (Section 12)

---

## Phase 3: Homelab Services

### 3.1 Radicale (CalDAV)
- [ ] NixOS service configuration for Radicale
- [ ] htpasswd auth, HTTPS via Caddy reverse proxy
- [ ] Calendar for personal scheduling
- [ ] DAVx5 on mobile for sync
- [ ] Git-versioned .ics backup
- **Doc:** `02-shell-design.md` (Calendar section)

### 3.2 Super Productivity
- [ ] Install (NixOS package or Flatpak)
- [ ] Connect to Radicale via CalDAV
- [ ] Configure Pomodoro/Flowtime timers
- [ ] Focus session integration: `qs ipc call garden focusStart/focusEnd`
- [ ] Lives as system:planner page
- **Doc:** `02-shell-design.md` (Focus Session Integration)

### 3.3 Existing Homelab Integration
- [ ] AdGuard Home on NixOS machine
- [ ] WireGuard + Tailscale remote access
- [ ] Caddy reverse proxy for services
- [ ] UniFi network (already configured)

---

## Phase 4: Research Workflow

### 4.1 Zotero Setup
- [ ] Zotero install + Better BibTeX plugin
- [ ] Citation key format: `authors(n=1,etal=EtAl)+year`
- [ ] Auto-export `references.bib` (WebDAV or local path)
- [ ] "My Writing" collection for self-authored work
- [ ] Browser connector for web sources
- **Doc:** `08-research-workflow.md` (Section 2)

### 4.2 Obsidian Setup
- [ ] Obsidian install + vault location
- [ ] Plugins: Zotero Desktop Connector, Citations, Dataview, Templater, Canvas
- [ ] Garden CSS snippet (from palette generator)
- [ ] Literature note template (Zotero import format)
- [ ] Permanent note template
- [ ] Project/paper outline template
- **Doc:** `08-research-workflow.md` (Section 3)

### 4.3 Typst Writing Environment
- [ ] Typst install (NixOS package)
- [ ] Garden Typst template (garden-paper.typ) — M PLUS 1p + IBM Plex Mono,
      Chicago citations, generous margins
- [ ] `typst watch` workflow with Zathura live preview
- [ ] Fish `writing-setup` function (spawns Kakoune + typst watch + Zathura)
- [ ] Garden launcher `write <filename>` command
- [ ] Kakoune fzf citation insertion (grep references.bib)
- [ ] Pandoc install + CSL styles (Chicago, APA, MLA)
- [ ] Pandoc markdown → PDF (via Typst), markdown → docx conversion
- [ ] CV template using `humanistically` Typst package
- [ ] Thesis/book template based on `classicthesis` adapted with Garden typography
- **Doc:** `08-research-workflow.md` (Section 5)

### 4.4 Document Viewing
- [ ] Zathura install + Garden theme (from palette generator)
- [ ] Calibre + Calibre-Web for ebook management
- [ ] Paperless-ngx for document archiving
- **Doc:** `08-research-workflow.md` (Section 7)

---

## Phase 5: Infrastructure — Rust Workspace

### 5.1 garden-core
- [ ] Cargo workspace setup (`garden-infra/`)
- [ ] Domain types: HostConfig, HostTier, ConnectionState, JobId, JobState
- [ ] GardenEvent enum (connection, job, agent, health events)
- [ ] Trait ports: StoragePort, RemoteExecutor, NotificationEmitter
- [ ] EventBus (pub/sub for all state changes)
- **Doc:** `04-infrastructure.md` (Sections 6-7)

### 5.2 garden-ssh
- [ ] SSH ControlMaster socket monitoring (inotify on ~/.ssh/sockets/)
- [ ] Health checker (periodic `ssh -O check`)
- [ ] RemoteExecutor implementation (exec via ControlMaster)
- [ ] SSH config parser
- **Doc:** `04-infrastructure.md` (Sections 3-4)

### 5.3 garden-daemon
- [ ] Systemd user service
- [ ] Unix socket IPC server (~/.local/run/garden/daemon.sock)
- [ ] ConnectionMonitor, HealthChecker, JobTracker
- [ ] SQLite storage (via StoragePort trait)
- [ ] Event streaming for `garden-ctl watch --json`
- **Doc:** `04-infrastructure.md` (Sections 2, 5)

### 5.4 garden-ctl
- [ ] CLI: status, jobs, submit, connect, disconnect, watch, health, agents, config
- [ ] `--json` output for machine consumption
- [ ] Fish shell completions
- **Doc:** `04-infrastructure.md` (Section 10)

### 5.5 garden-tui
- [ ] Ratatui 4-panel dashboard (connections, jobs, agents, event log)
- [ ] Garden palette theme for Ratatui
- [ ] Vim-style navigation (h/j/k/l, Enter, Tab, /)
- [ ] Connects to daemon via Unix socket
- **Doc:** `04-infrastructure.md` (Section 9)

### 5.6 garden-autoresearch (separate process)
- [ ] Experiment scheduler
- [ ] SLURM script generation (train.py template)
- [ ] Metrics collection
- [ ] Agent architecture (trainer, evaluator, sweeper, collector)
- [ ] Communicates with daemon via Unix socket API
- **Doc:** `04-infrastructure.md` (Section 8)

---

## Phase 6: Nyxt & Curation

### 6.1 Nyxt Theme
- [ ] garden-theme.lisp (from palette generator)
- [ ] M PLUS 1p + IBM Plex Mono fonts
- [ ] Prompt buffer styled like Garden launcher
- [ ] Live palette switching via runtime Lisp re-evaluation
- **Doc:** `05-nyxt-and-curation.md` (Section 2)

### 6.2 Curation Integration
- [ ] Quick save (Alt+S) — save URL/excerpt to Garden curation app
- [ ] Hint-save mode (Alt+Shift+S) — rapid link harvesting
- [ ] Reading mode — Garden typography + palette
- [ ] Attention boundaries: time awareness, feed reduction
- [ ] Garden sidebar panel
- [ ] `qs ipc call garden blockSaved` integration
- **Doc:** `05-nyxt-and-curation.md` (Sections 3-11)

### 6.3 Garden Curation App
- [ ] Existing Tauri/Rust app — continue development
- [ ] IPC for Nyxt integration (HTTP or Unix socket)
- [ ] Resolve naming conflict (Garden app vs Garden Shell vs garden-infra)
- **Doc:** `05-nyxt-and-curation.md`, `08-research-workflow.md` (Section 4)

---

## Phase 7: Polish & Refinement

### 7.1 Animation System
- [ ] Implement all shell animations per timing hierarchy
- [ ] Page cycling: 120ms underline slide
- [ ] Channel switching: 200ms staggered tab entrance
- [ ] Launcher/switcher: 150ms panel slide
- [ ] Notifications: 200ms slide-in, vertical-compress dismiss
- [ ] Desktop clock: 200ms staggered digits (40ms/char)
- [ ] Palette switch: instant (hard cut, no animation)
- [ ] Reduced motion accessibility option
- **Doc:** `03-palette-and-theming.md` (Section 5)

### 7.2 Multi-Monitor
- [ ] Per-monitor bar instances (Quickshell Variants per screen)
- [ ] Shared channel topology, soft default-monitor affinity
- [ ] Niri per-monitor workspace strips
- **Doc:** `02-shell-design.md` (Multi-Monitor section)

### 7.3 App Theming — Remaining Targets
- [ ] Blender XML theme
- [ ] Godot editor theme
- [ ] GTK 3/4 theme
- [ ] Qt via Kvantum
- [ ] Aseprite (limited — Tier 3)
- [ ] Clip Studio Paint (containment — Tier 4, border tinting only)
- **Doc:** `03-palette-and-theming.md` (Section 6)

---

## Design Docs Maintenance

### Pending Doc Updates
- [ ] Finish Hyprland → Niri reference updates across all docs
      (grep for "Hyprland|hyprland|hyprctl" in 03, 04, 05, 06)
- [ ] Add Garden Typst template to `08-research-workflow.md`
- [ ] Add Niri decision to `06-open-questions.md` decision log
- [ ] Resolve naming conflict (Garden app vs Garden Shell)
- **Doc:** `07-niri-migration.md` (Documents Requiring Updates)

### Open Questions Remaining
- Attention & Curation: 6 questions (defer until building Nyxt integration)
- Nyxt Integration: 5 questions (defer until building Nyxt config)
- Infrastructure/Rust: 10 questions (resolve during implementation)
- Animation: 3 minor questions
- Research Workflow: 6 questions
- **Doc:** `06-open-questions.md`

---

## Suggested Build Order

**Week 0: Dendritic migration (do this first)**
Pre-Phase: Merge PR #15 on fern repo, add garden host,
migrate fern-shell to dendritic pattern

**Week 1-2: Live in the terminal immediately**
Phase 0 (NixOS + Niri + terminal stack + toolkit + fonts)
Phase 1.1 (palettes.json)
Phase 1.2 (theme generator — at least Kitty, Fish, Kakoune, bat, delta, fzf)

**Week 3-4: Basic shell**
Phase 2.1 (shell skeleton + NiriAdapter)
Phase 2.2 (bar — channel name, column indicators, clock)
Phase 2.4 (launcher — apps + channels)

**Week 5-6: Shell features**
Phase 2.3 (host awareness)
Phase 2.5 (channel switcher)
Phase 2.6 (notifications)
Phase 2.7 (scratchpads, OSD, lock screen, desktop clock)

**Week 7-8: Research workflow**
Phase 4.1-4.3 (Zotero + Obsidian + Typst writing environment)
Phase 3.1-3.2 (Radicale + Super Productivity)

**Week 9-10: Settings + polish**
Phase 2.8 (settings panel — palette editor, keybind remapper)
Phase 2.9 (extension architecture — IPC handlers)
Phase 7.1 (animations)

**Ongoing: Infrastructure**
Phase 5 (garden-infra Rust workspace — build incrementally as needed)
Phase 6 (Nyxt + curation — build when ready)

---

## Documentation Set

```
garden-design-docs/
├── 00-overview.md             — index + agent guide
├── 01-design-philosophy.md    — artistic references, principles
├── 02-shell-design.md         — all shell components + terminal stack
├── 03-palette-and-theming.md  — palettes, animation, theming pipeline
├── 04-infrastructure.md       — Rust daemon, SSH, autoresearch
├── 05-nyxt-and-curation.md    — browser + curation system
├── 06-open-questions.md       — remaining questions + decision log
├── 07-niri-migration.md       — Niri config, bar opportunities, layout
├── 08-research-workflow.md    — Zotero, Obsidian, Typst, citations
└── 09-build-plan.md           — this file
```

**Repositories:**
- `adanoelle/fern` — NixOS config (dendritic, multi-host)
  Open PR #15 for dendritic migration
- `adanoelle/fern-shell` — Quickshell / Garden Shell (dendritic, independent build)
  Needs dendritic migration + compositor/terminal stack updates

Mockup artifacts:
- garden-palette-editor.jsx — palette editor reference (updated with ✧ prompt, Kakoune, Niri)
- garden-shell-mockup.jsx, garden-shell-expanded.jsx, garden-shell-channels.jsx,
  garden-shell-hosts.jsx, garden-shell-settings.jsx — earlier shell mockups
- garden-palette-explorer.jsx — palette direction exploration

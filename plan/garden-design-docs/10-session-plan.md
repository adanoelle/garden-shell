# Garden — Claude Code Session Plan

> Scoped work units for Claude Code agents. Each session has clear
> context (which design docs to read), inputs (what exists), and
> deliverables (what to produce). Sessions are ordered by dependency.

**Created:** 2026-03-31

---

## How to Use This Document

Before starting a Claude Code session:
1. Read the session description below
2. Copy the "Context for agent" block into your CLAUDE.md or session prompt
3. Point the agent at the relevant repo
4. The agent reads the listed design docs and executes the tasks

Sessions are grouped into tracks that can run in parallel where noted.

---

## Track A: NixOS Configuration (adanoelle/fern)

### Session A1: Dendritic Migration

**Goal:** Convert fern from numbered flake-parts files to the
dendritic pattern using import-tree.

**Context for agent:**
```
Read PR #15 on this repo for the migration plan.
Read about the dendritic pattern: every .nix file under modules/ is a
self-contained flake-parts module. import-tree (vic/import-tree)
auto-discovers all modules. Files prefixed with _ are excluded.
flake.nix should simplify to:
  outputs = inputs:
    inputs.flake-parts.lib.mkFlake { inherit inputs; }
    (inputs.import-tree ./modules);
Convert each flake.parts/*.nix into a standalone module under modules/.
Move hardware configs to _hardware/ (excluded from import-tree).
Do NOT change any functionality — this is a pure structural refactor.
Test with: nix flake check
```

**Inputs:** Existing fern repo, PR #15
**Deliverables:**
- [ ] `import-tree` added to flake inputs
- [ ] `flake.nix` simplified to use `import-tree ./modules`
- [ ] All `flake.parts/*.nix` converted to `modules/*.nix`
- [ ] `_hardware/` for generated hardware configs
- [ ] `nix flake check` passes
- [ ] Updated CLAUDE.md reflecting new structure

**Estimated scope:** Medium (1-2 hours)

---

### Session A2: Garden Host Configuration

**Goal:** Add the MS-A2 as a new host called `garden` alongside
the existing `fern` host.

**Context for agent:**
```
This is a Minisforum MS-A2 with Ryzen 9 9955HX, AMD integrated
graphics (no NVIDIA). The host is called "garden". It needs:
- Its own hardware-configuration.nix (in _hardware/garden.nix)
- A host module that defines nixosConfigurations.garden
- AMD GPU support (amdgpu driver, no NVIDIA modules)
- The existing fern host must continue to work unchanged
Reference the dendritic pattern: the host module is just another
flake-parts module under modules/.
```

**Inputs:** Session A1 completed (dendritic structure)
**Deliverables:**
- [ ] `_hardware/garden.nix` (hardware config for MS-A2)
- [ ] `modules/host-garden.nix` (host definition)
- [ ] `fern` host still builds: `nix build .#nixosConfigurations.fern.config.system.build.toplevel`
- [ ] `garden` host builds: `nix build .#nixosConfigurations.garden.config.system.build.toplevel`

**Estimated scope:** Small (30-60 min)
**Note:** Hardware config needs to be generated on the actual machine
with `nixos-generate-config`. Agent can create the host module with
a placeholder that gets filled in during install.

---

### Session A3: Niri + Compositor Module

**Goal:** Add Niri compositor support for the garden host.

**Context for agent:**
```
Read garden-design-docs/07-niri-migration.md for the full Niri spec.
Add niri-flake (github:sodiboo/niri-flake) as a flake input.
Create a dendritic module that:
- Enables Niri on the garden host
- Configures five named workspaces: studio, research, writing, music, system
- Sets up keybinds per the design doc
- Configures layout: 2px gaps, 1px borders, no rounded corners
- Sets up window rules for column widths per app
- Configures floating rules for scratchpads
- Sets up animations (overdamped springs, 150-200ms)
- Enables xwayland-satellite for X11 apps
The fern host should NOT be affected (it keeps Hyprland).
```

**Inputs:** Session A2 completed, `07-niri-migration.md`
**Deliverables:**
- [ ] `niri` added to flake inputs with `follows = "nixpkgs"`
- [ ] `modules/niri.nix` — compositor config for garden host
- [ ] Full `config.kdl` generated or templated
- [ ] Keybinds, window rules, animations per design doc

**Estimated scope:** Medium (1-2 hours)

---

### Session A4: Terminal Stack Modules

**Goal:** Add Kitty, Fish, and Kakoune as dendritic modules for
the garden host.

**Context for agent:**
```
Read garden-design-docs/02-shell-design.md Section 13 (Terminal Stack)
for the full spec.

Terminal emulator: Kitty (not Ghostty)
- Config from Section 13: Garden palette colors, IBM Plex Mono 13pt,
  hide_window_decorations, beam cursor, padding 12x16
- Kitty image protocol for yazi/chafa

Shell: Fish (not Nushell)
- ✧ (U+2727) prompt character
- Two-line prompt: info above, input below
- Color states: text-1 normal, urgent on error, accent in nix shell
- Garden channel integration via $GARDEN_CHANNEL (niri msg)
- Channel-specific abbreviations
- Long-command notification (>10s)

Editor: Kakoune primary, Helix backup
- Garden colorscheme (garden.kak) from Section 13
- kak-lsp for LSP support
- tree-sitter integration

All configs should use the mokume palette colors initially (we'll
generate from palettes.json later).
```

**Inputs:** Session A2 completed, `02-shell-design.md`
**Deliverables:**
- [ ] `modules/kitty.nix` — terminal config + palette
- [ ] `modules/fish.nix` — shell config, ✧ prompt, channel detection
- [ ] `modules/kakoune.nix` — editor config, garden.kak colorscheme
- [ ] `modules/helix.nix` — backup editor (minimal config)
- [ ] All modules apply only to garden host (or shared if appropriate)

**Estimated scope:** Medium-Large (2-3 hours)

---

### Session A5: Terminal Toolkit Module

**Goal:** Add the complete terminal toolkit as a dendritic module.

**Context for agent:**
```
Read garden-design-docs/02-shell-design.md Section 14 (Terminal Toolkit).
Install and configure:
Essential: ripgrep, fd, bat, delta, zoxide, jq, yazi
Recommended: lazygit, btop, fzf, glow, xh, jless, chafa

Fish integration:
- yazi cd-on-exit wrapper
- bat as MANPAGER
- fzf/skim with Garden palette colors (FZF_DEFAULT_OPTS)
- delta as GIT_PAGER
- zoxide init

Use mokume palette colors for fzf, bat theme name "garden".
Actual theme files (bat .tmTheme, lazygit .yml, etc.) will be
generated by the palette generator later — for now just reference
the theme names and set up the tool configs.
```

**Inputs:** Session A4 completed, `02-shell-design.md`
**Deliverables:**
- [ ] `modules/toolkit.nix` — all tools installed + configured
- [ ] Fish integration conf files
- [ ] Git config with delta as pager

**Estimated scope:** Medium (1-2 hours)

---

### Session A6: Fonts + Research Tools Modules

**Goal:** Add fonts and the research workflow tools.

**Context for agent:**
```
Read garden-design-docs/08-research-workflow.md.

Fonts: M PLUS 1p (UI/prose), IBM Plex Mono (terminal/code)
Configure fontconfig.

Research tools (as individual dendritic modules):
- Zotero (with Better BibTeX — may need overlay or manual plugin)
- Obsidian
- Typst + Pandoc + CSL styles (chicago-fullnote-bibliography)
- Zathura (PDF viewer, will get Garden theme later)
- Calibre (ebook management)

Also add:
- Super Productivity (task management)
- Radicale (CalDAV server — NixOS service module)
```

**Inputs:** `08-research-workflow.md`
**Deliverables:**
- [ ] `modules/fonts.nix` — M PLUS 1p, IBM Plex Mono, fontconfig
- [ ] `modules/zotero.nix` — Zotero + Better BibTeX
- [ ] `modules/obsidian.nix` — Obsidian with vault config
- [ ] `modules/typst.nix` — Typst, Pandoc, CSL styles
- [ ] `modules/zathura.nix` — PDF viewer
- [ ] `modules/radicale.nix` — CalDAV server
- [ ] `modules/super-productivity.nix` — task management

**Estimated scope:** Medium (1-2 hours)

---

## Track B: Garden Shell (adanoelle/fern-shell)

### Session B1: Dendritic Migration of fern-shell

**Goal:** Convert fern-shell to dendritic pattern, preserving
existing functionality.

**Context for agent:**
```
This repo has QML sources in fern/, Rust crates in crates/,
and flake-parts modules in flake-parts/.
Migrate to dendritic pattern:
- Add import-tree to flake inputs
- Simplify flake.nix to use import-tree ./modules
- Convert flake-parts/*.nix to modules/*.nix
- QML sources stay where they are — prefix with _ or keep in
  a path that import-tree won't interpret as modules
- Rust crates stay in crates/
- Do NOT change any functionality, pure structural refactor
- Rename exports from fern-shell to garden-shell:
  homeModules.garden-shell, nixosModules.garden-shell
```

**Inputs:** Existing fern-shell repo
**Deliverables:**
- [ ] Dendritic structure with import-tree
- [ ] Renamed module exports
- [ ] `nix flake check` passes
- [ ] QML sources accessible but not auto-imported as modules

**Estimated scope:** Medium (1-2 hours)

---

### Session B2: Compositor Abstraction + NiriAdapter

**Goal:** Replace Hyprland-specific QML with compositor abstraction
layer targeting Niri.

**Context for agent:**
```
Read garden-design-docs/07-niri-migration.md (Quickshell Service
Changes section) and 02-shell-design.md (Section 12: Extension
Architecture, Section 13: Quickshell File Structure).

Create:
- CompositorService.qml — abstract interface for workspace/window queries
- NiriAdapter.qml — connects to $NIRI_SOCKET, event stream, exposes:
  - activeWorkspace (string)
  - columns (list with id, title, appId, focused, visible)
  - workspaces (list with name, columnCount, active)
- ScratchpadService.qml — floating window toggle via niri msg

Remove or replace:
- Any HyprlandService.qml or hyprctl calls
- Update all compositor IPC to use niri msg

Reference: iNiR's NiriService.qml and Noctalia's CompositorService
for proven patterns.
```

**Inputs:** Session B1 completed, `07-niri-migration.md`, `02-shell-design.md`
**Deliverables:**
- [ ] `CompositorService.qml` — abstract interface
- [ ] `NiriAdapter.qml` — Niri event stream consumer
- [ ] `ScratchpadService.qml` — floating window management
- [ ] All Hyprland references removed from QML

**Estimated scope:** Large (3-4 hours)

---

### Session B3: Palette System + Theme Singleton

**Goal:** Implement the palette system in QML — reading palettes.json
and exposing colors as reactive properties.

**Context for agent:**
```
Read garden-design-docs/03-palette-and-theming.md for palette spec.

Create:
- Theme.qml singleton that reads ~/.config/garden/palettes.json
- Exposes all 13 semantic roles as color properties
- Active palette switching (hard cut, no animation)
- Four built-in palettes: mokume, sumi, kinu, yoru
- Custom palette support

Also create the palettes.json file itself with all four built-in
palette definitions.

The Theme singleton is consumed by every other QML component via
property bindings — when Theme.base changes, everything updates.
```

**Inputs:** `03-palette-and-theming.md`
**Deliverables:**
- [ ] `palettes.json` with four built-in palettes
- [ ] `Theme.qml` singleton with 13 color properties
- [ ] Palette switching via property assignment (hard cut)
- [ ] IpcHandler for `qs ipc call garden switchPalette`

**Estimated scope:** Medium (1-2 hours)

---

### Session B4: Bar Component

**Goal:** Build the Garden Shell bar — the most visible component.

**Context for agent:**
```
Read garden-design-docs/02-shell-design.md Section 2 (Bar Design)
and 07-niri-migration.md (Bar Design Opportunities section).

Build:
- Bar.qml as PanelWindow anchored top
- Three density modes (full 34px, standard 30px, minimal 2px)
- Active channel name + column indicators from NiriAdapter
- Column order matches strip spatial order (Option H)
- Try visible/off-screen distinction (Option C)
- Inactive channel dots
- Clock (IBM Plex Mono)
- Mode system: per-channel mode stacks

The bar consumes NiriAdapter.activeWorkspace, NiriAdapter.columns,
NiriAdapter.workspaces for all its data. It should snap focus
discretely with ~100ms debounce.

Use Theme.qml for all colors — no hardcoded hex values.
```

**Inputs:** Sessions B2 + B3 completed, `02-shell-design.md`, `07-niri-migration.md`
**Deliverables:**
- [ ] `Bar.qml` — main bar container
- [ ] `BarChannel.qml` — channel tab with column indicators
- [ ] `BarDot.qml` — inactive channel dot
- [ ] `BarClock.qml` — time display
- [ ] `ModeService.qml` — per-channel mode management
- [ ] Three density modes working

**Estimated scope:** Large (3-4 hours)

---

### Session B5: Launcher + Channel Switcher

**Goal:** Build the universal launcher and channel switcher overlays.

**Context for agent:**
```
Read garden-design-docs/02-shell-design.md Sections 3-4 and
Section 12 (launcher disambiguation, slow sources).

Launcher (Super+/):
- FloatingWindow with DitherOverlay backdrop
- / prefix, flat result list with source labels
- Sources: AppSource (desktop entries), ChannelSource (workspaces),
  CommandSource (shell commands), CalcSource (inline calc)
- Running pages ranked first in disambiguation
- "write <filename>" command integration

Channel Switcher (Super+Tab):
- Same dithered backdrop
- All channels with column names + truncated window titles
- Arrow keys navigate, Enter switches, Escape closes

DitherOverlay.qml:
- PC-98 dithered backdrop (dense 2x2 pattern)
- image-rendering: pixelated
- Used by launcher, switcher, scratchpads, settings
```

**Inputs:** Sessions B2-B4 completed, `02-shell-design.md`
**Deliverables:**
- [ ] `Launcher.qml` + launcher sources
- [ ] `ChannelSwitcher.qml`
- [ ] `DitherOverlay.qml`
- [ ] IPC handlers for keyboard triggers

**Estimated scope:** Large (3-4 hours)

---

### Session B6: Notifications + Remaining Shell Components

**Goal:** Build notifications, OSD, lock screen, desktop clock,
and remaining utilities.

**Context for agent:**
```
Read garden-design-docs/02-shell-design.md Sections 6-10.

Build in priority order:
1. NotificationService.qml — D-Bus notification server
2. Notifications.qml — slide from right, progress line, compress dismiss
3. OSD.qml — volume/brightness thin bar
4. DesktopClock.qml — always-visible, low opacity, staggered digits
5. LockScreen.qml — dithered texture, typographic clock
6. PowerMenu.qml — horizontal text options

All components use Theme.qml for colors and DitherOverlay for backdrops.
Notifications: global toggle via IPC, auto-suppress during focus sessions.
Desktop clock: always visible behind windows, 80px IBM Plex Mono.
```

**Inputs:** Sessions B2-B4 completed, `02-shell-design.md`
**Deliverables:**
- [ ] All listed QML components
- [ ] Notification D-Bus integration
- [ ] IPC handlers for notification toggle

**Estimated scope:** Large (4-5 hours)

---

### Session B7: Settings Panel

**Goal:** Build the palette editor and keybind remapper.

**Context for agent:**
```
Read garden-design-docs/02-shell-design.md Section 11.
Reference garden-palette-editor.jsx as the visual specification —
it shows the exact layout, component structure, and interactions.

Palette editor:
- Mode selector tabs (mokume/sumi/kinu/yoru + custom)
- 13 hex inputs grouped by role
- Live preview (mini bar, terminal, code, notification, launcher)
- "Regenerate 17 themes" button
- Custom palette creation (fork → name → icon)

Keybind remapper:
- Flat list by category
- Layer badges (niri/quickshell)
- Click-to-capture key combo
- Conflict detection

Settings is a FloatingWindow with dithered backdrop (Super+,).
```

**Inputs:** Sessions B3-B5 completed, `02-shell-design.md`,
`garden-palette-editor.jsx`
**Deliverables:**
- [ ] `SettingsPanel.qml` — tabbed container
- [ ] `PaletteEditor.qml` — 13-role hex editor with live preview
- [ ] `KeybindEditor.qml` — flat list with capture

**Estimated scope:** Large (4-5 hours)

---

## Track C: Palette Generator (can run parallel to A and B)

### Session C1: Theme Generator Script

**Goal:** Build the tool that reads palettes.json and produces
all 17 theme output files.

**Context for agent:**
```
Read garden-design-docs/03-palette-and-theming.md Section 6
(Generator Pipeline).

Input: ~/.config/garden/palettes.json
Outputs (17 files):
  kitty/kitty.conf, fish/garden-theme.fish, fish/fish_prompt.fish,
  fish/garden-tools.fish, kak/garden.kak, bat/garden.tmTheme,
  lazygit/garden.yml, btop/garden.theme, yazi/garden.toml,
  obsidian/garden.css, zathura/gardenrc, garden-theme.lisp,
  blender/garden.xml, gtk-3.0/gtk.css, kvantum/garden.kvconfig,
  garden-tui (Ratatui), niri border colors

The generator should:
- Read the active palette from palettes.json
- Produce each output file from a template
- Be callable as: garden-themes regenerate
- Derive 4 ANSI complement colors algorithmically from palette hue

Write this in Rust (consistent with garden-infra) or as a standalone
Nix derivation. Either works — Rust is preferred for the garden-ctl
integration later.
```

**Inputs:** `03-palette-and-theming.md`, `palettes.json` from B3
**Deliverables:**
- [ ] Generator tool (Rust binary or script)
- [ ] Template files for all 17 outputs
- [ ] Working generation from mokume palette
- [ ] Verified output matches the specs in design docs

**Estimated scope:** Large (4-5 hours)

---

## Track D: Research Workflow (can run after A4-A6)

### Session D1: Writing Environment Integration

**Goal:** Set up the Typst writing workflow with Fish functions
and launcher integration.

**Context for agent:**
```
Read garden-design-docs/08-research-workflow.md Section 5.

Create:
- Garden Typst template (garden-paper.typ): M PLUS 1p body,
  IBM Plex Mono code, Chicago citations, generous margins
- Fish writing-setup function (spawns Kakoune + typst watch + Zathura)
- Fish cite function (fzf citation search against references.bib)
- Niri window rules for writing layout (50/50 split)
- Example paper project structure

Also configure:
- Zotero Better BibTeX citation key format
- Obsidian Zotero Desktop Connector template
- Pandoc output commands (PDF via Typst, docx for advisors)
```

**Inputs:** Sessions A4-A6 completed, `08-research-workflow.md`
**Deliverables:**
- [ ] `garden-paper.typ` template
- [ ] Fish functions: `writing-setup`, `cite`
- [ ] Pandoc wrapper functions
- [ ] Example paper project with correct structure

**Estimated scope:** Medium (2-3 hours)

---

## Session Dependencies

```
A1 (dendritic migration)
 ├── A2 (garden host)
 │    ├── A3 (niri)
 │    ├── A4 (terminal stack)
 │    │    └── A5 (toolkit)
 │    └── A6 (fonts + research tools)
 │         └── D1 (writing environment)
 │
B1 (fern-shell dendritic)
 ├── B2 (compositor abstraction)
 │    ├── B4 (bar)
 │    │    └── B5 (launcher + switcher)
 │    └── B6 (notifications + utilities)
 ├── B3 (palette system)
 │    ├── B4 (bar — needs Theme.qml)
 │    └── B7 (settings panel)
 │
C1 (theme generator) — parallel, needs palettes.json from B3
```

**Parallel tracks:**
- Track A and Track B can run simultaneously after A1 and B1
- Track C can start once palettes.json exists (after B3)
- Track D needs Track A completed (tools installed)

**Critical path:** A1 → A2 → A3 + A4 → use the system daily
while building Track B in parallel.

---

## Session Tips

- Each session should start by reading the listed design docs
- Test incrementally: `nix flake check` after every module change
- For QML work: `qs -p path/to/shell.qml` for live reload
- Commit working states frequently — atomic commits per component
- If a session is too large, split at the deliverable boundaries
- The garden-palette-editor.jsx mockup is the visual reference for
  all Garden Shell aesthetics — fonts, spacing, colors, density

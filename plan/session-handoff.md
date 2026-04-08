# Session Handoff — Garden Desktop on Fern

**Date:** 2026-04-06 **Branch:** `feat/niri` **Commits:**

- `f2905aa` — feat(desktop): add garden terminal stack (Niri + Kitty + Fish +
  Kakoune)
- `31606b9` — docs: add garden design docs and shell mockups
- _(uncommitted)_ — fix: wire niri HM config to user ada + fix niri-flake schema
  issues

---

## Current State

**Build passes** — `nixos-rebuild build --flake .#fern` succeeds. Changes are
**not yet committed** and **not yet switched**. You need to:

1. `sudo nixos-rebuild test --flake .#fern` (or `just test`)
2. Log out of current session
3. Select Niri from greetd
4. Test keybindings (see table below)
5. If good: `sudo nixos-rebuild switch --flake .#fern` (or `just switch`)
6. Commit the changes

### Uncommitted changes (3 files)

- **`modules/desktop/bundle.nix`** — Added `den.aspects.niri` to `desktop-apps`
  includes (the root fix — wires niri's homeManager config to user ada)
- **`modules/desktop/niri.nix`** — Fixed 5 schema mismatches with niri-flake HM
  module (see "What Was Fixed This Session" below)
- **`modules/host-fern.nix`** — Moved `programs.niri.package = pkgs.niri` here
  (avoids duplicate unique-option when den applies the aspect from both host and
  user paths)

---

## What Was Done (Phase 0)

All four sessions from the Phase 0 build plan were implemented in a single pass
and the NixOS rebuild succeeded (`nixos-rebuild test` passed, `switch` in
progress).

### Session 1: Niri Compositor

- **`modules/desktop/niri.nix`** — Full Niri aspect with:
  - 5 named workspaces: studio, research, writing, music, system
  - Keybinds: Super+1-5 (channels), Super+H/L/J/K (navigation), Super+N (spawn
    kitty), Super+Shift+Q (close), Super+F (maximize), Super+A (overview),
    Super+R (cycle widths)
  - Layout: 2px gaps, 1px borders (mokume `#4a5568`/`#3a4456`),
    `center-focused-column "on-overflow"`, no rounded corners
  - Overdamped spring animations (damping-ratio=1.0), 150-200ms
  - Window rules: column width presets (kitty 40%, nyxt 70%, obsidian 60%,
    creative 100%), floating scratchpads, host tier border colors
  - Startup: kitty→research, btop→system, xwayland-satellite
- **`modules/host-fern.nix`** — Added niri aspect + niri-flake NixOS module
  import + greetd dual-session (Niri + Hyprland via tuigreet `--sessions`)
- **`flake.nix`** — Added `niri` input (sodiboo/niri-flake)

### Session 2: Terminal Stack

- **`modules/cli/kitty.nix`** — IBM Plex Mono 13pt, mokume ANSI 16 colors, no
  decorations, beam cursor, 120% cell height, Kitty image protocol
- **`modules/shells/fish.nix`** — Two-line prompt with `✧` (U+2727), color
  states (text-1 normal, urgent on error, accent in nix-shell, ok in venv),
  vi-mode, `GARDEN_CHANNEL` detection via `niri msg`, long-command notification
  (>10s), git abbreviations, yazi `y` wrapper
- **`modules/cli/kakoune.nix`** — Full `garden.kak` colorscheme (mokume),
  kak-lsp for Nix/Rust/Python/TypeScript, clipboard via wl-clipboard, relative
  line numbers, soft wrap

### Session 3: Terminal Toolkit

- **`modules/cli/yazi.nix`** — File manager with Fish integration
- **`modules/cli/lazygit.nix`** — Mokume theme overlay (uses `mkForce` over
  git/tools.nix base config)
- **`modules/cli/btop.nix`** — System monitor, vim keys
- **`modules/cli/fzf.nix`** — Fuzzy finder with mokume colors, Fish integration
  (Ctrl+R/Ctrl+T/Alt+C)
- **`modules/cli/fd.nix`**, **`ripgrep.nix`**, **`jq.nix`** — Simple package
  aspects

### Session 4: Fonts

- **`modules/fonts.nix`** — Added M PLUS 1p (sans/serif default) + IBM Plex Mono
  (monospace default), kept Nerd Fonts as icon fallbacks

### Bundle Updates

- `modules/cli/bundle.nix` — Added kitty, kakoune, yazi, lazygit, btop, fzf, fd,
  ripgrep, jq
- `modules/shells/bundle.nix` — Added fish
- `modules/shells/zoxide.nix` — Added `enableFishIntegration = true`

---

## Key Decision: niri Package

The niri-flake's own packages (`niri-stable`, `niri-unstable`) both fail to
build from source due to a `fetchGit` evaluation-time issue with the Smithay
dependency (the pinned git revision isn't findable on the `master` ref, and SSH
isn't available to the nix daemon).

**Current fix:** `programs.niri.package = pkgs.niri;` — uses the nixpkgs package
(niri 25.05.1). The niri-flake NixOS/HM module still provides the
`programs.niri.settings` configuration system for generating `config.kdl`.

**To revisit:** When niri-flake fixes the Smithay fetch (likely needs
`allRefs = true`), switch back to get a newer version:

```nix
programs.niri.package = inputs.niri.packages.${pkgs.system}.niri-stable;
```

---

## What Was Fixed This Session

The niri aspect's `homeManager` config was never reaching user ada because the
`niri` aspect wasn't in ada's include chain (`ada` → `desktop-apps` →
`[hyprland, chromium, ...]`). Adding it to the `desktop-apps` bundle exposed 5
schema mismatches with the niri-flake HM module:

1. **Animations** — niri-flake uses `attrTag` (`spring`/`easing` variants);
   wrapped in `kind.spring`/`kind.easing` blocks
2. **Keybind actions** — `kdl-leaf` type requires `{ action-name = []; }`, not
   plain strings like `"close-window"`
3. **Window-rule borders** — decoration type uses `border.active.color`, not
   `border.active-color`
4. **Layout** — `center-focused-column` enum is `never`/`always`/`on-overflow`,
   not `best-effort`
5. **Regex** — niri's regex engine doesn't support look-ahead (`(?!btop)`);
   reordered rules so btop-specific rule overrides generic kitty rule

Also moved `programs.niri.package = pkgs.niri` from the aspect to
`host-fern.nix` because den applies the aspect's nixos section twice (from host
and user paths) and the package option is unique-typed.

---

## What Needs Testing (Next Session)

1. **`sudo nixos-rebuild test --flake .#fern`** — apply the config
2. **Log out and select Niri from greetd** — verify session picker shows both
   Niri and Hyprland
3. **Check `~/.config/niri/config.kdl`** — should be a symlink to nix store (not
   a regular file with default config)
4. **Niri launches** — 5 named workspaces visible
5. **Keybinds** (critical test):

   | Key                   | Expected                                       |
   | --------------------- | ---------------------------------------------- |
   | Super+1-5             | Switch to studio/research/writing/music/system |
   | Super+Shift+1-5       | Move window to that channel                    |
   | Super+H / Super+L     | Focus column left/right                        |
   | Super+J / Super+K     | Focus window down/up                           |
   | Super+Shift+H/L       | Move column left/right                         |
   | Super+Shift+J/K       | Move window down/up                            |
   | Super+N               | Spawn kitty                                    |
   | Super+Shift+Q         | Close window                                   |
   | Super+F               | Maximize column                                |
   | Super+A               | Toggle overview                                |
   | Super+R               | Cycle preset widths (40%/60%/100%)             |
   | Super+V               | Toggle floating                                |
   | Super+Tab / Shift+Tab | Next/prev workspace                            |
   | Super+[ / ]           | Consume/expel window                           |
   | Print                 | Screenshot                                     |
   | Super+Shift+E         | Quit session                                   |
   | Super+Shift+/         | Show hotkey overlay                            |

6. **Visual checks** — 2px gaps, 1px borders in mokume colors, no focus ring
7. **Startup rules** — kitty opens on research, btop on system
8. **Kitty** — mokume colors, IBM Plex Mono font, no window decorations
9. **Fish** — `✧` prompt, vi-mode, abbreviations
10. **Hyprland fallback** — logging in with Hyprland still works

---

## Known Issues / Rough Edges to Watch For

- **niri 25.05.1 vs design docs** — Design docs reference features that may be
  newer than 25.05.1 (tabbed columns, some animation options). Check
  `niri --version` and test what works.
- **Fish is not the login shell** — `modules/users.nix` still sets
  `shell = pkgs.nushell`. Fish is available but not default. Change if desired.
- **Kakoune not default editor** — Helix is still `defaultEditor = true` in
  `modules/cli/helix.nix`. Both coexist.
- **TERMINFO_DIRS** — Uses `mkForce` to combine kitty + ghostty paths. If
  ghostty is removed later, simplify this.
- **btop theme** — Uses `Default` theme, not a custom mokume theme. The design
  docs specify a generated garden theme — deferred to theme generator work.
- **bat theme** — Still references catppuccin-adjacent defaults. A
  `garden.tmTheme` is deferred to the theme generator.
- **xwayland-satellite** — Spawns at startup. Test Clip Studio Paint / X11 apps.
- **Startup window rules** — `at-startup` + `app-id` matching for kitty→research
  and btop→system may need tuning based on actual window titles.
- **den double-application** — den applies the niri aspect's nixos section twice
  (from host-fern and desktop-apps). Mergeable options (lists, bools) are fine,
  but unique options like `package` must live in the host config. Keep this in
  mind when adding unique options to aspects included from both paths.
- **Future: separate niri+quickshell repo** — The niri config will eventually
  move to a standalone repo with the full quickshell configuration.

---

## What's NOT Done (Deferred per Plan)

- Quickshell bar, launcher, notifications (→ fern-shell repo)
- Palette system / palettes.json / Theme.qml (→ fern-shell repo)
- Theme generator (17 output targets) (→ fern-shell repo)
- CompositorService / NiriAdapter / ScratchpadService (→ fern-shell repo)
- Garden-specific shell integration (mode system, IPC handlers)
- Actual generated theme files (garden.kak, garden.tmTheme, etc.) — using
  hardcoded mokume colors for now

---

## File Reference

```
modules/desktop/niri.nix     — Niri compositor aspect (HM settings + nixos enable)
modules/desktop/bundle.nix   — Desktop bundle (wires niri to user ada)
modules/host-fern.nix        — Host config (niri package + greetd dual-session)
modules/cli/kitty.nix        — Kitty terminal
modules/shells/fish.nix      — Fish shell + ✧ prompt
modules/cli/kakoune.nix      — Kakoune editor + garden.kak
modules/cli/yazi.nix         — File manager
modules/cli/lazygit.nix      — Git TUI theme
modules/cli/btop.nix         — System monitor
modules/cli/fzf.nix          — Fuzzy finder
modules/cli/fd.nix           — Find replacement
modules/cli/ripgrep.nix      — Grep replacement
modules/cli/jq.nix           — JSON processor
modules/fonts.nix            — M PLUS 1p + IBM Plex Mono
modules/cli/bundle.nix       — CLI bundle (+9 tools)
modules/shells/bundle.nix    — Shells bundle (+fish)
modules/shells/zoxide.nix    — +Fish integration
```

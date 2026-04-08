# Garden — Design Documentation Index

> A unified desktop environment, infrastructure layer, and curation system
> for creative research computing on NixOS + Niri.

**Last updated:** 2026-03-27

---

## Document Map

```
garden-design-docs/
│
├── 00-overview.md              ← you are here
│   Project vision, document map, shared principles
│
├── 01-design-philosophy.md
│   Design lineage, artistic references, what-not-to-do
│   Read this first — it frames every other decision
│
├── 02-shell-design.md
│   Quickshell/QML desktop shell: bar, launcher, overlays,
│   notifications, lock screen, settings panel, utilities
│   → feeds: quickshell repo
│
├── 03-palette-and-theming.md
│   Color system, four palettes, custom palettes, typography,
│   animation system, app theming strategy, generator pipeline
│   → feeds: quickshell repo + infrastructure repo (TUI theming)
│
├── 04-infrastructure.md
│   Rust daemon, SSH management, connection monitoring,
│   autoresearch architecture, Ratatui control plane, CLI
│   → feeds: garden-infra workspace
│
├── 05-nyxt-and-curation.md
│   Nyxt browser integration, Garden curation system,
│   attention boundaries, reading mode, foraging workflow
│   → feeds: nyxt config + garden app
│
├── 06-open-questions.md
│   All unresolved questions, organized thematically
│   Updated as decisions are made across all docs
│
├── 07-niri-migration.md
│   Niri compositor integration, workspace config, window rules,
│   bar design opportunities, layout spec, animation config
│   → feeds: niri config + quickshell repo
│
└── 08-research-workflow.md
    Zotero + Obsidian + Kakoune + Typst scholarly pipeline,
    citation workflow, writing environment, self-authored work
    → feeds: dotfiles + writing repos
```

---

## Repositories

This documentation feeds three codebases:

**garden-shell** (Quickshell/QML)
- Desktop shell for **Niri** compositor (Hyprland fallback via abstraction layer)
- Bar, launcher, overlays, settings
- Terminal stack: Kitty + Fish (✧ prompt) + Kakoune
- Reads from: `palettes.json`, `settings.json`
- Queries: `garden-daemon` via `garden-ctl watch --json`
- Docs: `02-shell-design.md`, `03-palette-and-theming.md`

**garden-infra** (Rust workspace)
- `garden-core` — shared types, traits, EventBus
- `garden-ssh` — ControlMaster monitoring, health checking
- `garden-daemon` — long-running infrastructure service
- `garden-ctl` — CLI tool
- `garden-tui` — Ratatui control plane
- `garden-autoresearch` — experiment orchestration (separate process)
- Docs: `04-infrastructure.md`

**garden-nyxt** (Common Lisp config)
- Nyxt browser theme and integration
- Garden curation commands
- Attention boundary modes
- Docs: `05-nyxt-and-curation.md`

**garden** (Tauri/Rust app — existing)
- Local-first curation app (Are.na-inspired)
- The visual ancestor of the entire design language
- Receives blocks from Nyxt via IPC

---

## Self-Hosted Services

```
homelab
  radicale        # CalDAV/CardDAV server (calendar + contacts)
  (future)        # additional services as needed
```

**Super Productivity** — task management, timeboxing, Pomodoro/Flowtime,
GitHub/GitLab integration. Local-first, open source.
Lives as `system:planner` page. Connects to Radicale via CalDAV.

**Radicale** — CalDAV server for calendar data. Plain .ics file storage,
git-versionable. Garden Shell calendar widget reads from it.

---

## Shared Resources

All repositories consume the same palette source:

```
~/.config/garden/
  palettes.json          # color palettes (built-in + custom)
  settings.json          # keybinds, appearance, host config
  ssh/                   # generated SSH config fragments
```

The palette generator pipeline (defined in `03-palette-and-theming.md`)
produces theme files for every target from `palettes.json`.

---

## How to Use These Docs with Claude Code

Each document is self-contained enough that an agent can work with
just the relevant doc(s):

- **Building a shell component?** Read `01-design-philosophy.md` +
  `02-shell-design.md` + `03-palette-and-theming.md` + `07-niri-migration.md`
- **Building the Rust daemon?** Read `01-design-philosophy.md` +
  `04-infrastructure.md`
- **Configuring Niri?** Read `07-niri-migration.md` +
  `02-shell-design.md` (workspace model + bar)
- **Configuring Nyxt?** Read `01-design-philosophy.md` +
  `05-nyxt-and-curation.md` + `03-palette-and-theming.md`
- **Setting up the research/writing workflow?** Read
  `08-research-workflow.md`
- **Making a design decision?** Check `06-open-questions.md` first

`01-design-philosophy.md` should always be included as context —
it's the shared value system that keeps all the pieces coherent.

---

## Project Name: Garden

Named after the local-first curation app that is the visual and
philosophical ancestor of the entire system. The name references:
- A curated space that grows through intentional cultivation
- Are.na's metaphor of channels and blocks
- Yokoyama Yūichi's manga *Garden* — vast spaces explored methodically
- Kenya Hara's concept of emptiness as readiness to receive

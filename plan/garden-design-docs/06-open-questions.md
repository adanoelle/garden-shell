# Garden — Open Questions

> Unresolved design decisions organized by theme. Update this document
> as decisions are made. Reference the relevant design doc for context.

**Last updated:** 2026-03-12

---

## 1. Color & Palette Infrastructure
*Context: `03-palette-and-theming.md`*

**Resolved:**
- [x] ANSI mapping: 13 semantic roles + 4 algorithmically derived complements
- [x] Custom palettes: unlimited
- [x] Shareable: yes, standalone .garden-palette.json files
- [x] File organization: palettes.json and settings.json separate
- [x] Regenerate button: yes, explicit action with status feedback
- [x] Live palette switch: hard cut for shell + Nyxt; others on restart
- [x] Pigment: OKLCH authoring → hex export to palettes.json
- [x] GTK/Qt crossfade: no — regenerate on demand, apps pick up on restart

**Remaining:**
(none — all questions resolved)

---

## 2. Attention & Curation
*Context: `05-nyxt-and-curation.md`*

- [ ] Garden block format: should saved web content include full HTML,
      cleaned HTML, markdown conversion, or just URL + metadata?
- [ ] Should the hint-save mode (Alt+Shift+S) preview the link
      metadata before saving, or save immediately?
- [ ] Time awareness mode: should accumulated time persist across
      Nyxt restarts (daily budget) or reset per session?
- [ ] Feed reduction: should rules be shareable as community-maintained
      lists (like ad-blocker filter lists)?
- [ ] Connection suggestions: local ML embedding similarity, keyword
      matching, or manual-only?
- [ ] How to handle saving content from JS-heavy SPAs where the URL
      doesn't reflect the actual content?

---

## 3. Information Display
*Context: `02-shell-design.md`*

**Resolved:**
- [x] Channel switcher: page name primary, truncated window title in text-3
- [x] Desktop clock: always visible on desktop (behind windows)
- [x] Notification suppression: global toggle + auto-suppress during focus sessions
- [x] System tray: text dropdown (no icon grid)
- [x] Volume OSD mute: shows "muted" label in text-4, empty progress bar
- [x] Calendar: read-only CalDAV client (Radicale on homelab), glance view only
- [x] Wallpaper: no wallpaper — base solid color + desktop clock, no gradients
- [x] Focus/Pomodoro: channel name shifts to accent during session,
      auto-suppress notifications, no countdown in bar

**Remaining:**
- [ ] Calendar sync: how to handle CalDAV auth credentials in NixOS config
      (sops-nix secrets? environment variable? keyring?)
- [ ] Super Productivity: page in system channel or scratchpad? Or both?
- [ ] Focus session detection: D-Bus signal from Super Productivity,
      or file-watch, or garden-daemon integration?

---

## 4. Host & Multi-Machine
*Context: `04-infrastructure.md` Section 3-4*

**Resolved:**
- [x] Host detection: hybrid (SSH config registry + window title runtime)
- [x] Tier colors: constrained to named tiers using semantic palette roles
- [x] Nested SSH: show final destination; full chain on hover/inspect
- [x] Host indicator animation: animate only on change, instant when same
- [x] Multi-monitor: freely movable with soft default-monitor affinity
- [x] ControlPersist: 8h OLCF, 8h DGX, 12h homelab
- [x] Connection drop handling: queue-and-notify
- [x] SSH config management: generated from NixOS

**Remaining:**
- [ ] Multi-monitor: should channels be lockable to specific monitors
      in addition to soft affinity?
- [ ] Should connection health checks run more frequently when agents
      have pending work? (adaptive interval)

---

## 5. Architecture & Extensibility
*Context: `02-shell-design.md` Section 12*

**Resolved:**
- [x] Hook system: QML signals on singletons (internal) + Quickshell
      IpcHandler via `qs ipc call` (external). No scripting language —
      QML is the config language, qs ipc is the external API.
- [x] Modes subsume barMode: composable per-channel behavior stacks
      (e.g. `modes = ["minimal-bar" "suppress-notifications"]`)
- [x] Launcher ambiguity: show all results categorized with source labels,
      running pages ranked first
- [x] Slow sources: show instant results immediately, slow results appear
      asynchronously (no spinner, no blocking)
- [x] Describe mode: deferred to post-v1 (`qs ipc show` partially fills
      the role for now)
- [x] Chords: no, modifier+key only for v1 (Niri doesn't support
      native chords; no current keybind conflicts require them)
- [x] Dev-mode boxes: global toggle only (`qs ipc call garden devMode true`)

**Remaining:**
(none — all questions resolved)

---

## 6. Nyxt Integration
*Context: `05-nyxt-and-curation.md`*

**Partially resolved:**
- [x] Nyxt → Garden Shell IPC: `qs ipc call garden` (Nyxt Lisp calls
      shell command via `uiop:run-program`). No custom socket needed.

**Remaining:**
- [ ] Nyxt status buffer: option A (minimal strip), B (eliminate),
      or C (Garden-native redesign)?
- [ ] Should Garden sidebar be always visible when Nyxt is open, or
      togglable? Should it adapt to the current channel?
- [ ] Buffer-set-per-channel: what happens to buffers in no channel?
      Orphan buffer pool? Auto-assign based on URL patterns?
- [ ] Should the reading mode typography be configurable independently
      of the shell typography, or always match?
- [ ] Should Garden bookmark command in Nyxt write to Garden's
      local database, or use an API/IPC protocol?

---

## 7. Animation & Motion
*Context: `03-palette-and-theming.md` Section 5*

**Resolved:**
- [x] Palette crossfade: hard cut, no animation (structural honesty —
      every other tool hard-cuts, shell should not be special)

**Remaining:**
- [ ] Reduced motion accessibility: binary on/off (all durations → 0),
      or a scale factor (0.5× for gentle reduction)?
- [ ] Desktop clock staggered entrance: should it replay on palette
      switch, or only on first appearance per session?
- [ ] MPRIS album art dithering: 1-bit ordered dither, Floyd-Steinberg,
      or Bayer matrix? What density?
- [ ] Screenshot save-to-Garden: should it auto-detect and suggest
      a channel based on the current Garden Shell channel?

---

## 8. Infrastructure (Rust)
*Context: `04-infrastructure.md` Section 13*

- [ ] Should garden-daemon manage its own SQLite WAL checkpointing?
- [ ] Autoresearch ↔ daemon: structured RPC (tonic/gRPC) over Unix
      socket, or simpler JSON-lines protocol?
- [ ] Should the TUI support multiple daemon connections (remote monitoring)?
- [ ] Job metrics: pull-based (poll remote files) or push-based
      (training script sends to daemon)?
- [ ] garden-autoresearch: experiment configs in TOML, JSON, or custom DSL?
- [ ] How to handle SLURM allocation quotas — should scheduler be
      aware of project allocation limits?
- [ ] Should daemon expose REST API for potential web UI or remote monitoring?
- [ ] Log retention: how long to keep event history? Auto-archive?
- [ ] Should garden-ctl support shell completions (bash, zsh, fish, nushell)?

---

## 9. Niri-Specific
*Context: `02-shell-design.md`, compositor migration*

- [ ] Clip Studio Paint under xwayland-satellite: test tablet input,
      color rendering, and window sizing before committing for studio channel
- [ ] Runtime window border color changes: can `niri msg` change individual
      window border colors dynamically for host tier indication, or do we
      need static window rules? If static only, rely more on bar indicator.
- [ ] Scratchpad toggle behavior: exact implementation of show/hide
      floating windows via niri msg — test reliability under rapid toggling
- [ ] Niri tabbed columns: should Garden Shell use tabbed columns for
      grouping related windows (e.g. multiple terminals), or keep one
      window per column and rely on scrolling?
- [ ] Niri overview feature: should Garden Shell integrate with Niri's
      built-in overview, or replace it with the channel switcher?
- [ ] Niri animations: should Garden Shell defer to Niri's built-in
      animations (which are configurable in config.kdl), or does the
      shell need its own layer? How do they interact?

---

## Decision Log

Record resolved questions here with date and rationale:

**2026-03-12: Host & Multi-Machine decisions**
- Host detection: hybrid SSH config + window title (robust, low-maintenance)
- Tier colors: constrained to semantic roles (meaning over identity)
- Nested SSH: final destination default (safety-critical info first)
- Host animation: change-only (calm at rest principle)
- Multi-monitor: soft affinity (freedom with spatial hints)
- ControlPersist: 8h/8h/12h (full work session coverage)
- Connection drops: queue-and-notify (human in auth loop, agents resilient)
- SSH config: NixOS-generated (single source of truth)

**2026-03-12: Infrastructure architecture decisions**
- Daemon: persistent systemd user service (reliable for agent orchestration)
- Autoresearch: separate process (independent iteration, clean boundaries)
- Storage: SQLite initial (hexagonal arch allows swap to DuckDB later)
- Crate organization: single Cargo workspace (synchronized types)

**2026-03-12: Terminal stack decisions**
- Terminal emulator: Kitty (mature, image protocol for yazi/chafa,
  kitten ssh for remote integration, balances Niri's newer-project risk)
- Shell: Fish (opinionated defaults, bash-compatible enough for agents)
- Editor: Kakoune primary, Helix backup (select-then-act = structural honesty)
- Prompt character: ✧ (white four-pointed star, U+2727)
  Quiet presence, queer/trans resonance, warm cream on dark blue-slate
- Prompt colors: text-1 normal, urgent on error, accent in nix shell, ok in venv
- Prompt layout: two-line, info above input, right-aligned Garden channel context
- Fish integrates with Garden channels via $GARDEN_CHANNEL environment variable

**2026-03-12: Terminal toolkit decisions**
- Essential: ripgrep, fd, bat, delta, zoxide, jq, yazi
- Recommended: lazygit (scratchpad Alt+V), btop, fzf/skim, glow, xh, jless, chafa
- No local multiplexer (Garden channels/pages + Niri scrollable tiling replace it)
- tmux on remote machines only, managed by garden-daemon RemoteExecutor
- All visual tools themed from palettes.json (bat, delta, lazygit, btop, yazi, fzf)
- Rust-native tools preferred for consistency with garden-infra codebase
- Tool selection principles: themeable, composable, replaceable

**2026-03-12: Color & palette infrastructure decisions**
- ANSI mapping: 13 semantic roles, 4 complement colors derived algorithmically
- Custom palettes: unlimited
- Shareable palettes: yes, standalone .garden-palette.json files
- File organization: palettes.json and settings.json remain separate files
- Theme regeneration: explicit "regenerate" action, not automatic on palette switch
- Live palette switch: instant hard cut for shell + Nyxt, other apps on restart
- Palette crossfade: none — hard cut, structural honesty over cosmetic smoothness
- Pigment integration: OKLCH authoring → hex export to palettes.json format
- GTK/Qt crossfade: no — unreliable, regenerate on demand instead

**2026-03-12: Information display decisions**
- Channel switcher: page name primary, truncated window title as text-3 secondary
- Desktop clock: always visible (behind windows, pointer-events: none)
- Notification suppression: global toggle (Super+Shift+N), plus auto-suppress
  during Super Productivity focus sessions
- System tray: text dropdown (no icon grid — text is more informative)
- Volume OSD mute: "muted" label in text-4, empty progress bar
- Calendar: read-only CalDAV client (self-hosted Radicale on homelab)
- Wallpaper: no wallpaper, no gradients — base solid color + desktop clock
- Focus/Pomodoro: handled by Super Productivity; bar shows accent channel name
  during focus sessions, no countdown timer (anti-attention-seeking)

**2026-03-12: De-Google infrastructure decisions**
- Calendar: self-hosted Radicale (CalDAV) on homelab, plain .ics files,
  git-versionable backups, synced via DAVx5 on mobile
- Task/time management: Super Productivity (open source, local-first,
  Pomodoro/Flowtime, GitHub/GitLab integration)
- Email: Proton Mail recommended (self-hosting email is a full-time job;
  pick battles — calendar self-hosting is easy, email is not)

**2026-03-13: Architecture & extensibility decisions**
- Hook system: QML signals (internal) + Quickshell IpcHandler (external)
  No scripting language needed — QML is the config, `qs ipc` is the API
  Quickshell's native IpcHandler gives every service a CLI API for free
- Modes: composable per-channel stacks, subsume barMode
  (e.g. `modes = ["minimal-bar" "suppress-notifications"]`)
- Launcher ambiguity: categorized results, running pages ranked first
- Slow launcher sources: async appearance, no blocking, no spinner
- Describe mode: deferred post-v1 (qs ipc show fills gap partially)
- Chord keybinds: no, modifier+key only for v1
- Dev-mode: global toggle only
- Nyxt ↔ Shell IPC: resolved via `qs ipc call` (Nyxt calls shell commands)

**2026-03-27: Compositor decision — Niri over Hyprland**
- Niri's scrollable-tiling model maps naturally to Garden's channel/page hierarchy:
  channels = Niri named workspaces (vertical), pages = columns (horizontal scroll)
- "Opening a new window never causes existing windows to resize" = structural honesty
- Rust foundation matches garden-infra ecosystem
- Quickshell has dedicated Niri QML plugin; proven by Noctalia, DankMaterialShell, iNiR
- Compositor abstraction layer (NiriAdapter.qml) preserves Hyprland fallback option
- Scratchpads implemented via floating windows + niri msg IPC (not native, but workable)
- Host awareness border tinting via Niri window rules (may need static rules vs runtime)
- Key risk: single maintainer — mitigated by compositor abstraction + Smithay foundation
- Key risk: X11 creative apps — xwayland-satellite integrated since 25.08, test Clip Studio
- Fish channel detection via `niri msg -j focused-window` instead of hyprctl

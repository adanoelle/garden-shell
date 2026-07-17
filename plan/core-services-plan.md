# Core Desktop Services — Implementation Plan

> Track: make Garden a complete daily-driver desktop for work (ORNL),
> research, and personal use. Implements the surfaces already specified in
> `garden-design-docs/02-shell-design.md` §6–10, sequenced against the
> codebase as it exists today (2026-07).

## Why this track first

The shell today is excellent chrome (bar, launcher, switcher, theming) but
delegates nothing-else to no-one: there is no notification daemon, no OSD,
no lock screen, no battery/network/tray state, no media surface. For a
work laptop that docks, joins meetings, and runs a VPN, these are
table stakes — and several later ambitions (HPC job alerts from
garden-daemon, screenshot → "save to garden", focus modes) all need a
notification surface to land on. Notifications are the keystone.

## Ground rules

- **Prefer Quickshell built-in services over process polling.**
  Quickshell ships `Quickshell.Services.{Pipewire, Notifications,
  SystemTray, UPower, Mpris, Pam}` and `WlSessionLock` in
  `Quickshell.Wayland`. Step 0 verifies each against the installed
  Quickshell version before we build on it.
- **Non-modal windows get their own base pattern.** `OverlayBase` is for
  modal, keyboard-grabbing overlays. Notifications/OSD/DesktopClock must
  not steal focus. The first component built in this track
  (`NotificationPopups`) establishes the non-modal pattern; OSD and
  everything after follows it (per CLAUDE.md).
- **Every new mode goes through ModeService + settings.json**, matching
  the existing per-channel `modes` array
  (e.g. `"modes": ["minimal-bar", "suppress-notifications"]`).
- **Spec fidelity:** visual details (sizes, colors, timings) come from
  `02-shell-design.md` §6–10 unless noted as a deliberate deviation.

## Step 0 — Verify the platform (half a session)

- [ ] `qs --version`; confirm which `Quickshell.Services.*` modules are
      present in the installed build (import each in a scratch QML file,
      check `just qs-log`).
- [ ] Confirm niri + quickshell handle `WlSessionLock` (niri implements
      `ext-session-lock-v1`).
- [ ] Note results at the top of this file so later steps don't re-litigate.

## Phase A — Reactive audio plumbing (1 session)

Replace the 500 ms `wpctl` poll in `AudioService.qml` with
`Quickshell.Services.Pipewire`:

- `Pipewire.defaultAudioSink` + `PwObjectTracker` for bound nodes;
  expose the same `volume` / `muted` properties so `BarSystemState`
  doesn't change.
- Add `AudioService.volumeChanged` / `mutedChanged` semantics suitable
  for OSD triggering (suppress the initial-state event on startup so the
  OSD doesn't flash on login).
- Keep `BrightnessService` (ddcutil) as-is for now, but emit a change
  signal the OSD can consume. ddcutil polling is slow; brightness OSD can
  also be triggered optimistically from the keybind path later.

Why first: OSD and bar both want event-driven audio; polling can't drive
a "show OSD on change" surface without heuristics.

## Phase B — Notifications (2–3 sessions) ← keystone

**B1. `services/NotificationService.qml`** — singleton wrapping
`NotificationServer`:

- Tracked list of active notifications (id, appName, summary, body, icon,
  actions, urgency, timestamp).
- Suppression model:
  - global toggle (IPC `suppressNotifications(bool)` + Super+Shift+N);
  - per-channel via ModeService: `"suppress-notifications"` in the active
    channel's mode stack;
  - focus sessions later reuse the same switch (IPC `focusStart/focusEnd`).
- While suppressed: queue silently, expose `queuedCount` for the bar dot.
- Expiry: 10 s default (spec), respect notification-specified timeouts,
  urgency=critical never auto-expires.

**B2. `notifications/NotificationPopups.qml`** — the first non-modal
window; establishes the pattern (PanelWindow, `WlrLayer.Overlay`,
`exclusiveZone: 0`, **no** keyboard focus, click-through outside cards):

- Anchored right edge; cards 264–272 px, `base-raised`, 1 px `border`.
- App name bold `text-1`, body `text-2`, timestamp mono `text-4`.
- Progress line depleting over the expiry window.
- Vertical-compress dismiss; 60 ms staggered entrance.
- Action buttons via `GButton`; invoke + dismiss.

**B3. Wiring**

- `HookService`: `suppressNotifications`, `notificationsSuppressed(bool)`
  signal; bar dot indicator in `BarSystemState` when suppressed with
  queued items.
- ModeService: generalize beyond bar heights — `hasMode(name: string)`
  for the active channel (bar-height logic becomes a consumer of it).
- fern: keybind Super+Shift+N; disable any mako/dunst autostart.
- `_config/niri.kdl` reference config updated alongside.

**Risk:** only one notification daemon can own the D-Bus name. Rollout
step: verify no other daemon is enabled in fern before switching.

## Phase C — Volume/brightness OSD (1 session)

`osd/Osd.qml`, second non-modal window, reusing the Phase B pattern:

- 280×28 px, centered bottom; mono label + 4 px progress; 1.5 s dismiss.
- One component for volume and brightness (spec §10); triggered by
  AudioService/BrightnessService change signals.
- Muted state: "muted" in `text-4`, empty bar; still shown on mute toggle.
- Guard: no OSD on startup or palette reload; only on real state changes.

## Phase D — Lock screen + power menu (2 sessions)

Work-machine requirements; do before the first day badge-in if possible.

**D1. `lock/LockScreen.qml`** using `WlSessionLock` +
`Quickshell.Services.Pam` for auth:

- Full-screen `base-deep` with the existing `DitherOverlay` "lock"
  preset (finally used!), 1 px border frame inset 24 px.
- Clock 96 px mono weight 300 `text-1` @ 0.9; seconds 40 px `text-3`
  @ 0.4; lowercase wide-tracked date.
- `ada@nix` label → bordered password field → "press enter" hint;
  shake/urgent border on PAM failure.
- Footer: `nixos · niri · garden shell`.
- IPC `lock` method so external triggers work.

**D2. Idle integration (fern):** swayidle (or niri idle config) →
`qs -c garden ipc call garden lock`, plus lock-before-suspend
(`before-sleep`). Lives in fern; document here, implement there.

**D3. `overlays/PowerMenu.qml`** — this one IS modal, so it extends
`OverlayBase`: horizontal text row `lock · suspend · logout · reboot ·
shutdown`, arrow-key navigation, destructive actions require a second
Enter (confirm state swaps label to `confirm shutdown?` in `urgent`).
IPC `togglePowerMenu`, keybind Super+Escape.

## Phase E — Bar system state: battery, network, tray (2–3 sessions)

**E1. Battery (UPower).** Not in the original spec (desktop-era doc) —
added for the ORNL laptop:

- `services/BatteryService.qml` on `Quickshell.Services.UPower`.
- Bar: percentage in mono `text-3`, `urgent` below 15 %, charging
  indicator; hidden entirely on machines without a battery
  (`UPower.displayDevice` presence check).
- Low-battery warning lands as a notification (Phase B pays off).

**E2. Network indicator + panel.**

- `services/NetworkService.qml`: `nmcli monitor` / `nmcli -t` process
  parsing (no Quickshell built-in for NM) — SSID, wired, VPN/tailscale
  state.
- Bar: text-first status (`homelab` / `ornl-guest` / `offline`), VPN
  state as an `accent` dot — glanceable "am I on the VPN" matters at work.
- `panels/NetworkPanel.qml` floating card from bar click, text + signal
  bars, no switch widgets (spec §10).

**E3. System tray.**

- `Quickshell.Services.SystemTray`; bar shows a single dot when items
  exist (spec: no icon grid).
- `panels/TrayPanel.qml`: text dropdown listing items
  (`bluetooth · connected (WH-1000XM5)` style), click activates,
  right-click menu via the tray item's menu model.

## Phase F — Riders (1 session each, orderable freely)

- **MPRIS ambient title**: `Quickshell.Services.Mpris`; track title in
  `text-3` in the bar, gated by a `"mpris-ambient"` channel mode (music
  channel). Full MediaControls scratchpad deferred.
- **Screenshot flow**: keybind → `grim`/`slurp` → notification with
  thumbnail + actions (copy / open / *save to garden* — the action hook
  the are.na track will claim later).
- **Clipboard history**: `cliphist` list as a launcher source
  (Super+Shift+V opens Launcher pre-filtered), same ResultItem language.
- **Launcher calc hardening**: replace `eval()` with a small
  shunting-yard parser (also closes an injection-adjacent smell).
- **Focused-screen overlays**: overlays currently appear on one screen;
  when docked multi-monitor at work they should follow
  `CompositorService` focus. Small `OverlayBase` change, verify with two
  outputs.

## Explicitly deferred (tracked, not forgotten)

- Desktop clock overlay (§8) — pure delight, zero dependencies, do any
  rainy day.
- Calendar/CalDAV glance view — **open question for ORNL**: Radicale on
  the homelab may be unreachable from the work network; needs
  cache-and-degrade or a tailscale-only answer before it's worth building.
- Focus-session integration (Super Productivity IPC) — rides on the
  Phase B suppression switch once the planner is in daily use.
- Tooltips, network/bluetooth deep panels, MediaControls scratchpad.

## Suggested order & effort

| Phase | What | Est. sessions |
|---|---|---|
| 0 | Platform verification | 0.5 |
| A | Pipewire audio refactor | 1 |
| B | Notifications + suppression | 2–3 |
| C | OSD | 1 |
| D | Lock screen + power menu | 2 |
| E | Battery / network / tray | 2–3 |
| F | Riders | as desired |

Each phase lands independently and is hot-reload testable
(`just qs-log`, `just qs-ipc …`); fern-side keybinds batch at the end of
each phase (`just switch`).

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

## Step 0 — Verify the platform (half a session) ✅ 2026-07-17

**Probe results (quickshell 0.1.0, Nixpkgs):** all seven modules ok —
Pipewire, Notifications, SystemTray, UPower, Mpris, Pam, and
Quickshell.Wayland (`WlSessionLock` instantiates). Caveats:

- The UPower **system daemon** is not running on this machine
  (`org.freedesktop.UPower` not on D-Bus) — enable `services.upower`
  in fern before Phase E battery work.
- The probe's `Qt.quit()` has no receiver under `ShellRoot`; the probe
  process must be killed manually after it prints.
- Editing a service QML file does not always trigger hot-reload;
  `touch _qml/shell.qml` forces it.

- [x] Run `just qs-probe` — one-shot probe (`_qml/dev/probe.qml`) that
      imports each required service module and prints ok/MISSING per
      line, plus `qs --version`.
- [x] If `Quickshell.Services.Pipewire` reports MISSING, the installed
      quickshell was built without pipewire support — fix the package in
      fern before Phase A's AudioService (already migrated) can work.
- [x] Confirm niri + quickshell handle `WlSessionLock` (niri implements
      `ext-session-lock-v1`; probe checks the quickshell side).
- [x] Note results at the top of this file so later steps don't re-litigate.

## Phase A — Reactive audio plumbing (1 session) ✅ implemented

Replace the 500 ms `wpctl` poll in `AudioService.qml` with
`Quickshell.Services.Pipewire`:

- [x] `Pipewire.defaultAudioSink` + `PwObjectTracker`; same public
      `volume` / `muted` properties, plus `ready`, `setVolume()`,
      `toggleMute()`.
- [x] `stateChanged()` signal for OSD triggering — guarded by a
      `_settled` flag so initial-state population on login doesn't fire
      it. `BrightnessService` gets the same signal + guard (ddcutil
      polling kept for now; brightness OSD can also trigger
      optimistically from the keybind path later).
- [x] `BarSystemState` now listens to `stateChanged()` instead of raw
      property changes — the bar slots no longer flash on login.
- [x] **Verify on hardware** (2026-07-17): `just qs-probe` all ok; volume
      bump 55→60→55 % via wpctl produced clean logs (the old wpctl-poll
      warnings are gone) and the `stateChanged()` → `v{n}` trigger path
      is confirmed wired.

Why first: OSD and bar both want event-driven audio; polling can't drive
a "show OSD on change" surface without heuristics.

## Phase B — Notifications (2–3 sessions) ← keystone ✅ implemented 2026-07-17

> B1–B3 landed: NotificationService + NotificationPopups/NotificationCard
> (first non-modal window), ModeService.hasMode(), HookService IPC
> (`suppressNotifications`, `toggleNotifications`), bar suppression dot,
> Super+Shift+N in fern (needs `just switch`) + `_config/niri.kdl`.
> Verified end-to-end: D-Bus name owned by quickshell, popups render,
> suppress → queue → release cycle works. Decisions: bar dot shows at
> text-4 whenever suppressed, accent once items queue; unsuppressing
> releases the queue as popups; card click dismisses; no icons/images in
> cards yet (text-first). Debugging note: interaction-time
> "invalid context" / ReferenceError QML errors during this build were
> stale hot-reload state, not code bugs — gone after a full restart
> (see CLAUDE.md "Restarting Quickshell"). Also fixed `just qs-restart`,
> which had never actually killed the process (`.quickshell-wrapped`
> comm name).
>
> **Upgrades landed 2026-07-17 (second pass):**
> - **History center** — session-only in-memory history (cap 50), plain-JS
>   snapshots taken at arrival in `onNotification` (single capture point,
>   covers shown AND queued; Notification QObjects die after close).
>   `overlays/NotificationCenter.qml` (OverlayBase, 480 px, 200 ms) with
>   j/k/arrows nav, `c` clear, Esc close; IPC `toggleNotificationCenter`,
>   Super+Shift+M. Limitation: `replaces_id` updates don't refresh
>   history snapshots. Synthetics don't enter history.
> - **Summary release** — unsuppressing no longer dumps the queue as a
>   popup bomb: queue is cleared first (idempotent under rapid toggles),
>   N=1 releases the real popup (keeps actions), N>1 dismisses all and
>   shows ONE synthetic summary card ("N notifications while suppressed")
>   whose `open` action / card click opens the center. Synthetic shim =
>   plain JS object matching NotificationCard's API surface with
>   `expire()`/`dismiss()` closures → `_remove`; required untyping
>   `timeoutFor(n)` (typed param coerced JS objects to null).
> - **Focus sessions** — `focusActive` as global third OR-term in
>   `suppressed`; IPC `focusStart`/`focusEnd` (idempotent `setFocus`);
>   on end the queue releases synchronously, then a "focus session
>   complete / take a break" synthetic shows — deliberately bypassing the
>   queue (local intentional signal per §6, shown even on suppress-mode
>   channels). `focusSessionChanged(bool)` signal on HookService.
> - Bar dot unchanged — existing suppressed/queued logic already covers
>   focus sessions.
> - **Critical bypass** — urgency=critical skips all three suppression
>   layers and pops up immediately (GNOME/KDE DND convention; keeps the
>   Phase D low-battery warning from dying silently in a focus session).
>   Trade-off accepted: suppression is no longer absolute for criticals.

**B1. `services/NotificationService.qml`** — singleton wrapping
`NotificationServer`:

- Tracked list of active notifications (id, appName, summary, body, icon,
  actions, urgency, timestamp).
- Suppression model:
  - global toggle (IPC `suppressNotifications(bool)` + Super+Shift+N);
  - per-channel via ModeService: `"suppress-notifications"` in the active
    channel's mode stack;
  - focus sessions ✅ landed as global `focusActive` third layer (IPC
    `focusStart/focusEnd`).
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

## Phase C — Volume/brightness OSD (1 session) ✅ implemented 2026-07-17

`osd/Osd.qml`, second non-modal window, reusing the Phase B pattern:

- 280×28 px, centered bottom; mono label + 4 px progress; 1.5 s dismiss.
- One component for volume and brightness (spec §10); triggered by
  AudioService/BrightnessService change signals.
- Muted state: "muted" in `text-4`, empty bar; still shown on mute toggle.
- Guard: no OSD on startup or palette reload; only on real state changes.

> Landed: `osd/Osd.qml` + shell.qml wiring. Volume OSD verified instant
> (Pipewire event-driven). Collision: single bar retargets to most-recent
> source, no stacking. Brightness lag confirmed (~3 s poll delay, plus
> I2C bus contention when ddcutil setvcp races the poll); the signal-driven
> path works but needs an optimistic `showBrightnessOsd(value)` IPC method
> callable from the fern keybind to feel responsive — deferred to a
> follow-up (plan §10 noted this risk).

## Phase D — Lock screen + power menu (2 sessions) ✅ implemented 2026-07-17

Work-machine requirements; do before the first day badge-in if possible.

> **Landed:** `lock/LockScreen.qml` (Scope: WlSessionLock + PamContext +
> shared auth state) + `lock/LockSurface.qml` (per-screen
> WlSessionLockSurface) — the third window kind, neither OverlayBase nor
> the non-modal PanelWindow pattern. `overlays/PowerMenu.qml`
> (OverlayBase, zero-size focus-item key idiom). IPC `lock` +
> `togglePowerMenu`; keybinds Super+Escape (power menu) and Super+Alt+L
> (direct lock — added beyond plan) in fern + `_config/niri.kdl`.
>
> **Lockout-safe rollout worked as designed:** PAM flow proven first in
> a throwaway window (`_qml/dev/pamtest.qml`, kept for reuse) —
> non-interactive wrong-password probe (`PAMTEST_AUTO=bad`) then
> interactive good-password — before `locked: true` was ever wired.
> Spare-TTY lifeboat verified (ctl+opt+fn+F2 on the mac-layout board;
> note: SSH here is key-only, so the TTY is the primary lifeboat).
> Full cycle verified on hardware: lock → wrong password (urgent border
> + shake, field clears) → right password → unlock; suspend →
> before-sleep lock → resume → unlock also verified.
>
> **Decisions / deviations from spec §7 (approved during test):**
> - PAM config is `"swaylock"` (auth-only pam_unix stack in
>   /etc/pam.d/swaylock) — not "login", which drags in loginuid/systemd
>   session modules a locker shouldn't run.
> - Outer 1px frame inset 24px **removed** — read as clutter on hardware.
> - Full-opacity cream "lock" dither competed with the (same-colored)
>   text: dither dimmed to 0.4 opacity, and the clock/login block sits on
>   a base-deep clearing card with a 1px border-sub border (masks dots
>   behind text; reads as a panel).
> - Power menu destructive confirm: second Enter, label swaps to
>   `confirm <action>?` in urgent; Esc / moving selection cancels the
>   pending confirm. logout runs `niri msg action quit
>   --skip-confirmation` (the menu already confirmed — avoids niri's own
>   double prompt).
> - `LockScreen.lock()` is idempotent; do NOT hot-reload lock QML while
>   locked (under ext-session-lock a dead lock client leaves the session
>   locked — recovery ladder documented in the session, TTY → pkill →
>   relaunch quickshell → re-auth).
>
> **D2 (fern):** `services.swayidle` in the niri aspect's homeManager
> section — 600 s idle → `qs -c garden ipc call garden lock`, plus
> `before-sleep` event (logind inhibitor) for lock-before-suspend.
> Deployed with `just switch`.

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

## Phase E — Bar system state: battery, network, tray (2–3 sessions) ✅ implemented 2026-07-17

> **Landed:** `services/BatteryService.qml`, `services/NetworkService.qml`,
> `panels/TrayPanel.qml` + battery/network/tray indicators in
> `BarSystemState`. Prerequisite `services.upower.enable` in fern's niri
> aspect (UPower is D-Bus demand-activated; verified via `busctl`).
> New IPC: `toggleTray`, plus warm-up riders `showBrightnessOsd` /
> `stepBrightnessOsd` (optimistic OSD before the ~200 ms ddcutil step;
> `BrightnessService.setSilently` keeps the 3 s poll from re-showing
> it). Fern brightness keybinds now call the IPC first, mirrored in
> `_config/niri.kdl`. Other riders: OSD window shrunk to the 280 px
> card (was a full-width click-eating strip); PowerMenu flashes its
> border urgent for 1.2 s on nonzero exit (polkit denial isn't silent).
>
> **Anchored-panel pattern (fourth window kind — TrayPanel is the
> reference):** NOT OverlayBase. A transparent full-surface PanelWindow
> (`exclusiveZone: 0`, overlay layer) acts as a click-outside catcher;
> the content card anchors to a bar-relative corner
> (`ConfigService.barPosition`-aware). Pointer-only — no keyboard grab,
> no dimming. NetworkPanel and the calendar glance should reuse this.
>
> **Decisions / deviations:**
> - Battery bar slot is a persistent `text-3` percentage (`+` suffix on
>   AC, urgent ≤15 % discharging) — deliberately NOT the v/b
>   BarStateSlot flash idiom: charge is glanceable state, not an event.
>   Low warning at ≤10 %, once per discharge cycle (rearms on AC), sent
>   critical via new `NotificationService.sendSynthetic(summary, body,
>   urgency)` — shim factory + urgency override; synthetics bypass the
>   queue by construction. This machine has no battery: hide path
>   verified live (`isLaptopBattery: false` probe); battery-present
>   rendering follows the documented 0–1 `percentage` and awaits laptop
>   hardware.
> - Network: `nmcli monitor` long-lived Process → 300 ms debounced
>   re-query (`nmcli -t -f TYPE,DEVICE,NAME connection show --active`);
>   monitor respawns 3 s after exit (NM restart). Bar text: SSID /
>   `eth` / `offline` in text-3, VPN as accent dot. Tailscale check
>   rides the same trigger via a sh guard that prints `{}` when the
>   binary is missing (not installed on this box — path dormant).
>   NetworkPanel deferred as planned (since landed 2026-07-20 — see
>   E2); bar indicator was the Phase E deliverable.
> - Tray menus are rendered as themed text rows via `QsMenuOpener`
>   drill-down (`‹ back`, `›` submenus, `[x]`/`(·)` check prefixes,
>   320 px elide) — NOT `SystemTrayItem.display()`: platform menus need
>   `//@ pragma UseQApplication` and render unstyled (tried, reverted).
>   Menu-only appindicator items (nm-applet exposes no `Activate`) open
>   the menu on left click too.
> - Positioner lesson: never `width: parent.width` in a Column delegate
>   — the positioner sizes FROM child widths; the loop blew the menu
>   card past the screen edge. Separator rules bind the Column's width
>   instead (one-way).
> - Tested with `nm-applet --indicator` via `nix shell`
>   (blueman-applet hides its SNI when no bluetooth adapter exists).
>   No new keybinds — tray is click/IPC-driven.

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

> **Landed (panel, 2026-07-20):** `panels/NetworkPanel.qml` on the
> TrayPanel anchored-panel shape; bar `eth`/SSID label is clickable
> (halo idiom); new IPC `toggleNetworkPanel`. No fern changes — click/
> IPC-driven like the tray.
>
> **Decisions / deviations:**
> - **Saved connections only.** The panel is pointer-only (no keyboard
>   grab), so there is no password entry. Unknown secured wifi networks
>   are listed but not clickable; known = SSID ∈ saved wireless profile
>   names (NM's profile-name==SSID convention, approximation noted in
>   code).
> - Activation always via `nmcli connection up id` — never
>   `device wifi connect`, which can duplicate profiles.
> - Confirm-down (PowerMenu second-click idiom) only when dropping the
>   **last active link**. `connection up` is a local D-Bus call, so the
>   panel restores a link even while offline — confirm guards
>   accidents, not lockout. VPN rows toggle without confirm (never
>   connectivity-fatal).
> - Errors are text-first in the row's status slot: first stderr line,
>   `Error:` prefix stripped, ~60 chars, 6 s auto-clear. No toasts.
> - Wifi scan only on panel open (`--rescan auto`) + explicit `rescan`
>   row (`--rescan yes`) — monitor events never rescan (radio churn).
>   Terse parsing needs real unescaping (`\:`/`\\`) since NAME/SSID
>   lead the field list: `_splitTerse` in NetworkService.
> - Tailscale is a read-only `tailscale · up` line — `tailscale up` may
>   need a browser auth flow a pointer-only panel can't host, and a
>   one-way toggle is a confusing affordance.
> - Surprise: this desktop has a wifi radio (`wlp6s0`), so section
>   visibility, scan parsing, signal bars, and secured/unknown
>   rendering verified here. Still owed to the laptop pass:
>   known-network activate + rescan latency (no saved wifi profiles on
>   this box).

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
- Tooltips, bluetooth deep panel, MediaControls scratchpad.
- ~~Network panel~~ (deferred 2026-07-18, **landed 2026-07-20** — see
  E2 landed note for scope decisions). Remaining laptop-day items:
  known-network activate, rescan latency, real-VPN toggle.

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

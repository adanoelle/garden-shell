# Garden Shell — Component Design

> Quickshell/QML desktop shell for Niri: bar, launcher, overlays,
> notifications, lock screen, settings, and all shell utilities.
> Designed with a compositor abstraction layer — Hyprland fallback possible.

**Last updated:** 2026-03-27
**Related docs:** `01-design-philosophy.md`, `03-palette-and-theming.md`, `04-infrastructure.md`

---

## 1. Workspace Model — Channels & Pages

### Conceptual Model
Workspaces are organized as a two-level hierarchy inspired by Are.na:
- **Channels** — top-level workflow domains (studio, research, writing, music, system)
- **Pages** — individual windows within a channel, arranged as columns

Niri's scrollable-tiling model maps to this naturally:
- **Channels = Niri named workspaces** (vertical axis, Super+1-5)
- **Pages = columns on the horizontal strip** (scroll with Super+H/L)

Opening a new window never causes existing windows to resize — Niri's
core guarantee. You scroll to new pages rather than teleporting to
separate workspaces. This preserves spatial awareness: neighboring
windows remain accessible by scrolling, like turning your head at a desk.

### Example Topology
```
studio (workspace)              research (workspace)
  ← clip-studio | aseprite |      ← kak | frontier | docs →
     godot →                    (scroll horizontally between columns)

writing (workspace)             music (workspace)
  ← obsidian | typst →           ← ardour | strudel | guitar →

system (workspace)
  ← config | monitor | planner →
```

### Niri Implementation
Named workspaces defined in `~/.config/niri/config.kdl`:
```kdl
workspace "studio"
workspace "research"
workspace "writing"
workspace "music"
workspace "system"
```

Each channel is a Niri workspace. Pages are columns within that
workspace — Niri's native unit. No namespace delimiter hack needed;
the compositor's model matches the conceptual model directly.

Niri also supports **tabbed columns** — multiple windows stacked as
tabs within a single column. This could be useful for grouping related
windows (e.g. multiple terminals in one column with tab switching).

### Navigation
```
Super + 1-5          → switch channel (focus-workspace by name)
Super + H/L          → scroll to prev/next column (page)
Super + Tab          → channel switcher overlay (Garden Shell)
Super + /            → full app launcher
Super + N            → new column in current channel
Super + Shift + Q    → close current window
Alt + [key]          → toggle floating scratchpad
```

### Dynamic Pages
Channels are defined in config (static). Pages within channels are
fluid — open a new window and it becomes a new column. Close a window
and it's gone. The horizontal strip grows and shrinks naturally.

---

## 2. Bar Design

### Channel-Focused Display
- **Active channel:** expands to show name (bold) + page tabs. Active page
  gets subtle underline and `base-hl` background.
- **Inactive channels:** collapse to dots. Occupied = `text-3` dot,
  empty = `border-sub` dot. Hover expands name. Click switches.

### Three Density Modes (auto-switch per channel)

**Full (34px):** workspaces, pages, clock+date, metrics, host indicator.
For research, system monitoring.

**Standard (30px):** workspaces, pages, clock only. For writing, general work.

**Minimal (2px → 30px on hover):** thin accent line. For full-screen creative
apps, music/live coding.

### Bar Layout (Full Mode)
```
[·] [·] research : helix · ▸frontier · docs [·]  ▪frontier  14:32  cpu 8% mem 4.1g
dots   active channel + page tabs             host dots  clock  metrics
```

### Host Indicator
See `04-infrastructure.md` Section 4. Appears between pages and clock when
focused window has remote connection. Color from host tier (urgent/accent/ok).
Host detection via window title matching against SSH config registry —
compositor-agnostic (works with both Niri and Hyprland).

### Connection Health Dots
Small colored squares (▪) in metrics zone showing persistent SSH connection
state. Solid = alive, hollow = stale, absent = disconnected.

---

## 3. Launcher

**Trigger:** `Super + /`

Universal command palette — type to reach any capability:
```
Type...                Result
"firefox"              → launch app
"research"             → switch channel
"palette mokume"       → switch palette
"lock"                 → lock screen
"clip"                 → clipboard history
"connect frontier"     → open SSH auth terminal
"describe bar"         → introspection panel
"calc 2+2"             → inline calculation
```

### Appearance
- Dithered PC-98 backdrop (not blur)
- Centered panel, 460px wide, 1px `border`, no rounded corners
- `/` prefix in `text-4`, results as flat list
- Selected: `base-hl` background, `text-1`, weight 600
- Footer: keybind hints in `text-4` mono

---

## 4. Channel Switcher

**Trigger:** `Super + Tab`

Shows all channels (workspaces) with their columns. Page name primary,
truncated window title as secondary in `text-3`. Horizontal layout
reflects the actual scroll position on each strip:

```
research                                    3 columns
  kak (events.rs)  · ●frontier (login01)  · docs (Research)
                      ↑ currently focused

studio                                      2 columns
  aseprite (sprite_walk.ase)  · godot (raven)
```

The active column in each channel is marked. Arrow keys navigate
channels vertically, Enter switches, Escape closes. Same dithered
backdrop and visual language as launcher.

---

## 5. Floating Scratchpads

Toggle on/off with keybind, always use dithered backdrop:
```
Alt + G    → Garden (curation app)
Alt + T    → quick terminal
Alt + M    → music player
Alt + V    → lazygit (version control)
```

Floating window centered with 1px border. Title bar shows `special:{name}`.

Niri supports floating windows but not native scratchpad toggle. The shell
implements scratchpad behavior via `niri msg` IPC: on toggle, either spawn
the window as floating or show/hide it. A small `ScratchpadService.qml`
manages the toggle state and window matching by app-id.

---

## 6. Notifications

- Slide from right, 264-272px wide, `base-raised` with 1px `border`
- App name bold `text-1`, body `text-2`, timestamp `text-4` mono
- Progress line depletes over 10s, then vertical-compress dismiss
- Staggered entrance: 60ms per card

### Context-Aware Behavior
- Global notification toggle (Super+Shift+N or launcher: "notifications off")
- When suppressed: dot indicator in bar, notifications queue silently
- Additionally, active focus session (via Super Productivity) automatically
  suppresses notifications for the active channel
- Research/browsing: show normally when unsuppressed

---

## 7. Lock Screen

- Full-screen `lock-bg` with sparse dithered texture
- 1px border frame inset 24px from edges
- Clock: 96px mono, weight 300, `text-1` at 0.9 opacity
- Seconds: 40px, `text-3` at 0.4 opacity
- Date: 13px, wide letter-spacing, lowercase
- Login: `ada@nix` label → bordered input field → "press enter" hint
- Bottom: `nixos 24.11 · niri · garden shell`

---

## 8. Desktop Clock Overlay

- Large mono time: 80px, weight 300, `text-1` at 0.12 opacity
- Date below: 14px, `text-1` at 0.08 opacity
- Position: lower-left (bottom: 60px, left: 40px)
- **Always visible** on desktop — non-interactive (pointer-events: none)
- Sits behind all windows; visible when desktop is exposed or no windows open
- Entrance: digits render one at a time, 40ms stagger (departure board effect)

---

## 9. Dithering System

Replaces gaussian blur everywhere. PC-98 signature material.

**Patterns:**
- **Dense** (2×2 checkerboard, ~88%) — launcher, switcher, scratchpads
- **Light** (4×4 sparse, ~50%) — less critical overlays
- **Lock** (6×6 very sparse, ~2.5% cream) — lock screen texture

Rendered with `image-rendering: pixelated`. In QML: ShaderEffect or tiled PNG.

---

## 10. Shell Utilities

### Volume & Brightness OSD
Thin horizontal bar (280px, 28px tall), centered bottom. Label in mono,
4px progress bar, 1.5s auto-dismiss. One component for both.
Muted state: label shows "muted" in `text-4`, progress bar empty,
volume icon (if present) crossed out. OSD still appears on mute/unmute
toggle to confirm the state change.

### MPRIS Media
- **Bar:** ambient track title in `text-3` (music channel only, via modes)
- **Scratchpad (Alt+M):** album art with dithered halftone, text transport

### System Tray
Text-first dropdown. Bar shows single dot indicator for tray presence.
Click opens dropdown listing all tray items as text labels with status:
```
bluetooth · connected (WH-1000XM5)
network · homelab (192.168.1.x)
tailscale · connected
```
No icon grid. Text is more informative and matches Garden's
typography-driven hierarchy.

### Power Menu (Super+Escape)
Horizontal text: `lock · suspend · logout · reboot · shutdown`
Destructive actions require second confirmation.

### Screenshot
Notification with thumbnail + "save to garden" action.
Recording: pulsing `urgent` dot + duration in bar.

### Clipboard History (Super+Shift+V)
Launcher extension — same visual language, clipboard data source.

### Network/Bluetooth Panels
Floating cards from bar click. Text + signal bars, no switch widgets.

### Calendar (click clock)
Read-only CalDAV client displaying events from self-hosted Radicale.
Typographic grid: mono numbers (aligned columns), current day `base-hl`,
events as `accent` dots below their dates. Click a day to see event
titles in a small detail panel below the grid.

No editing — create and manage events in Super Productivity. The shell
calendar is a glance view: "what's happening today/this week."

Data source: CalDAV (Radicale on homelab). Fetches and caches events
locally with configurable sync interval (default: 15 minutes).

```nix
gardenShell.calendar = {
  enable = true;
  caldav.url = "https://radicale.homelab.local/ada/calendar.ics";
  caldav.syncInterval = 15;  # minutes
};
```

### Focus Session Integration
When Super Productivity starts a Pomodoro/Flowtime session:
- Active channel name shifts to `accent` color in the bar
- Notifications auto-suppress for the active channel
- Break notification appears via Garden Shell when session ends
- No countdown timer in bar (timers are attention-seeking; deep work
  means forgetting about time, not watching it)

Super Productivity lives as a page (`system:planner`) or scratchpad.
Tier 4 theming (Electron — containment via dithered backdrop + border).

### Tooltips
`base-raised` card, 400ms delay, no arrow, 200px max width.
Content varies per bar element.

### Wallpaper
No image wallpaper. The palette IS the visual identity.
Desktop is `base` solid color + always-visible desktop clock.
No gradients, no generated art, no photographs. The simplicity is
deliberate: when you expose the desktop, you see the color of your
chosen palette and the time. Nothing competes with your work.

### Multi-Monitor
Per-monitor bar instances, shared channel topology. Freely movable
with soft default-monitor affinity per channel.

---

## 11. Settings Panel

**Trigger:** `Super + ,`

Unified floating window with dithered backdrop. Tabs: palette, keybinds.
Panel renders in active palette (self-referencing).

### Palette Editor
- Mode selector: mokume/sumi/kinu/yoru + custom
- 13 hex inputs grouped by role (surfaces, borders, text, semantic)
- Live preview (mini bar, terminal, code, notification, swatch strip)
- Custom palette creation: name → fork base → pick icon → subtitle
- Export/import JSON for sharing

### Keybind Remapper
- Filter/search input
- Flat list by category (channels, pages, shell, scratchpads, windows)
- Each row: action name + layer badge (`niri`/`quickshell`) + keybind input
- Click to capture: field pulses, press new combo, Enter confirms
- Conflict detection with resolution prompt
- Save: quickshell binds apply immediately, niri binds written to config.kdl

See `03-palette-and-theming.md` for palette JSON schema and
`04-infrastructure.md` for how keybinds map to Niri config generation.

---

## 12. Extension Architecture

### Principle
No scripting language. QML is the config language, `qs ipc` is the
external API, and Quickshell's live-reload means editing a QML file
applies changes immediately. This covers every extension use case
without embedding Lua, Lisp, or a custom DSL.

### Three Mechanisms

**Internal hooks (QML signals on singletons):**
Shell components communicate through typed signals on service singletons.
Standard Qt reactive binding — no framework to build.

```qml
// services/HookService.qml
pragma Singleton
import Quickshell
import Quickshell.Io

QtObject {
    // Lifecycle signals — any component can connect to these
    signal channelSwitched(string channel, string page)
    signal paletteChanged(string palette)
    signal notificationsSuppressed(bool suppressed)
    signal focusSessionStarted(string channel)
    signal focusSessionEnded(string channel)
    signal connectionChanged(string host, string state)
    signal blockSaved(string channel, string url)

    // External API via qs ipc
    IpcHandler {
        target: "garden"

        function switchPalette(palette: string): void {
            // load palette from palettes.json, apply to Theme singleton
            paletteChanged(palette)
        }

        function switchChannel(channel: string): void {
            // dispatch to Niri via niri msg
            channelSwitched(channel, "")
        }

        function suppressNotifications(suppress: bool): void {
            notificationsSuppressed(suppress)
        }

        function focusStart(channel: string): void {
            focusSessionStarted(channel)
        }

        function focusEnd(channel: string): void {
            focusSessionEnded(channel)
        }

        function getChannel(): string {
            return currentChannel
        }

        function getPalette(): string {
            return Theme.activePalette
        }
    }
}
```

**External hooks (IpcHandler via `qs ipc call`):**
Any process can call into the shell. This is how all external tools
integrate — no special protocol, just command-line calls:

```fish
# From Fish prompt, Kakoune command, garden-daemon, Nyxt Lisp, anywhere:
qs ipc call garden switchPalette kinu
qs ipc call garden suppressNotifications true
qs ipc call garden focusStart research
qs ipc call garden getChannel          # returns "research"

# Super Productivity focus session integration:
qs ipc call garden focusStart writing
# ... work happens ...
qs ipc call garden focusEnd writing
```

Every service with an IpcHandler automatically gets a CLI API.
`qs ipc show` lists all registered targets and their functions.

**Data streaming (Process + SplitParser):**
For continuous data feeds, Quickshell's Process runs an external
command and SplitParser reads newline-delimited output reactively:

```qml
// services/DaemonBridge.qml — consumes garden-ctl watch --json
Process {
    id: daemonWatch
    command: ["garden-ctl", "watch", "--json"]
    running: true
    stdout: SplitParser {
        onRead: data => {
            var event = JSON.parse(data)
            switch (event.type) {
                case "ConnectionEstablished":
                    hookService.connectionChanged(event.host, "up")
                    break
                case "ConnectionLost":
                    hookService.connectionChanged(event.host, "down")
                    break
                case "JobCompleted":
                    notificationService.show(
                        "garden", "Job " + event.id + " completed")
                    break
            }
        }
    }
}
```

This is how the shell receives events from `garden-daemon` without
polling — a persistent streaming process that emits QML signals.

### Mode System

Modes are composable behavior stacks assigned per channel, replacing
the simpler `barMode` config. Each mode is a named bundle that only
touches its own concern:

```nix
channels.studio = {
  modes = ["minimal-bar" "suppress-notifications"];
  pages = { ... };
};
channels.research = {
  modes = ["full-bar" "connection-health" "mpris-ambient"];
  pages = { ... };
};
channels.writing = {
  modes = ["standard-bar" "suppress-notifications"];
  pages = { ... };
};
```

Available modes (extensible):
```
minimal-bar           → bar collapses to 2px line
standard-bar          → bar at 30px, clock only
full-bar              → bar at 34px, all metrics
suppress-notifications → queue silently, dot indicator
connection-health     → show SSH health dots in bar
mpris-ambient         → show track title in bar
focus-active          → channel name in accent (auto-set by focus session)
```

Modes compose: `["minimal-bar", "mpris-ambient"]` gives a 2px bar
that expands to show the track title on hover. Modes can be toggled
at runtime via IPC: `qs ipc call garden toggleMode suppress-notifications`.

### Launcher Disambiguation

When a query matches multiple sources (e.g. "obsidian" matches both
an app and a page), results appear categorized with source labels:

```
obsidian                    writing:obsidian   page
Obsidian                    application        app
```

If the match is already running as a page, that result ranks first
(navigating to an open window is more likely than launching a duplicate).
Each result shows its source in `text-4`. The system makes a smart
default but shows all options.

### Slow Launcher Sources

Local sources (apps, channels, clipboard, calc) return instantly.
Slow sources (Garden block search, garden-ctl queries) appear
asynchronously — results slide in when ready. No loading spinner,
no blocking. The launcher shows what it knows immediately and adds
more when it learns more.

### Dev Mode

Global toggle only: `qs ipc call garden devMode true`
Outlines all component bounding boxes. Useful during shell development.
Per-component granularity deferred — not needed for v1.

### No Describe Mode (v1)

Introspection panel deferred. The IPC system partially fills this
role — `qs ipc show` lists all targets, and `qs ipc prop get`
reads property values. A visual inspector can be added later if needed.

### No Chord Keybinds (v1)

Keybinds are modifier+key only (Super+Tab, Alt+G, etc.). Niri
doesn't natively support chord sequences, and the current keybind
set has no conflicts requiring chords. Can be added later via a
Quickshell state machine if needed.

---

## 13. Quickshell File Structure

```
~/.config/quickshell/garden/
  shell.qml                  # root — ShellRoot with Variants per screen
  Theme.qml                  # palette singleton (reads palettes.json)
  config/
    palettes.json             # all palettes (source of truth)
    settings.json             # keybinds, prefs, channel modes
  components/
    Bar.qml                   # main bar container
    BarChannel.qml            # channel tab with page dots
    BarDot.qml                # inactive channel dot
    BarHostIndicator.qml      # remote host + tier color
    BarConnectionDots.qml     # SSH health squares
    BarMpris.qml              # ambient track title
    Notifications.qml         # context-aware notification stack
    Launcher.qml              # universal command palette
    LauncherResult.qml        # categorized result row
    ChannelSwitcher.qml       # workspace topology overlay
    DitherOverlay.qml         # PC-98 dithered backdrop
    DesktopClock.qml          # always-visible large clock
    LockScreen.qml            # lock with dithered texture
    OSD.qml                   # volume/brightness bar
    PowerMenu.qml             # horizontal text options
    Calendar.qml              # CalDAV read-only grid
    ClipboardHistory.qml      # launcher extension
    MediaControls.qml         # MPRIS scratchpad
    NetworkPanel.qml          # text-based network info
    TrayPanel.qml             # text dropdown tray
    Tooltip.qml               # base-raised tooltip card
    settings/
      SettingsPanel.qml       # unified settings window
      PaletteEditor.qml       # 13-role hex editor
      PaletteCreator.qml      # fork → name → icon flow
      KeybindEditor.qml       # flat list with capture
      KeybindCapture.qml      # key combo input
      HexInput.qml            # validated hex color input
      MiniPreview.qml         # live palette preview
  services/
    HookService.qml           # signals + IpcHandler (external API)
    DaemonBridge.qml          # garden-ctl watch --json consumer
    CompositorService.qml     # abstract compositor interface
    NiriAdapter.qml           # Niri IPC via $NIRI_SOCKET event stream
    ScratchpadService.qml     # floating window toggle via niri msg
    HostDetector.qml          # window title → host tier (compositor-agnostic)
    AudioService.qml          # PipeWire volume/mute
    BrightnessService.qml     # backlight control
    NetworkService.qml        # connection state
    MprisService.qml          # media player state
    NotificationService.qml   # D-Bus notification server
    ClockService.qml          # time + date
    KeybindService.qml        # keybind dispatch
    ConfigService.qml         # settings.json read/write
    CalendarService.qml       # CalDAV fetch + cache
    ScreenshotService.qml     # screenshot capture
    RecordingService.qml      # screen recording state
    ClipboardService.qml      # clipboard history
    ModeService.qml           # per-channel mode stacks
  sources/
    AppSource.qml             # desktop entry search
    CommandSource.qml         # shell commands
    ChannelSource.qml         # channel/page navigation
    ClipboardSource.qml       # clipboard entries
    CalcSource.qml            # inline calculator
```

---

## 13. Terminal Stack — Kitty + Fish + Kakoune

The terminal is where you spend the majority of your time. These tools
are chosen for alignment with Garden's design philosophy: honest, quiet,
composable, and deeply configurable.

### Tool Choices

**Kitty** (terminal emulator) — GPU-accelerated, Wayland-native, mature
(since 2017). Native image protocol used by yazi for previews and chafa
for inline pixel art. `kitten ssh` provides automatic shell integration
on remote machines (Frontier/DGX). Runs in single-window mode (no
internal tabs — Niri's columns are your tabs). Battle-tested stability
balances the risk of running Niri as a newer compositor.

**Fish** (shell) — opinionated defaults that prioritize daily usability.
Autosuggestions, syntax highlighting, man-page completions — all built in.
Bash-compatible enough for agent workflows (`bash -c "..."` works cleanly).
Not a different paradigm (like Nushell) — a better version of the same one.

**Kakoune** (editor) — "select then act" interaction model. Structurally
honest: you always see the selection before operating. Composable in the
Unix sense — delegates to external tools. Client-server architecture allows
multiple windows into the same editing session across pages. Helix retained
as backup for when immediate productivity matters.

### The ✧ Prompt

The prompt character is `✧` (white four-pointed star, U+2727). A small
warm light at the start of every command. Chosen for:
- Quiet presence — visible but not attention-seeking
- Queer/trans resonance — stars as markers for those who exist outside
  categories, points of light in liminal space
- Visual beauty — warm cream (text-1) on dark blue-slate (base) reads
  as a star on a night sky
- Personal meaning — a character chosen with intention, not defaulted to

### Prompt Layout (Fish)

Two lines. Information above, input below. Right-aligned Garden context.

**Local, in git repo:**
```
~/autoresearch main·3                                      research:helix
✧
```

**Remote (SSH to Frontier):**
```
~/experiments main·1                            frontier-login01 research:frontier
✧
```

**Minimal (home directory, no git, local):**
```
~
✧
```

### Prompt Color States

The ✧ glyph stays constant. Only its color changes:
```
text-1 (cream)    — normal state, local shell
urgent (red)      — last command failed (non-zero exit)
accent (gold)     — inside nix develop / nix shell
ok (green)        — inside Python venv or special environment
```

### Information Line Components

**Left side (always visible):**
- Directory path: abbreviated, 2 full-length trailing dirs (`text-3`)
- Git branch + dirty count: `main·3` means branch "main", 3 changes (`text-4`)
- Only shown when in a git repo

**Right side (contextual):**
- Hostname: only when SSH'd, in host tier color (urgent/accent/ok)
- Garden channel:page: in `text-4` (very faint), only when detectable
  via Niri workspace name

**Not shown (the bar handles these):**
- Username (you know who you are)
- Local hostname (the bar tells you when you're remote)
- Current time (the bar has it)
- Shell name, terminal name

### Garden Channel Integration via Fish

Fish reads the current Niri workspace to set environment variables:

```fish
# conf.d/garden-channel.fish
function __garden_update_channel --on-event fish_prompt
    if command -q niri
        set -l ws (niri msg -j focused-window 2>/dev/null | jq -r '.workspace_name // empty' 2>/dev/null)
        if test -n "$ws"
            set -gx GARDEN_CHANNEL $ws
        end
        set -l title (niri msg -j focused-window 2>/dev/null | jq -r '.title // empty' 2>/dev/null)
        if test -n "$title"
            set -gx GARDEN_PAGE $title
        end
    end
end
```

This enables:
- **Channel:page in prompt** — right-aligned context indicator
- **Channel-specific abbreviations** — `sq` expands to full `squeue`
  command in research channel, `sc` starts SuperCollider in music channel
- **Channel-specific PATH** — ORNL tools in research, audio tools in music
- **Channel-specific environment** — SLURM_ACCOUNT, CUDA_VISIBLE_DEVICES
- **Channel-aware greeting** — research channel shows `garden-ctl` summary,
  studio channel shows nothing
- **Channel-aware `garden-ctl`** — `garden-ctl connect` without arguments
  connects to the channel's primary host

The terminal participates in the channel system. The Are.na metaphor extends
all the way down: the channel shapes windows, prompts, abbreviations, and
environment.

### Kitty Configuration

```conf
# Garden palette — mokume (generated from palettes.json)
# ~/.config/kitty/kitty.conf

background #2c3444
foreground #d4c5a9
cursor     #d4c5a9
cursor_shape beam
selection_background #3d4759
selection_foreground #d4c5a9

# ANSI 16 — mapped to Garden semantic roles
color0  #252d3b    # base-deep (black)
color1  #c4796b    # urgent (red)
color2  #7c9a7c    # ok (green)
color3  #c9b88c    # accent (yellow)
color4  #6b7a8d    # text-3 (blue)
color5  #8b7a8d    # muted purple
color6  #6b8a8d    # muted cyan
color7  #8b9bb0    # text-2 (white)
color8  #505e70    # text-4 (bright black)
color9  #c4796b    # urgent (bright red)
color10 #7c9a7c    # ok (bright green)
color11 #c9b88c    # accent (bright yellow)
color12 #8b9bb0    # text-2 (bright blue)
color13 #9b8a9d    # lighter purple
color14 #7b9a9d    # lighter cyan
color15 #d4c5a9    # text-1 (bright white)

# Typography
font_family      IBM Plex Mono
font_size        13.0
modify_font cell_height 120%

# Window — no decoration, Niri handles borders
hide_window_decorations yes
window_padding_width 12 16 12 16

# Behavior
confirm_os_window_close 0
copy_on_select clipboard
mouse_hide_wait 3.0

# Kitty-specific features useful for Garden
# Image protocol (used by yazi, chafa for pixel art previews)
# enabled by default — no config needed

# kitten ssh for remote machine shell integration
# Usage: kitten ssh frontier (instead of ssh frontier)
# Automatically copies shell config to remote
```

Key choices:
- `hide_window_decorations yes` — Niri handles window borders via window rules
- Padding (12px top/bottom, 16px left/right) gives text breathing room
- `cursor_shape beam` — thin line matching launcher/settings input cursors
- `modify_font cell_height 120%` — improves readability at muted gray tones
- ANSI colors map to semantic roles: red=urgent, green=ok, yellow=accent
- Kitty image protocol: native support for yazi previews and chafa inline images
- `kitten ssh`: automatic shell integration on remote machines (Frontier/DGX)

### Fish Theme

```fish
# conf.d/garden-theme.fish (generated from palettes.json)

# Prompt colors
set -U fish_color_cwd          6b7a8d   # text-3
set -U fish_color_cwd_root     c4796b   # urgent
set -U fish_color_prompt       d4c5a9   # text-1 (the ✧)
set -U fish_color_error        c4796b   # urgent (✧ on failed command)

# Syntax colors
set -U fish_color_command      8b9bb0   # text-2
set -U fish_color_param        6b7a8d   # text-3
set -U fish_color_quote        c9b88c   # accent
set -U fish_color_string       7c9a7c   # ok
set -U fish_color_comment      505e70   # text-4
set -U fish_color_operator     6b7a8d   # text-3
set -U fish_color_redirection  6b7a8d   # text-3
set -U fish_color_end          6b7a8d   # text-3
set -U fish_color_escape       c9b88c   # accent

# UI colors
set -U fish_color_autosuggestion  505e70   # text-4 (ghost text)
set -U fish_color_selection       3d4759   # base-hl
set -U fish_color_search_match    3d4759   # base-hl
set -U fish_color_cancel          c4796b   # urgent

# Pager (tab completion menu)
set -U fish_pager_color_prefix      d4c5a9  # text-1
set -U fish_pager_color_completion  8b9bb0  # text-2
set -U fish_pager_color_description 6b7a8d  # text-3
set -U fish_pager_color_selected_background 3d4759  # base-hl
```

Autosuggestions in `text-4` — ghost text barely visible, there when
you look, invisible when you don't. Tab completion pager uses the same
`base-hl` selection highlight as the launcher and bar.

### Kakoune Theme

```kak
# garden.kak — mokume (generated from palettes.json)

# UI
face global Default            rgb:8b9bb0,rgb:2c3444    # text-2 on base
face global StatusLine         rgb:6b7a8d,rgb:252d3b    # text-3 on base-deep
face global StatusLineMode     rgb:d4c5a9,rgb:252d3b    # text-1 on base-deep
face global StatusLineInfo     rgb:505e70,rgb:252d3b    # text-4 on base-deep
face global StatusLineValue    rgb:c9b88c,rgb:252d3b    # accent on base-deep
face global StatusCursor       rgb:252d3b,rgb:d4c5a9    # inverted
face global Prompt             rgb:c9b88c,rgb:252d3b    # accent on base-deep
face global MenuForeground     rgb:d4c5a9,rgb:3d4759    # text-1 on base-hl
face global MenuBackground     rgb:8b9bb0,rgb:343d4f    # text-2 on base-raised
face global Information        rgb:8b9bb0,rgb:343d4f    # text-2 on base-raised
face global Error              rgb:c4796b,rgb:2c3444    # urgent on base

# Selections — select-then-act is visible but not loud
face global PrimarySelection   default,rgb:3d4759+g     # base-hl
face global SecondarySelection default,rgb:343d4f+g     # base-raised
face global PrimaryCursor      rgb:252d3b,rgb:d4c5a9    # inverted
face global SecondaryCursor    rgb:252d3b,rgb:8b9bb0    # dimmer

# Line numbers
face global LineNumbers        rgb:505e70               # text-4
face global LineNumberCursor   rgb:6b7a8d               # text-3
face global LineNumbersWrapped rgb:3a4456               # border-sub

# Matching & whitespace
face global MatchingChar       rgb:c9b88c+b             # accent bold
face global Whitespace         rgb:3a4456               # border-sub
face global BufferPadding      rgb:3a4456               # border-sub

# Syntax — structure quiet, content prominent
face global value              rgb:c9b88c               # accent
face global type               rgb:8b9bb0               # text-2
face global variable           rgb:d4c5a9               # text-1
face global module             rgb:8b9bb0               # text-2
face global function           rgb:d4c5a9               # text-1
face global string             rgb:7c9a7c               # ok
face global keyword            rgb:6b7a8d               # text-3
face global operator           rgb:6b7a8d               # text-3
face global attribute          rgb:c9b88c               # accent
face global comment            rgb:505e70+i             # text-4 italic
face global documentation      rgb:6b7a8d               # text-3
face global meta               rgb:c9b88c               # accent
face global builtin            rgb:8b9bb0+b             # text-2 bold
```

Key: selections use `base-hl` — the same highlight as the bar's active
page, the launcher's selected item, and Fish's tab completion selection.
The "selected/active" visual treatment is consistent across every surface.
Kakoune's select-then-act model is visible but never loud.

Syntax: keywords and operators are `text-3` (quiet structure), your names
and values are `text-1` (prominent content). This follows the Garden
principle: structure is mechanical, content is alive.

### Generator Pipeline — Terminal Stack

```
palettes.json → kitty/kitty.conf            (terminal palette + settings)
              → fish/garden-theme.fish       (shell colors)
              → fish/fish_prompt.fish        (✧ prompt function)
              → kak/garden.kak              (Kakoune colorscheme)
              → bat/garden.tmTheme          (syntax for bat + delta)
              → lazygit/garden.yml          (git UI theme)
              → btop/garden.theme           (system monitor)
              → yazi/garden.toml            (file manager)
```

---

## 14. Terminal Toolkit

Every tool you look at should speak Garden's visual language. When you
`bat` a file, `lazygit` a repo, `btop` your system, and `yazi` your
filesystem — the colors are the same, selections are always `base-hl`,
errors are always `urgent`, success is always `ok`.

### Essential (install from day one)

**ripgrep (`rg`)** — recursive search. Fast, respects `.gitignore`,
colored output adapts to terminal palette. Non-negotiable.

**fd** — find files. Sane defaults, respects `.gitignore`, Rust-native.
Replaces `find` for daily use.

**bat** — view files with syntax highlighting. Accepts custom themes —
a Garden `.tmTheme` means every `bat` invocation matches Kakoune's
syntax colors. Also used as the syntax engine by delta. Replaces `cat`
for anything with structure.

**delta** — git diff pager. Syntax-highlighted, side-by-side capable.
Additions in `ok` green, deletions in `urgent` red — the same semantic
colors as SLURM job states and host tier indicators. Configure as git's
default pager:
```gitconfig
[core]
    pager = delta
[delta]
    syntax-theme = garden
    line-numbers = true
    side-by-side = false
```

**zoxide (`z`)** — smart `cd`. Learns most-visited directories. `z auto`
from anywhere jumps to `~/autoresearch`. Pairs with Fish autosuggestions:
type `z re` and Fish suggests `z research` from history. Replaces `cd`
for known paths.

**jq** — JSON processing. Essential for parsing `garden-ctl` output,
SLURM JSON, API responses, experiment configs. Non-negotiable.

**yazi** — terminal file manager. Rust, fast, image preview via Kitty
protocol (Kitty supports this), vim keybindings, themeable. Feels like
a Garden channel browser for the local filesystem. Preview pixel art,
PDFs, markdown — all without leaving the terminal. Configure to open
files in Kakoune.

### Recommended (install when needed)

**lazygit** — interactive git TUI. Staging, branching, rebasing, visual
diffs. Themeable — Garden lazygit theme gives it the same palette as
everything else. Could live as a scratchpad float:
```
Alt + V    → toggle lazygit scratchpad (with dithered backdrop)
```
Particularly useful for autoresearch where you're managing experiment
code across branches.

**btop** — system monitor. Fully themeable, Garden btop theme generated
from palette. Lives as a page in the `system` channel (`system:monitor`).
For local machine health — the Ratatui control plane handles Frontier/DGX.

**fzf** or **skim (`sk`)** — fuzzy finder. Integrates with Fish for
history search (Ctrl+R), file picking, and Kakoune file navigation.
skim is the Rust alternative; either works. Colors from terminal palette.

**glow** — Markdown rendering in terminal. By Charm. Useful for reading
docs, READMEs, your own notes without opening Obsidian. Respects
terminal colors.

**xh** — HTTP client (Rust, HTTPie-like). Cleaner output than curl,
colored by terminal palette. For testing Garden app API, Nyxt IPC,
web services.

**jless** — interactive JSON explorer. For navigating complex structures:
experiment configs, SLURM job details, metrics dumps. Tree-view with
folding, search, and terminal-palette colors.

**chafa** — terminal image rendering via Kitty protocol. Preview pixel
art exports, Garden image blocks, screenshots — all inline in the
terminal. Yazi uses this for its previews.

**presenterm** — terminal presentation tool. Renders Markdown slides.
Themeable. For presenting research without leaving the terminal.

### Remote Only

**tmux** — session persistence on Frontier, DGX, and homelab.

No local multiplexer. Garden Shell's channel/page model already provides
workspace organization; Niri's scrollable tiling handles side-by-side
views naturally (just scroll to see both columns). A local
multiplexer would add a competing layer of window management — exactly
the redundancy Garden's philosophy rejects.

Remote tmux is essential: when SSH connections drop, long-running
processes (training runs, evaluation suites) must survive independently
of your local machine. The `garden-daemon`'s `RemoteExecutor` wraps
long-running remote commands in tmux sessions automatically:
```
ssh frontier "tmux new-session -d -s train_v3 './run_experiment.sh'"
```

You never type `tmux` manually. The agent infrastructure handles session
creation, monitoring, and reattachment. The Ratatui control plane
(`garden-tui`) shows remote tmux session state alongside SLURM jobs.

tmux on remote machines is infrastructure, not a user-facing tool.

### Tool Selection Principles

Why these tools and not others:

- **Rust-native preferred** — fd, ripgrep, bat, delta, zoxide, yazi, skim,
  xh, jless are all Rust. Consistent with the garden-infra codebase,
  NixOS packaging is clean, performance is excellent.
- **Themeable** — every tool that has visual output accepts a custom
  theme generated from palettes.json. No visual outliers.
- **Composable** — each does one thing. They pipe into each other and
  into Fish. No tool tries to be a platform.
- **Replaceable** — if any tool stops being maintained, the interface
  is generic enough that a replacement slots in. fd could be replaced
  by find, bat by cat+highlight, etc. No lock-in.

### Fish Integration Points

```fish
# conf.d/garden-tools.fish

# Yazi: cd to directory on exit
function y
    set -l tmp (mktemp)
    yazi --cwd-file=$tmp $argv
    set -l cwd (cat $tmp)
    if test -n "$cwd" -a "$cwd" != "$PWD"
        cd $cwd
    end
    rm -f $tmp
end

# Bat as default pager for man pages
set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
set -gx BAT_THEME "garden"

# fzf/skim with Garden colors
set -gx FZF_DEFAULT_OPTS "\
    --color=bg+:#3d4759,bg:#2c3444,spinner:#c9b88c,hl:#c4796b \
    --color=fg:#8b9bb0,header:#6b7a8d,info:#6b7a8d,pointer:#d4c5a9 \
    --color=marker:#c9b88c,fg+:#d4c5a9,prompt:#c9b88c,hl+:#c4796b \
    --color=border:#4a5568 \
    --border --border-label-pos=3"

# Delta as git pager
set -gx GIT_PAGER "delta"

# Zoxide init
zoxide init fish | source

# Long-command notification (>10s commands notify via Garden Shell)
function __garden_notify_on_long_command --on-event fish_postexec
    set -l duration $CMD_DURATION
    if test $duration -gt 10000  # 10 seconds in ms
        set -l seconds (math "$duration / 1000")
        # Send notification via notify-send (Garden Shell picks up)
        notify-send "fish" "Command completed in {$seconds}s: $argv[1]" 2>/dev/null
    end
end
```

---

## 15. Shell Build Order

1. Palette source file (palettes.json)
2. **Kitty + Fish (✧) + Kakoune themes** — live in the colors immediately
3. **Terminal toolkit themes** — bat, delta, fzf, yazi, lazygit, btop
4. Bar (channel-focused, density modes)
5. Notifications (context-aware)
6. Launcher (dithered backdrop, universal command palette)
7. Channel switcher
8. Scratchpad overlay (including lazygit as Alt+V)
9. Volume/brightness OSD
10. Lock screen
11. Desktop clock
12. Power menu
13. Screenshot feedback
14. Settings panel: palette editor
15. Settings panel: keybind remapper
16. Clipboard history, MPRIS, calendar
17. Network/Bluetooth panels
18. Tooltips, launcher extensions

Animations implemented alongside each component (see `03-palette-and-theming.md`).
Infrastructure integration (connection dots, host indicator) depends on
`garden-daemon` — see `04-infrastructure.md`.

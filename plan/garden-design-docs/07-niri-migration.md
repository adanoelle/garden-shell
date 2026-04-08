# Garden Shell — Niri Migration Guide

> Reference document for Claude Code agents updating the Garden design docs
> and codebase from Hyprland to Niri. Read this FIRST, then apply changes
> to the relevant documents.

**Created:** 2026-03-27
**Status:** Decision made, partial updates applied to `02-shell-design.md`

---

## Decision

Garden Shell targets **Niri** as the primary compositor instead of Hyprland.
A compositor abstraction layer (`CompositorService.qml` + `NiriAdapter.qml`)
allows Hyprland fallback if ever needed.

## Why Niri

- **Scrollable-tiling model maps to Are.na channels naturally.** A Niri
  workspace IS a channel, columns on the strip ARE pages. No namespace
  delimiter hack (`name:research:kak`) needed.
- **"Opening a new window never causes existing windows to resize"** —
  structural honesty aligned with Garden's philosophy.
- **Written in Rust** — matches garden-infra codebase.
- **Quickshell has native Niri support** — QML plugin, multiple existing
  shells (Noctalia, DankMaterialShell, iNiR) prove the integration works.
- **Spatial awareness preserved** — neighboring windows accessible by
  scrolling rather than teleporting between workspaces.

## Risks Accepted

- Single maintainer (Ivan Molodetskikh) — mitigated by compositor abstraction
- Scratchpads not native — implemented via floating windows + `niri msg` IPC
- Creative apps (Clip Studio Paint) need xwayland-satellite — integrated
  since Niri 25.08, test before relying on it
- Window border tinting for host awareness may need adaptation — Niri
  window rules handle static borders, dynamic runtime changes need testing

---

## Conceptual Model Change

```
OLD (Hyprland):
  Channel = named workspace prefix (research:*)
  Page = individual named workspace (research:kak)
  Navigation = workspace switching (teleporting)

NEW (Niri):
  Channel = named Niri workspace (vertical axis)
  Page = column on the horizontal strip
  Navigation = scrolling horizontally (spatial, continuous)
```

## Key Mappings

### IPC
```
hyprctl dispatch workspace name:X  →  niri msg action focus-workspace "X"
hyprctl dispatch movetoworkspace   →  niri msg action move-window-to-workspace-down
hyprctl activewindow -j            →  niri msg -j focused-window
hyprctl activeworkspace -j         →  niri msg -j focused-output (then parse workspace)
hyprctl setprop bordercolor        →  Niri window-rule { border { color "..." } }
```

### Config Format
```
Hyprland: hyprland.conf (key=value)
Niri: config.kdl (KDL format)
```

### Named Workspaces
```kdl
// Niri config.kdl
workspace "studio"
workspace "research"
workspace "writing"
workspace "music"
workspace "system"
```

### Navigation Keybinds (in Niri config.kdl)
```kdl
binds {
    Mod+1 { focus-workspace "studio"; }
    Mod+2 { focus-workspace "research"; }
    Mod+3 { focus-workspace "writing"; }
    Mod+4 { focus-workspace "music"; }
    Mod+5 { focus-workspace "system"; }
    Mod+H { focus-column-left; }
    Mod+L { focus-column-right; }
    Mod+N { spawn "kitty"; }  // new column (opens new window)
    Mod+Shift+Q { close-window; }
}
```

### Window Rules for Host Tier Border Colors
```kdl
// Example: SSH windows to Frontier get urgent-colored border
window-rule {
    match title=r#"frontier"#
    border { active-color "#c4796b"; }
}
```

---

## Quickshell Service Changes

### Remove
- `HyprlandService.qml` — replaced by compositor abstraction

### Add
- `CompositorService.qml` — abstract interface for workspace/window queries
- `NiriAdapter.qml` — connects to `$NIRI_SOCKET`, sends "EventStream",
  parses JSON events for workspace/window state changes. Reference
  implementations: iNiR's NiriService.qml, Noctalia's CompositorService
- `ScratchpadService.qml` — manages floating window toggle via `niri msg`

### Modify
- `HostDetector.qml` — already compositor-agnostic (window title matching),
  but update any compositor-specific window query calls
- `HookService.qml` — update `switchChannel` to use `niri msg` instead of
  `hyprctl dispatch`

### NiriAdapter.qml Pattern
```qml
// Connect to Niri event stream
Socket {
    path: Qt.env("NIRI_SOCKET")
    onConnected: write("EventStream\n")
}
// Or use Process:
Process {
    command: ["niri", "msg", "event-stream"]
    stdout: SplitParser {
        onRead: data => handleNiriEvent(JSON.parse(data))
    }
}
```

---

## Fish Shell Changes

### Channel Detection
```fish
# OLD (Hyprland)
hyprctl activeworkspace -j | jq -r '.name'
# then parse "research:kak" by splitting on ":"

# NEW (Niri)
niri msg -j focused-output | jq -r '.workspaces[] | select(.is_focused) | .name'
# returns "research" directly — no parsing needed
```

### GARDEN_CHANNEL Variable
```fish
function __garden_update_channel --on-event fish_prompt
    if command -q niri
        set -l ws (niri msg -j focused-output 2>/dev/null | jq -r '.workspaces[] | select(.is_focused) | .name // empty' 2>/dev/null)
        if test -n "$ws"
            set -gx GARDEN_CHANNEL $ws
        end
    end
end
```

---

## NixOS Configuration Changes

### Module
```nix
# Instead of Hyprland module:
programs.niri.enable = true;
# Or use niri-flake:
inputs.niri.url = "github:sodiboo/niri-flake";
```

### Garden Shell NixOS Config
Replace `gardenShell.hyprland.*` references with `gardenShell.niri.*`.
Channel definitions change from `barMode` (already updated to `modes`)
to workspace definitions that generate both `config.kdl` entries and
Quickshell mode configuration.

---

## Documents Requiring Updates

### Already Partially Updated (2026-03-27)
- `02-shell-design.md` — workspace model, navigation, bar, channel
  switcher, scratchpads, services list, Fish detection, lock screen text,
  keybind layer badges. Some minor Hyprland refs may remain in the
  extension architecture section.

### Need Full Review
- `03-palette-and-theming.md` — one reference updated (Tier 4 containment).
  Check NixOS config section for any Hyprland-specific config syntax.
- `04-infrastructure.md` — SSH host detection references window title
  matching (compositor-agnostic) but may mention Hyprland in passing.
  Update NixOS integration section.
- `05-nyxt-and-curation.md` — one reference to "Hyprland IPC" in the
  IPC architecture section (line ~198). Change to "compositor IPC" or
  "Niri IPC via niri msg".
- `06-open-questions.md` — add Niri migration to decision log. May have
  Hyprland references in resolved decisions.
- `00-overview.md` — update repository descriptions if they mention
  Hyprland specifically.

### Search Pattern
Run `grep -rn "Hyprland\|hyprland\|hyprctl\|Hyprland" *.md` across all
docs and update each reference. Most should become "Niri" or
"compositor" (for agnostic references).

---

## New Niri-Specific Features to Explore

- **Tabbed columns** — multiple windows as tabs within one column.
  Could replace some scratchpad use cases.
- **Overview** — Niri's built-in overview (all workspaces + windows).
  Could complement or replace the Garden channel switcher.
- **Per-column width presets** — Niri supports preset column widths.
  Useful for defining "narrow terminal" vs "wide editor" defaults.
- **Animations** — Niri has its own animation system in config.kdl.
  Garden's animation philosophy (calm at rest, alive in motion) should
  inform Niri's animation config as well as Quickshell's.

---

## Decision Log Entry

**2026-03-27: Compositor switch — Hyprland → Niri**
- Niri's scrollable-tiling maps to Are.na channels naturally
- Channels = named workspaces (vertical), Pages = columns (horizontal scroll)
- No namespace delimiter hack needed; compositor model = conceptual model
- "Never resize existing windows" = structural honesty
- Rust codebase matches garden-infra ecosystem
- Quickshell Niri plugin proven (Noctalia, DankMaterialShell, iNiR)
- Compositor abstraction layer (CompositorService + NiriAdapter) allows
  Hyprland fallback
- Risks accepted: single maintainer, non-native scratchpads, X11 via
  xwayland-satellite for creative apps

---

## Niri Configuration — Detailed Spec

### Named Workspaces (Channels)

Five permanent named workspaces. Super+1-5 always reaches the same
channel. One dynamic workspace remains at the bottom (Niri default)
as an impromptu scratch space — no keybind assigned, not part of
the channel model.

```kdl
workspace "studio"
workspace "research"
workspace "writing"
workspace "music"
workspace "system"
```

**Channel purposes:**
- **studio** — Aseprite (pixel art, Raven), Clip Studio Paint, Godot.
  Visual creative work. Modes: `minimal-bar`, `suppress-notifications`
- **research** — Kakoune (garden-infra, Garden app), SSH terminals to
  Frontier/DGX, Nyxt for docs. Modes: `full-bar`, `connection-health`
- **writing** — Obsidian (notes, zettelkasten, art education), Typst
  (papers, applications). Modes: `standard-bar`, `suppress-notifications`
- **music** — Ardour (DAW), Strudel (live coding), guitar practice.
  Modes: `minimal-bar`, `mpris-ambient`
- **system** — NixOS config, btop, Super Productivity (planner),
  system admin. Modes: `full-bar`, `connection-health`

No sixth channel by default. If a `browse`/`social` channel becomes
needed for non-research browsing, email, messaging — add it when the
gap is felt in daily use, not speculatively.

### Startup Programs

Principle: **launch what you always need, not what you might need.**
Morning starts quiet — tools warm, but no walls of windows.

```kdl
spawn-at-startup "kitty"        // research: landing terminal
spawn-at-startup "kitty" "-e" "btop"  // system: health monitor
```

```kdl
// Assign startup apps to their workspaces
window-rule {
    match at-startup=true app-id="kitty" title=""
    open-on-workspace "research"
}
window-rule {
    match at-startup=true app-id="kitty" title="btop"
    open-on-workspace "system"
}
```

studio, writing, and music channels start empty — you enter them
with intention when ready. Garden launcher could offer a "warm up"
command (`qs ipc call garden warmChannel studio`) that launches the
channel's configured apps on demand.

### Floating Windows

**Principle:** columns are for work, floats are for tools you use
while working. A float is picking up a tool from your desk, using it,
putting it back. A column is the desk itself.

**Floating (transient, cross-channel):**
- Settings panel (Super+,) — configuration overlay
- All scratchpads — Garden (Alt+G), terminal (Alt+T), music (Alt+M),
  lazygit (Alt+V)
- Color picker / Pigment — floats over content being matched
- Picture-in-picture — reference video while working
- Calculator (if standalone beyond launcher inline)

**Not floating (columns on the strip):**
- All primary work apps (editor, browser, terminal, art tool)
- btop / system monitor
- Super Productivity
- Obsidian, Nyxt, Ardour, Godot

```kdl
// Scratchpad float rules
window-rule {
    match app-id="garden"
    open-floating true
    default-floating-position x=0 y=0 relative-to="center"
}
window-rule {
    match title="scratchpad-terminal"
    open-floating true
    default-floating-position x=0 y=0 relative-to="center"
}
window-rule {
    match app-id="lazygit"
    open-floating true
    default-floating-position x=0 y=0 relative-to="center"
}
```

### Column Width Presets

Niri supports default column widths per app. Set sensible defaults
so windows arrive at the right size without manual resizing.

```kdl
// Terminals: 40% — enough for code, leaves room for neighbors
window-rule {
    match app-id="kitty"
    default-column-width { proportion 0.4; }
}

// Nyxt browser: 70% — comfortable for reading and research
window-rule {
    match app-id="nyxt"
    default-column-width { proportion 0.7; }
}

// Creative apps: full width — maximum canvas
window-rule {
    match app-id=r#"^org\.aseprite"#
    default-column-width { proportion 1.0; }
}
window-rule {
    match app-id="clip-studio-paint"
    default-column-width { proportion 1.0; }
}
window-rule {
    match app-id="godot"
    default-column-width { proportion 1.0; }
}

// Obsidian: 60% — prose needs width but not the full screen
window-rule {
    match app-id="obsidian"
    default-column-width { proportion 0.6; }
}

// btop: 50% — enough for the dashboard layout
window-rule {
    match title="btop"
    default-column-width { proportion 0.5; }
}

// Super Productivity: 60%
window-rule {
    match app-id="superproductivity"
    default-column-width { proportion 0.6; }
}
```

Users can always resize manually or cycle through presets with a
keybind. These defaults mean most windows arrive usable without
adjustment.

### Layout — Gaps and Borders

```kdl
layout {
    gaps 2  // 2px between columns — tight, like Are.na card spacing

    border {
        width 1
        active-color "#4a5568"    // border (mokume)
        inactive-color "#3a4456"  // border-sub (mokume)
    }

    // No rounded corners — structural honesty
    // No focus ring — the 1px border color shift handles focus indication

    // Center focused column by default — keeps active work centered
    // with context visible on either side
    center-focused-column "best-effort"
}
```

**No gaps or minimal gaps.** Windows sit next to each other on the
strip like cards in an Are.na channel. 2px is enough to distinguish
borders without creating visual rivers between content.

**1px borders** using palette `border` (active) and `border-sub`
(inactive). The active window's border is subtly brighter — visible
on inspection, invisible at a glance. This matches the bar's 1px
borders and the overall typographic density.

**No rounded corners.** Structural honesty. Rectangles are the shape
of content.

**`center-focused-column "best-effort"`** — when you scroll to a
column, Niri tries to center it. This keeps your active work in the
middle of the screen with neighboring columns peeking from the edges,
preserving spatial context without demanding attention.

### Animations

Niri's animations should align with Garden's timing hierarchy:
calm at rest, alive in motion, 120-200ms range.

```kdl
animations {
    // Workspace switching (channel change) — 200ms, matches shell
    workspace-switch {
        spring damping-ratio=1.0 stiffness=800 epsilon=0.0001
        // overdamped spring ≈ ease-out at ~200ms
    }

    // Horizontal scrolling (page navigation) — 150ms, fast and direct
    horizontal-view-movement {
        spring damping-ratio=1.0 stiffness=1000 epsilon=0.0001
    }

    // Window open — 150ms fade+scale
    window-open {
        duration-ms 150
        curve "ease-out-expo"
        custom-shader r"
            vec4 open_color(vec3 coords_geo, vec3 size_geo) {
                vec3 coords_tex = niri_geo_to_tex * coords_geo;
                vec4 color = texture2D(niri_tex, coords_tex.st);
                // Simple fade in — no bounce, no overshoot
                color *= niri_clamped_progress;
                return color;
            }
        "
    }

    // Window close — 100ms, faster than open (departure is not a moment)
    window-close {
        duration-ms 100
        curve "ease-in-cubic"
    }

    // Config notification — when config reloads
    config-notification-open-close {
        duration-ms 150
        curve "ease-out-cubic"
    }
}
```

Niri uses spring physics for some animations. Use overdamped springs
(damping-ratio >= 1.0) to avoid bounce — Garden's principle is that
nothing overshoots or oscillates. Movement decelerates into rest.

### Focus and Host Awareness

**Focus-follows-column** — when you scroll, the newly visible column
gets focus. This means scrolling IS navigation, which is Niri's core
UX. But the host indicator in the bar should debounce focus changes
(~100ms) so that scrolling past a Frontier terminal doesn't cause
the host indicator to flicker. Only settled focus updates the indicator.

**Host tier borders** via window rules — SSH terminals matching
hostname patterns get tier-colored borders:

```kdl
// HPC tier (urgent red)
window-rule {
    match title=r#"frontier|andes|summit"#
    border { active-color "#c4796b"; }
}

// GPU tier (accent gold)
window-rule {
    match title=r#"dgx-"#
    border { active-color "#c9b88c"; }
}

// Homelab tier (ok green)
window-rule {
    match title=r#"homelab"#
    border { active-color "#7c9a7c"; }
}
```

Note: these are static window rules matching title patterns. For
dynamic runtime border changes (e.g. when a connection drops), the
bar's host indicator and connection health dots handle the feedback
rather than the window border. This is a pragmatic adaptation — the
bar is the ambient status surface, borders are structural.

### XWayland for Creative Apps

Niri auto-launches xwayland-satellite since v25.08. The only X11 app
in the default channel set is **Clip Studio Paint**. Test it
specifically when setting up the machine. Aseprite and Godot both
have native Wayland support.

If Clip Studio Paint has issues under xwayland-satellite:
- Try `gamescope` as a compatibility layer
- Check window-rule sizing (`default-column-width {}` — empty braces
  let the app pick its own size, which helps some X11 apps)
- File issues upstream with xwayland-satellite if needed

### Niri Overview vs Garden Channel Switcher

Two tools, two purposes. Don't fight the compositor.

**Super+Tab → Garden channel switcher (Quickshell)**
- Dithered PC-98 backdrop, palette colors, Garden typography
- Host annotations, mode context, page names with window titles
- For daily channel navigation — "take me to research"
- Garden's aesthetic lives here

**Super+A → Niri overview (compositor-native)**
- Interactive window management: drag windows between workspaces,
  rearrange column order, resize, reorganize spatially
- Compositor-level power that would be fragile and wrong to rebuild
  in a shell layer — the compositor should manage windows
- For spatial reorganization — "move this terminal to the studio channel"

The overview won't have Garden's dithered backdrop — it's compositor-
rendered, outside Quickshell's control. But it inherits the layout
config (1px borders, 2px gaps, palette border colors) so it already
looks minimal and clean. The overview looks like Niri; the channel
switcher looks like Garden. They don't need to be identical — they
need to be useful for different tasks.

Possible future exploration: a Quickshell layer-shell window at the
bottom layer could provide a dithered background surface that becomes
visible when the overview exposes what's behind windows. This is
speculative and needs testing.

### Niri Tabbed Columns

Niri supports presenting windows within a column as tabs rather than
vertically stacked. This could be useful for:
- Multiple terminals in one column (tab between them rather than scrolling)
- Grouping reference documents alongside the main work window

This is an optional power-user feature. The default column behavior
(single window per column) matches the channel/page model more
naturally. Tabs add a third level of hierarchy (channel → column → tab)
that could create confusion. Explore this after the basic shell is
working — it may be most useful in the research channel where you
often have several terminals.

---

## Bar Design Opportunities — Niri-Specific

These are design options enabled by Niri's scrollable-tiling model
that weren't possible with Hyprland's discrete workspaces. Each
should be evaluated during implementation. Not all should ship —
pick the ones that earn their space.

### Context: The Bar's Role Shift

In Hyprland, the bar did *essential navigation* — page tabs were
the only way to know what existed on invisible workspaces. In Niri,
the compositor provides spatial awareness through scrolling. The bar's
role shifts from *navigation* to *orientation*: where you are, what's
happening, what's nearby.

### Option A: Proportional Column Blocks

Column indicators as proportional rectangles reflecting actual column
width. A full-width Aseprite gets a wide block, a 40% terminal gets
a narrow block. The bar becomes a spatial minimap of the strip's shape.

```
research  ▂▅▂                    ▪frontier  14:32
          kak nyxt terminal
          40% 70%  40%
```

Blocks are 4-6px tall, `base-hl` for focused, `border-sub` for others.
Hover reveals window name in tooltip.

**Pro:** communicates strip shape at a glance, information-dense.
**Con:** might be too abstract, loses readable text labels.

### Option B: Text Labels with Proportional Underlines

Hybrid of text readability and spatial information. Column names
with thin underlines whose width reflects column proportion.

```
research  kak    ●frontier    docs         14:32
          ───    ─────────    ──
```

**Pro:** readable AND spatial, underlines echo Are.na's channel view.
**Con:** more visual elements in the bar, may feel busy.

### Option C: Visible / Off-Screen Distinction

Columns visible on screen appear in `text-2`. Columns scrolled
off-screen appear in `text-4` (faint). Three states mapped to
three visual treatments:

```
research  kak  ●frontier  docs            14:32
          ^^^  ^^^^^^^^^  ~~~~
          focused  visible  off-screen
          text-1   text-2   text-4
```

- **Focused:** `text-1`, bold, `base-hl` background or underline
- **Visible:** `text-2`, normal weight — on screen but not focused
- **Off-screen:** `text-4`, faint — exists on strip but scrolled away

This is information only a scrolling compositor can provide. No other
tiling WM has the concept of "exists but scrolled out of view."

**Pro:** structurally honest (reflects real compositor state), useful
for spatial awareness, quiet (just a color shift).
**Con:** requires tracking Niri's viewport state, adds complexity.

### Option D: Column Count as Channel Weight

Inactive channels show a subscript column count instead of (or
alongside) their dot. Tells you not just "occupied" but "how much."

```
research  kak · frontier · docs    studio₃  writing₁  music₂  system₂    14:32
                                   ↑ subscript count in text-4
```

**Pro:** more information in the same space, helps anticipate what
you'll find when switching channels.
**Con:** might be visual noise, dots are quieter.

### Option E: Scroll Position Indicator

1px line at the bar's bottom edge showing scroll position on the strip.
Like a reading progress bar but for your workspace.

```
research  kak · frontier · docs                               14:32
━━━━━━━━━━━━━━━━━━━━━━▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁▁
                      ↑ you are here on the strip
```

The indicator is `border-sub`, 1px, almost invisible. Moves only
when you deliberately scroll. Settles immediately.

**Pro:** peripheral spatial awareness without looking away from work.
**Con:** might violate "calm at rest" (ambient motion on scroll),
might be too subtle to notice or too subtle to be useful.

### Option F: Channel-Specific Bar Content

Mode system already supports this, but Niri makes it cleaner.
The bar content fully adapts to the channel's purpose:

**music channel (mpris-ambient mode):**
```
music  ◂ II ▸  Autechre — Gantz Graf  0:42/6:38         14:32
```
Column indicators replaced by transport controls + track info.

**system channel (full-bar + connection-health mode):**
```
system  config · monitor · planner    cpu 4%  mem 3.2g  ▪frontier  14:32
```
Inline system metrics.

**research channel:**
```
research  kak · ●frontier · docs      ▪frontier ▪dgx-α   14:32
```
Connection health dots most relevant here.

**writing channel:**
```
writing  obsidian · typst                                 14:32
```
Minimal — just where you are.

**Pro:** each channel's bar shows exactly what matters for that work.
**Con:** inconsistency between channels may be disorienting if you
switch frequently and expect the bar to look the same everywhere.

### Option G: Breathing Bar (Automatic Density)

Bar content density adapts to column count automatically rather than
static per-channel mode config:

- **1 column:** channel name + clock only (minimal)
- **2-3 columns:** channel + column indicators + clock (standard)
- **4+ columns:** everything including metrics and health (full)

The bar *breathes* with your activity level. A single full-screen
Aseprite session gets minimal treatment automatically.

**Pro:** bar always shows the right amount for the situation, no
manual mode configuration needed.
**Con:** opening one window changes the bar layout, which could be
disorienting. Static modes are more honest — you know what to expect.
Unpredictable behavior conflicts with structural honesty.

### Option H: Column Order Matches Strip

The spatial order of column indicators in the bar matches the
physical order of columns on the strip. If you scroll right to go
from kak → frontier → docs, the bar shows them left-to-right in
that order. The bar is a top-down view of your strip.

If you rearrange columns on the strip (via Niri overview drag), the
bar reorders to match.

**Pro:** structural honesty — the bar never lies about spatial layout.
**Con:** should be the default anyway. Only noting this to make the
commitment explicit. Non-negotiable.

### Recommendation for v1

Start with a conservative base and add features as you use them:

1. **Option H (spatial order) — yes, always.** Non-negotiable.
2. **Option C (visible/off-screen distinction) — try it.** The most
   Garden-aligned Niri opportunity. Remove if too noisy in practice.
3. **Option F (channel-specific content) — yes, via modes.** Already
   designed, just implement.
4. **Text labels (not proportional blocks) — for v1.** Readable
   column names are more immediately useful than abstract shapes.
5. **Options A, B, D, E, G — defer.** Evaluate after daily-driving
   the basic bar. Some may prove unnecessary, some may become obvious.

### Focus Behavior

Column indicators **snap discretely** to the focused column rather
than scrolling continuously during mid-scroll. Focus debounce of
~100ms prevents the host indicator from flickering when scrolling
past remote terminals. The bar updates when focus *settles*, not
while it's in motion. Calm at rest.

### NiriAdapter Events for Bar

The bar subscribes to these Niri events:
- `WorkspaceActivated` — channel changed
- `WorkspacesChanged` — channel list updated
- `WindowFocusChanged` — active column changed
- `WindowOpenedOrChanged` — column list / titles updated
- `WindowClosed` — column removed from strip

The adapter debounces rapid events (window open flurry on startup)
and exposes clean reactive properties:

```qml
// NiriAdapter exposes:
property string activeWorkspace: "research"
property var columns: [
    { id: "...", title: "kak", appId: "kitty", focused: true, visible: true },
    { id: "...", title: "frontier", appId: "kitty", focused: false, visible: true },
    { id: "...", title: "docs", appId: "nyxt", focused: false, visible: false },
]
property var workspaces: [
    { name: "studio", columnCount: 3, active: false },
    { name: "research", columnCount: 3, active: true },
    { name: "writing", columnCount: 1, active: false },
    { name: "music", columnCount: 0, active: false },
    { name: "system", columnCount: 2, active: false },
]
```

The Bar component binds to these properties. When they change,
the bar updates automatically via QML reactive bindings.

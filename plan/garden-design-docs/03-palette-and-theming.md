# Garden — Palette, Theming & Animation

> Color system, typography, animation vocabulary, and the app theming
> pipeline that keeps the entire ecosystem visually unified.

**Last updated:** 2026-03-12
**Related docs:** `01-design-philosophy.md`, `02-shell-design.md`

---

## 1. Palette Structure — 13 Semantic Roles

Every palette defines exactly these roles:

```
SURFACES (4):
  base-deep    — recessed: bar background, code blocks
  base         — primary background: desktop, window areas
  base-raised  — elevated: notification cards, floating panels
  base-hl      — highlighted: selected items, hover states

BORDERS (2):
  border-sub   — subtle dividers, secondary separation
  border       — primary dividers, card outlines

TEXT (4):
  text-4       — faintest: hints, disabled states
  text-3       — muted: metadata, labels, inactive items
  text-2       — secondary: body text, descriptions
  text-1       — primary: headings, active items, clock

SEMANTIC (3):
  accent       — interactive, used sparingly (gold family)
  urgent       — alerts, remote SSH indicators (earthy red family)
  ok           — success, running states (muted green family)
```

---

## 2. Four Built-In Palettes

### Mokume ◐ (dark — hague blue × warm cream)
Default. Cool blue-slate base with warm cream text.
```
base-deep: #252d3b    base: #2c3444    base-raised: #343d4f    base-hl: #3d4759
border-sub: #3a4456   border: #4a5568
text-4: #505e70       text-3: #6b7a8d  text-2: #8b9bb0        text-1: #d4c5a9
accent: #c9b88c       urgent: #c4796b  ok: #7c9a7c
```

### Sumi ● (neutral — charcoal ink × amber)
Hueless gray. For color-critical work (pixel art, drawing).
```
base-deep: #222222    base: #282828    base-raised: #313131    base-hl: #3a3a3a
border-sub: #383838   border: #484848
text-4: #545450       text-3: #706f68  text-2: #9a9a8e        text-1: #d4c4a0
accent: #c2a86a       urgent: #bf7565  ok: #7a9470
```

### Kinu ○ (light — raw silk × dark walnut)
Warm light mode. For daylight, reading, writing.
```
base-deep: #ddd5c8    base: #e8e0d4    base-raised: #f0e9de    base-hl: #d8d0c2
border-sub: #d0c6b6   border: #c4b9a8
text-4: #a8a094       text-3: #8a8278  text-2: #5c554c        text-1: #2c2620
accent: #8a7440       urgent: #a85a48  ok: #5a7a52
```

### Yoru ◑ (night — no blue light × deep amber)
Zero blue emission. For late-night sessions.
```
base-deep: #221a14    base: #281e18    base-raised: #302520    base-hl: #3a2e28
border-sub: #3c322c   border: #4a3e36
text-4: #5c5044       text-3: #7a6a58  text-2: #a08a6e        text-1: #d4b888
accent: #c4a050       urgent: #c07848  ok: #7a9060
```

---

## 3. Custom Palettes

Users create unlimited custom palettes by forking any existing one. Each has:
- Name (material convention: "sakura", "forest", "midnight")
- Icon glyph: `● ○ ◐ ◑ ◒ ◓ ◔ ◕ ◖ ◗ ◦ ◌ ◎`
- Subtitle (e.g. "warm — cherry blossom dusk")
- All 13 color roles
- `forked_from` reference

Operations: rename, duplicate, delete (built-ins reset only), export/import JSON.

### Persistence: `~/.config/garden/palettes.json`
```json
{
  "active": "mokume",
  "palettes": {
    "mokume": {
      "name": "mokume", "subtitle": "dark — hague blue × warm cream",
      "icon": "◐", "builtin": true,
      "colors": {
        "base-deep": "#252d3b", "base": "#2c3444",
        "base-raised": "#343d4f", "base-hl": "#3d4759",
        "border-sub": "#3a4456", "border": "#4a5568",
        "text-4": "#505e70", "text-3": "#6b7a8d",
        "text-2": "#8b9bb0", "text-1": "#d4c5a9",
        "accent": "#c9b88c", "urgent": "#c4796b", "ok": "#7c9a7c"
      }
    },
    "sakura": {
      "name": "sakura", "subtitle": "custom — cherry blossom dusk",
      "icon": "◔", "builtin": false, "forked_from": "mokume",
      "colors": { "...": "..." }
    }
  }
}
```

### Palette Switching
- Manual: keybind (Super+Shift+P cycles) or settings panel
- Automatic: yoru at sunset, mokume at sunrise (Knoxville: 35.96°N, 83.92°W)
- Palette is global; bar density is per-channel

---

## 4. Typography

### Fonts
- **UI text:** M PLUS 1p (Latin + Japanese, warm, well-hinted)
- **Monospace:** IBM Plex Mono (clock, metrics, code, metadata)
- **No display/serif font** — hierarchy through size and weight only

### Rules
- One font family per context (sans for UI, mono for data)
- Three sizes max in any component
- Two weights: 400 (regular) and 700 (bold), occasionally 600
- Letter-spacing: 0.02-0.06em on small metadata text
- Differentiation through size, weight, and color — never decoration

---

## 5. Animation System

### Core Principle
Calm at rest, alive in motion. At rest, nothing moves. Animation
exists only to acknowledge actions and smooth transitions.

### Five Motion Primitives
```
fade      — opacity transitions
slide     — translateX/Y, 6-12px max
scale     — 0.97–1.0 range only
collapse  — height shrink/expand
crossfade — color transitions
```

No rotation, skew, 3D transforms, bounce, elastic, or spring physics.

### Easing
- Entrances: `ease-out` (decelerate into rest)
- Exits: `ease-in` (accelerate away)
- Transformations: `ease-in-out`
- Never: `linear` (except notification progress line)

### Timing Hierarchy (more frequent = faster)
```
Page cycling        → 120ms    (underline slides)
Channel switching   → 200ms    (staggered tab entrance, 30ms/tab)
Launcher/switcher   → 150ms    (panel slides up)
Notifications       → 200ms    (slide-in, vertical-compress dismiss)
Bar density change  → 200ms    (two-phase: content fade → height collapse)
Palette switching   → instant  (hard cut, no animation)
Desktop clock enter → 200ms    (staggered digits, 40ms/char)
```

### Key Details
- **Channel switch:** new tabs stagger in like dealt cards; old tabs instant fade.
  Asymmetry: arrival is a moment, departure is not.
- **Page cycle:** only the underline moves. Content swap is instant.
- **Host indicator:** animate only on change; instant when host stays same.
- **Palette switch:** hard cut. No crossfade. Every other tool in the stack
  (Kakoune, Kitty, Fish, GTK) hard-cuts on theme change; the shell does
  not grant itself special cosmetic treatment. This was the one animation
  that existed for aesthetics rather than information — removing it makes
  the system perfectly consistent.
- **Desktop clock:** digits render one at a time (PC-98 / departure board).
  Only on first appearance, not on updates.
- **Notifications dismiss:** vertical compress (height→0) rather than fade.
  Cards above settle down. Resolution, not disappearance.

### At Rest — Nothing Moves
Exceptions only: terminal cursor blink (not ours), notification progress
line (communicates time). No idle animations, no pulsing, no breathing.

### QML Implementation
- `Behavior on [property]` for simple transitions
- `NumberAnimation` / `ColorAnimation` for explicit control
- `SequentialAnimation` for two-phase (bar density)
- Palette switch: direct property assignment, no animation behavior
- All durations configurable for reduced-motion accessibility

---

## 6. Application Theming Strategy

### Goal
Make every app feel like it belongs in the same room. Don't force
uniform appearance on complex apps — shift the chrome, leave functional
colors alone.

### Tiers

**Tier 1 (full control):** Kitty, Fish, Kakoune, Obsidian, Zathura, Nyxt

**Tier 2 (deep control):** Blender (XML theme), Godot (editor theme),
Firefox (userChrome.css fallback), Ardour (theme editor)

**Tier 3 (limited):** Clip Studio Paint, Aseprite

**Tier 4 (containment):** Scratchpad floats with dithered backdrop +
Niri window rules (`border { color ... }`, matched by app-id/title)

**System-wide:** GTK3/4 theme + Qt via Kvantum

### Generator Pipeline

Single source of truth → many outputs:
```
palettes.json → kitty/kitty.conf            (terminal palette + settings)
              → fish/garden-theme.fish       (shell colors)
              → fish/fish_prompt.fish        (✧ prompt function)
              → fish/garden-tools.fish       (fzf colors, env vars)
              → kak/garden.kak              (Kakoune colorscheme)
              → bat/garden.tmTheme          (syntax for bat + delta)
              → lazygit/garden.yml          (git UI theme)
              → btop/garden.theme           (system monitor)
              → yazi/garden.toml            (file manager theme)
              → obsidian/garden.css         (CSS snippet)
              → zathura/gardenrc            (reader colors)
              → garden-theme.lisp           (Nyxt browser)
              → blender/garden.xml          (Blender theme)
              → gtk-3.0/gtk.css             (GTK theme)
              → kvantum/garden.kvconfig     (Qt theme)
              → garden-tui theme            (Ratatui colors)
```

Tweak one color → regenerate everything. NixOS derivation reads
palettes.json, produces all config files.

---

## 7. NixOS Configuration

```nix
gardenShell = {
  palette = "mokume";
  
  channels = {
    studio = {
      modes = ["minimal-bar" "suppress-notifications"];
      pages = {
        clip-studio = { app = "clip-studio-paint"; };
        aseprite    = { app = "aseprite"; };
        godot       = { app = "godot4"; };
      };
    };
    research = {
      modes = ["full-bar" "connection-health"];
      pages = {
        kak      = { app = "kitty -e kak"; };
        frontier = { app = "kitty --title=frontier"; };
        docs     = { app = "nyxt"; };
      };
    };
    writing = {
      modes = ["standard-bar" "suppress-notifications"];
      pages = {
        obsidian = { app = "obsidian"; };
        typst    = { app = "kitty -e kak"; };
      };
    };
    music = {
      modes = ["minimal-bar" "mpris-ambient"];
      pages = {
        ardour  = { app = "ardour"; };
        strudel = { app = "kitty -e kak"; };
      };
    };
    system = {
      modes = ["full-bar" "connection-health"];
      pages = {
        config   = { app = "kitty -e kak"; };
        monitor  = { app = "kitty -e btop"; };
        planner  = { app = "super-productivity"; };
      };
    };
    # ... (writing, music, system)
  };

  scratchpads = {
    garden   = { key = "Alt+G"; app = "garden"; };
    terminal = { key = "Alt+T"; app = "kitty"; };
    music    = { key = "Alt+M"; app = "spotify"; };
    lazygit  = { key = "Alt+V"; app = "kitty -e lazygit"; };
  };
  
  nightMode = {
    enable = true;
    latitude = 35.96;
    longitude = -83.92;
    palette = "yoru";
  };
  
  monitors = {
    "DP-1" = { position = "primary"; };
    "DP-2" = { position = "secondary"; };
  };
};
```

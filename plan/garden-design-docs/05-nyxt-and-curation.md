# Garden — Nyxt Integration & Curation System

> Nyxt browser as a native Garden citizen: theming, curation workflow,
> attention boundaries, and the browse-curate-reflect cycle.

**Last updated:** 2026-03-12
**Related docs:** `01-design-philosophy.md`, `03-palette-and-theming.md`

---

## 1. Why Nyxt

Nyxt is keyboard-driven, configured in Common Lisp, fully introspectable
at runtime, and treats theming as a first-class feature. It can become
a native citizen of Garden Shell — not just themed, but structurally
integrated with the curation workflow and attention protection system.

Nyxt is a **Tier 1** theming target (full control, matches Garden exactly).

---

## 2. Theme Integration

### Base Theme (config.lisp)
```lisp
(define-configuration browser
  ((theme (make-instance 'theme:theme
    :dark-p t
    :font-family "M PLUS 1p"
    :monospace-font-family "IBM Plex Mono"
    :background-color     "#2c3444"  ; base
    :on-background-color  "#8b9bb0"  ; text-2
    :primary-color        "#252d3b"  ; base-deep
    :on-primary-color     "#d4c5a9"  ; text-1
    :secondary-color      "#343d4f"  ; base-raised
    :on-secondary-color   "#8b9bb0"  ; text-2
    :accent-color         "#c9b88c"  ; accent
    :on-accent-color      "#252d3b"  ; base-deep
    ))))
```

### Component Styling
Every Nyxt interface element accepts CSS matching Garden's language:
- Prompt buffer → Garden launcher appearance
- Status buffer → minimal strip or eliminated
- Internal buffers → `base` background, `text-1`/`text-2`/`text-3` hierarchy

### Live Palette Switching
Nyxt supports runtime Lisp re-evaluation. On palette switch:
1. Shell writes active palette to palettes.json
2. Nyxt watches file or receives signal
3. Theme re-evaluates, browser reflows

### Ambient User Stylesheet (Optional)
Harmonizes web interaction surfaces without restyling content:
```css
::selection { background: #c9b88c40; }
:focus-visible { outline: 1px solid #4a5568; }
::-webkit-scrollbar { width: 4px; }
::-webkit-scrollbar-thumb { background: #4a5568; }
```

---

## 3. Curation System — The Quiet Internet

### The Problem
The web captures attention through algorithmic feeds, infinite scroll,
and engagement mechanisms. Garden + Nyxt create a different relationship:
the browser is a foraging tool, Garden is long-term memory.

### Core Principle
Your attention is yours. Every feature either helps you *find what matters*,
*save what matters*, *protect your focus*, or *reconnect with what you saved*.

### The Browse-Curate-Reflect Cycle
```
BROWSE   — open-ended exploration, following links
CURATE   — deliberately saving what matters to Garden
REFLECT  — returning to your collection, finding connections
```

---

## 4. Foraging Mode — Saving to Garden

### Quick Save (Alt+S)
Opens Garden-aware prompt buffer → select channel → page saved as block.
Under 3 seconds. No modal dialogs, no confirmation screens.

Block contains: URL, title, text excerpt (auto or selected), screenshot
thumbnail (optional), tags (optional), timestamp.

### Excerpt Save (select + Alt+S)
If text selected, saves only the selection with source URL. This is
Are.na's core gesture — saving a *piece*, not the whole page.

### Hint-Save Mode (Alt+Shift+S)
Nyxt hint system on all links → type label → link saved without opening.
Power-user curation: scan a page of references, cherry-pick rapidly.

### Auto-Extract Metadata
On save: Open Graph data, publish date, author, site name, primary image.

---

## 5. Reading Mode

Strips web pages to content, renders in Garden's design language:
- Typography: M PLUS 1p body, IBM Plex Mono code
- Colors: current palette
- Layout: single column, generous margins

Text selection + Alt+S saves excerpts inline while reading.
Seamless read-and-collect flow.

---

## 6. Attention Boundaries

### Time Awareness Mode
Persistent timer on configurable domains:
- 0-10 min: no indicator
- 10-20 min: timer in `text-3` (muted)
- 20+ min: timer shifts to `urgent`

Not blocking — makes time visible so you can decide.

### Feed Reduction Mode
For attention-capturing domains, inject CSS/JS to:
- Remove algorithmic feeds and infinite scroll
- Remove autoplay and recommendations
- Show only explicitly navigated content

```nix
gardenShell.nyxt.feedReduction = {
  "twitter.com" = { removeFeed = true; timeLimit = 15; };
  "reddit.com"  = { removeFeed = true; timeLimit = 20; };
  "youtube.com" = { removeAutoplay = true; removeRecommendations = true; };
};
```

### Channel-Linked Focus
- `research` channel: blocker-mode for social media
- `writing` channel: reader mode auto-enabled
- `studio` channel: minimal browser interaction

---

## 7. Connections

After saving a block, prompt offers: "Also connect to:" with suggestions
based on content similarity to existing channels. Blocks can live in
multiple channels. Over time: bookmarks → knowledge graph.

---

## 8. Garden Sidebar Panel

Persistent Nyxt panel buffer showing:
- Recent blocks saved this session
- Current channel's block count
- Quick-search across all Garden blocks

Creates feedback loop: see curation growing → reinforces practice.

---

## 9. Session Awareness

Nyxt buffer sets map to Garden Shell channels:
- In `research` → research buffers visible
- Switch to `writing` → writing buffers (or no browser)
- Switch back → research buffers restored

Browser participates in workspace topology.

---

## 10. The Return Path

Click a web block in Garden app → opens in Nyxt with reader mode +
original context (channel, timestamp, excerpt highlighted).

Browser is both foraging tool and reader for your collection.

---

## 11. IPC Architecture

```
Garden app ↔ Nyxt:
  Local API (HTTP or Unix socket) for:
  - Listing channels, saving blocks, searching, creating connections

Garden Shell ↔ Nyxt:
  Palette sync via file-watch or signal
  Channel-switch coordination via compositor IPC (niri msg)

Garden Shell ↔ Garden app:
  Shared palettes.json
```

---

## 12. Philosophy

The combined effect:
```
BEFORE: open browser → get pulled into feed → lose 45 minutes → guilt
AFTER:  enter channel with intention → browse with focus → save what
        matters → time awareness keeps you grounded → reflect in Garden
        → connections emerge → next session informed by what you know
```

The web becomes a library you visit with purpose.
Your Garden grows. Your attention stays yours.

---

## 13. Custom Garden Commands for Nyxt

- **garden-bookmark** — save URL/excerpt as Garden block with channel selection
- **garden-palette-switch** — re-apply theme from palettes.json at runtime
- **garden-search** — search web + Garden blocks in unified prompt buffer

---

## 14. Nyxt Design Principles → Garden Shell

Six principles ported from Nyxt's architecture to inform all Garden repos:

1. **Introspection** — `describe` command (Super+?) inspects any shell element
2. **Prompt as universal interface** — one launcher reaches all capabilities
3. **Hooks** — named events with attachable handlers (no core modification)
4. **Composable modes** — per-channel behavior stacks
5. **Defaults always accessible** — every value stores user + factory default
6. **Everything is a buffer/block/window** — no special-case UI

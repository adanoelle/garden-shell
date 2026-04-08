# Garden — Design Philosophy

> Read this document first. It frames every decision across all Garden
> repositories. Any contributor or agent should understand these principles
> before writing code.

**Last updated:** 2026-03-12
**Related docs:** All other Garden design documents reference this one.

---

## Core Principle

The shell is a quiet, unified workspace that respects the content inside it.
It does not compete with applications for visual attention. The grid, typography,
and spacing *are* the design — not decoration layered on top.

The content — your code, your art, your research, your writing — provides all
the visual interest and personality. The shell is the room; the work is the life
happening inside it.

---

## Design Lineage: Structural Warmth

Garden Shell shares surface-level traits with Brutalism — structural honesty,
visible grid, no decorative cladding, typography-driven hierarchy, rejection
of cosmetic softening (no blur, no rounded pills, no bounce animations).
But it is **not Brutalist**.

**Brutalism is confrontational.** It celebrates mass, weight, roughness.
It doesn't care about your comfort.

**Garden is inviting.** It prioritizes comfort and daily livability across
8+ hour sessions spanning creative work, research, and writing. The warmth
of the palette, the soft letterforms, the PC-98 dithering as *texture*
rather than rawness — these create intimacy, not confrontation.

### The Shorthand

```
Garden = structural honesty       (from Brutalism)
       + warmth and livability    (from mingei / Ando)
       + typographic hierarchy    (from Are.na / editorial design)
       + material texture         (from PC-98)
       + curated color            (from Farrow & Ball)
       + functional density       (from Braun / Rams)
       − confrontation
       − monumentality
       − deliberate discomfort
       − cosmetic softening
```

**Structural warmth.** Honest but inviting, minimal but not austere,
functional but not cold.

---

## Influences

### Direct Ancestors
- **Garden** (Ada's Tauri app) — the literal visual source; the shell
  should feel like Garden expanded to cover the desktop
- **Are.na** — structural minimalism, blocks-and-channels metaphor,
  typography-only hierarchy, near-absence of color in chrome
- **PC-98 game interfaces** — dithering as material texture, constrained
  palettes, pixel-level intentionality

### What "Minimal" Means in Garden's Vocabulary

It does **not** mean "as little as possible" (Brutalist minimalism).
It means "everything present is intentional and earns its place"
(closer to Japanese *ma* — the meaningful use of negative space).

- The dithered overlay has texture because **texture creates warmth**
- The host indicator has a subtle glow because **safety deserves emphasis**
- The kinu light palette is warm cream, not stark white, because
  **the screen is a space you inhabit, not a document you read**
- The palette has names (mokume, sumi, kinu, yoru) because
  **naming creates relationship with materials**

---

## Artistic References

References organized by what they teach, not what they look like.

### Structure & Emptiness (from manga)

**Tsutomu Nihei (BLAME!, Biomega):**
The rigid manga panel grid containing vast, almost-empty architectural
space. The tension between tight structure and expansive content is exactly
what Garden does: 1px borders and consistent gutters (the panel grid)
surrounding full-screen applications (the vast space). Nihei also alternates
between pages of near-silence and sudden bursts of detail — this maps to
bar density modes (minimal → full).
*Steal: the grid is tight, the content is vast. Let the contrast speak.*

**Yokoyama Yūichi (Travel, Garden, New Engineering):**
"Neo-manga" that deliberately removes the "human body smell" from structure.
Yokoyama uses rulers and templates to eliminate hand-drawn texture in
structural elements while allowing wild energy in content. This is Garden's
philosophy: depersonalized chrome (ruler-precise 1px borders) surrounding
expressive content (live coding output, pixel art, research notes).
*Steal: structure is mechanical and precise; content is alive and human.
Never reverse this.*

### Materials & Containers (from design theory)

**Kenya Hara / Hara Design Institute (Muji art direction):**
Hara's central concept: "emptiness" (空 kū) versus "nothingness."
Emptiness is not the absence of content — it's a container shaped to
receive content. A white cup is empty, not nothing. Garden's neutral chrome
is empty in Hara's sense: shaped to receive your work.
*Steal: design the container's shape, not its contents. The shell is
a vessel, not a painting.*

Essential reading: *Designing Design* and *White* by Kenya Hara.

**Neri Oxman / Material Ecology:**
Materials that *inform* — color, texture, and structure emerge from
material properties rather than surface decoration. Garden's palettes
are named for materials and their colors emerge from material references.
They're not arbitrary color schemes — they're specific material realities
translated into light.
*Steal: name palettes for materials, derive colors from the material
reality. Color is not arbitrary.*

### Habitation & Economy (from art and animation)

**Kazuo Oga / Studio Ghibli background art:**
Backgrounds should be spaces you want to *inhabit*, not just look at.
Every palette, every density mode, every overlay should feel like a space
you want to work in for eight hours, not a space you want to screenshot.
*Steal: the habitation test. If you wouldn't want to work in it for
8 hours, it's wrong.*

**Jockum Nordström:**
Sophistication through simple means. Garden uses only rectangles, 1px
lines, two fonts, and a 13-color palette. The sophistication comes from
composition, not element count.
*Steal: before adding a new element, exhaust the existing vocabulary.*

### Productive Constraint (from print)

**Risograph / letterpress printing community:**
Limited-palette, layered-color medium. Garden's palette structure with
13 semantic roles is a similar productive constraint.
*Steal: constraints are generative. The 13-role limit forces better
decisions than infinite color would.*

### Architecture & Industrial Design

- **Tadao Ando** — exposed concrete with warmth and light
- **Mingei folk craft** — functional beauty, honest materials, daily use
- **Dieter Rams / Braun** — "as little design as possible" with care
- **Nakamichi tape decks** — information-dense but beautifully composed
- **Muji** — precise, restrained, warm materials; emptiness as readiness
- **Farrow & Ball** — curated color with names and material references

### Summary

```
STRUCTURE:    Nihei, Yokoyama    → rigid grid, vast content, depersonalized frame
CONTAINERS:   Hara, Oxman        → emptiness as readiness, material-derived color
HABITATION:   Oga, Nordström     → design for living, sophistication through simplicity
CONSTRAINT:   Riso, letterpress  → limited palettes are generative, not limiting
SYNTHESIS:    Yokoo              → merge traditions structurally, not decoratively
CRAFT:        Ando, mingei, Rams → honest materials, functional beauty, daily use
```

---

## What Not To Do (Anti-Patterns)

These break the Garden aesthetic even if they seem "clean" or "minimal":

- **Don't add stark black/white contrast.** Garden lives in the warm
  middle. Pure #000/#fff is Brutalist territory.
- **Don't use monospace for everything.** Monospace everywhere is a
  hacker trope. Garden uses monospace for data and metadata; sans-serif
  for human-facing text.
- **Don't make elements deliberately uncomfortable.** No tiny click
  targets, no aggressive truncation, no hostile density.
- **Don't add decoration to compensate.** If something feels too sparse,
  the answer is better typography or spacing, not icons or gradients.
- **Don't chase screenshot aesthetics.** Design for 8-hour days, not
  r/unixporn upvotes.
- **Don't use blur.** Dithering is the material. Blur is the absence
  of a material decision. This is a hard rule.
- **Don't use algorithmic color.** No wallpaper extraction, no dynamic
  theming. Palettes are curated by a human, not computed.
- **Don't add idle animations.** At rest, nothing moves. The screen
  should be as still as a printed page.

---

## Design Principles Ported from Nyxt

These architectural principles from the Nyxt browser inform Garden's
system design across all repositories:

1. **Introspection** — the system describes itself. Every element can be
   inspected for its role, configuration, and current state.
2. **The prompt as universal interface** — one text interface (the launcher)
   reaches every capability.
3. **Hooks as extension points** — named events that users can attach
   handlers to without modifying core code.
4. **Modes as composable behavior** — per-channel behavior stacks that
   compose cleanly.
5. **Defaults always accessible** — every configurable value stores both
   the user's value and the factory default. Nothing is ever lost.
6. **Everything is a buffer/block/window** — no special-case UI. Every
   interface surface is built from the same components and styled by
   the same theme.

# The color system

> Every Garden palette defines exactly 13 semantic color roles — no more, no
> less.

## The 13 roles

Garden doesn't use raw ANSI color slots. Instead, every palette defines 13
named roles grouped into four categories. Theme generators map these roles to
whatever format each target application needs.

| Group | Role | Purpose |
|-------|------|---------|
| **Surfaces** | `base-deep` | Deepest background — recessed areas, gutters |
| | `base` | Primary background — the default canvas |
| | `base-raised` | Raised surface — cards, floating panels |
| | `base-hl` | Highlighted surface — selections, hover states |
| **Borders** | `border-sub` | Subtle border — separators, low-emphasis dividers |
| | `border` | Primary border — window frames, prominent dividers |
| **Text** | `text-4` | Faintest — disabled labels, ghost suggestions, comments |
| | `text-3` | Muted — secondary labels, placeholders, keywords |
| | `text-2` | Secondary — body copy, parameters, default terminal text |
| | `text-1` | Primary — headings, commands, high-emphasis content |
| **Semantic** | `accent` | Quoted strings, links, active indicators |
| | `urgent` | Errors, destructive actions, critical alerts |
| | `ok` | Success states, confirmations, healthy indicators |

The groups form a hierarchy. Surfaces provide depth (deep → raised). Text
provides emphasis (faint → primary). Borders sit between surfaces and text in
visual weight. Semantic colors carry meaning regardless of context.

## Design rationale

### Why not ANSI-16?

ANSI's 16 color slots are positional, not semantic. "Color 4" means blue in most
schemes, but that's convention, not contract. When you map a palette to ANSI
slots, you're forced to decide what "blue" means in your design system — is it
accent? Is it informational? The answer changes per application.

Garden's roles are semantic from the start. `accent` means accent everywhere.
Generators handle the translation to each application's native format, including
ANSI-16 for terminal emulators.

### Why 4 text levels?

Two levels (dim and bright) aren't enough to express the hierarchy in a typical
editor or shell session. Consider kakoune: comments need to recede below
keywords, which recede below function names, which recede below the text you're
actively typing. That's four levels. Fish has a similar spread: autosuggestions
(`text-4`) → keywords (`text-3`) → parameters (`text-2`) → commands (`text-1`).

Three levels would force either comments and keywords to share a weight, or
keywords and body text to merge. Four is the minimum that keeps every layer
visually distinct.

### Why only 3 semantic colors?

Each semantic color is a commitment. It must work across every palette — dark,
light, warm, cool — while remaining visually distinct from the text hierarchy and
from each other. Every addition raises the floor for new palettes.

Three covers the universal needs: something is *highlighted* (accent), something
went *wrong* (urgent), something is *fine* (ok). Most UI patterns map to one of
these. Adding a fourth (info? warning?) would either overlap with existing roles
or force awkward distinctions that not every palette can honor.

### The completeness constraint

Every palette must define all 13 roles. No optional fields, no fallback logic.
This means generators can assume every role exists and never need conditional
code paths. It also means palette authors know exactly what they need to provide
— the palette is either complete or it fails validation.

## Implementation

The color system lives in `garden-core`:

```rust
pub enum ColorRole {
    // Surfaces
    BaseDeep, Base, BaseRaised, BaseHl,
    // Borders
    BorderSub, Border,
    // Text
    Text4, Text3, Text2, Text1,
    // Semantic
    Accent, Urgent, Ok,
}
```

Each variant serializes to kebab-case (`BaseDeep` ↔ `"base-deep"`) to match the
keys in `palettes.toml`.

Colors are stored as validated `HexColor` values — exactly 7 ASCII characters
(`#` + 6 hex digits), normalized to lowercase on construction:

```rust
pub struct HexColor(String);

impl HexColor {
    pub fn new(s: &str) -> Result<Self, String>  // validates format
    pub fn as_str(&self) -> &str                 // "#rrggbb"
    pub fn bare(&self) -> &str                   // "rrggbb" (no #)
    pub fn r(&self) -> u8                        // channel accessors
    pub fn g(&self) -> u8
    pub fn b(&self) -> u8
}
```

A `Palette` holds a `BTreeMap<ColorRole, HexColor>` — the map is ordered by the
enum's derived `Ord`, so serialization always produces roles in canonical order
(surfaces → borders → text → semantic).

Validation checks that all 13 entries are present:

```rust
impl Palette {
    pub fn validate(&self) -> Result<(), Vec<String>> {
        let missing: Vec<String> = ColorRole::ALL
            .iter()
            .filter(|r| !self.colors.contains_key(r))
            .map(|r| r.to_string())
            .collect();

        if missing.is_empty() { Ok(()) } else { Err(missing) }
    }
}
```

# Built-in palettes

> Garden ships with four palettes named after Japanese craft materials — each
> covering a different temperature and lightness niche.

## The four palettes

| Icon | Name | Character | When to use |
|------|------|-----------|-------------|
| ◐ | **mokume** | Dark — hague blue × warm cream | Default. Cool backgrounds with warm foreground text. Comfortable for long sessions. |
| ● | **sumi** | Neutral — charcoal ink × amber | When you want no color bias in the background. Pure neutral grays with amber warmth in text. |
| ○ | **kinu** | Light — raw silk × dark walnut | Daytime or bright environments. Light parchment background with dark walnut text. |
| ◑ | **yoru** | Night — no blue light × deep amber | Late night. Eliminates blue light entirely. Deep amber tones throughout. |

Switch palettes instantly:

```bash
just themes try mokume    # generate + apply to kitty, fish, kakoune
just themes try sumi
just themes try kinu
just themes try yoru
```

## The colors

### mokume ◐

```
base-deep    #252d3b    base         #2c3444
base-raised  #343d4f    base-hl      #3d4759
border-sub   #3a4456    border       #4a5568
text-4       #505e70    text-3       #6b7a8d
text-2       #8b9bb0    text-1       #d4c5a9
accent       #c9b88c    urgent       #c4796b    ok  #7c9a7c
```

### sumi ●

```
base-deep    #222222    base         #282828
base-raised  #313131    base-hl      #3a3a3a
border-sub   #383838    border       #484848
text-4       #545450    text-3       #706f68
text-2       #9a9a8e    text-1       #d4c4a0
accent       #c2a86a    urgent       #bf7565    ok  #7a9470
```

### kinu ○

```
base-deep    #ddd5c8    base         #e8e0d4
base-raised  #f0e9de    base-hl      #d8d0c2
border-sub   #d0c6b6    border       #c4b9a8
text-4       #a8a094    text-3       #8a8278
text-2       #5c554c    text-1       #2c2620
accent       #8a7440    urgent       #a85a48    ok  #5a7a52
```

### yoru ◑

```
base-deep    #221a14    base         #281e18
base-raised  #302520    base-hl      #3a2e28
border-sub   #3c322c    border       #4a3e36
text-4       #5c5044    text-3       #7a6a58
text-2       #a08a6e    text-1       #d4b888
accent       #c4a050    urgent       #c07848    ok  #7a9060
```

## Design rationale

### Japanese craft naming

The names reference materials and techniques from Japanese craftsmanship:

- **mokume** (木目) — wood grain, specifically *mokume-gane*, a metalworking
  technique that creates layered patterns. The palette layers cool blue-gray
  depths with warm cream surfaces.
- **sumi** (墨) — ink, as in *sumi-e* ink painting. Pure carbon black through
  warm gray, with amber highlights like aged paper.
- **kinu** (絹) — silk. Raw, unbleached silk has a warm ivory tone. The light
  palette uses this as its canvas with dark walnut for text.
- **yoru** (夜) — night. The warmest palette, designed for use after dark when
  blue light should be avoided entirely.

### Why these four?

The four palettes span a coverage matrix:

|  | Cool/Neutral | Warm |
|--|-------------|------|
| **Dark** | mokume, sumi | yoru |
| **Light** | | kinu |

This gives you a palette for every common condition: daytime (kinu), evening
(mokume or sumi depending on taste), late night (yoru). The two dark palettes
differ in temperature bias — mokume has blue in its backgrounds, sumi is
deliberately neutral.

### Active selection

The `active` field in `palettes.json` determines which palette generators use
by default. Change it to switch your base palette:

```json
{
  "active": "sumi",
  "palettes": { ... }
}
```

Or override per-invocation without editing the file:

```bash
just themes try yoru
```

## Implementation

All four palettes live in `_config/palettes.json` as a `PaletteCollection`:

```json
{
  "active": "mokume",
  "palettes": {
    "mokume": {
      "name": "mokume",
      "subtitle": "dark -- hague blue x warm cream",
      "icon": "◐",
      "builtin": true,
      "colors": {
        "base-deep": "#252d3b",
        "base": "#2c3444",
        ...
      }
    },
    ...
  }
}
```

The `PaletteCollection` struct mirrors this shape:

```rust
pub struct PaletteCollection {
    pub active: String,
    pub palettes: BTreeMap<String, Palette>,
}

pub struct Palette {
    pub name: String,
    pub subtitle: String,
    pub icon: String,
    pub builtin: bool,
    pub forked_from: Option<String>,
    pub colors: BTreeMap<ColorRole, HexColor>,
}
```

Built-in palettes have `builtin: true`, which prevents them from being deleted
by user operations. The `BTreeMap` key order means palettes serialize
alphabetically by name, and colors serialize in canonical role order.

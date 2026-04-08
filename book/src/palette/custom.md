# Custom palettes

> Fork a built-in palette, adjust the colors, and validate — that's the whole
> workflow.

## Creating a palette

The easiest way to create a custom palette is to fork an existing one. Copy a
built-in palette entry in `_config/palettes.toml`, give it a new name, and
adjust the colors:

```toml
active = "my-palette"

[palettes.my-palette]
name = "my-palette"
subtitle = "dark -- custom description"
icon = "◆"
builtin = false
forked_from = "mokume"

[palettes.my-palette.colors]
base-deep = "#1a1a2e"
base = "#16213e"
base-raised = "#1e2a4a"
base-hl = "#2a3a5a"
border-sub = "#2a3050"
border = "#3a4a6a"
text-4 = "#4a5a7a"
text-3 = "#6a7a9a"
text-2 = "#8a9aba"
text-1 = "#d4c8b0"
accent = "#c9b88c"
urgent = "#c4796b"
ok = "#7c9a7c"
```

Set `active` to your new palette name, then validate and preview:

```bash
just themes validate     # check all 13 roles are present
just themes try          # generate + apply to see it live
```

## The forked_from field

When you fork a built-in palette, set `forked_from` to the parent's name. This
is metadata only — it doesn't affect generation or validation. It records
lineage so you (and others) know the starting point. If you're building a
palette from scratch, omit the field entirely.

## Requirements

Every custom palette must satisfy the same rules as built-ins:

1. **All 13 roles present.** No optional roles, no extras. The palette must
   define exactly: `base-deep`, `base`, `base-raised`, `base-hl`, `border-sub`,
   `border`, `text-4`, `text-3`, `text-2`, `text-1`, `accent`, `urgent`, `ok`.

2. **Valid hex colors.** Each value must be `#rrggbb` — 7 characters, lowercase
   or uppercase (normalized to lowercase on load).

3. **Set `builtin: false`.** Built-in palettes ship with Garden and can't be
   deleted by user operations. Your palettes should not claim to be built-in.

Validation catches missing roles and invalid colors:

```bash
$ just themes validate
error: palette 'my-palette' missing roles: border-sub, text-4
```

## Tips for good palettes

- **Start from a fork.** The built-in palettes have tested contrast ratios
  between their text and surface levels. Starting from one and making
  incremental changes preserves that work.

- **Keep the text hierarchy.** `text-1` should be the highest contrast against
  your `base`, stepping down through `text-2`, `text-3`, `text-4`. If `text-3`
  is brighter than `text-2`, generators will produce confusing results where
  keywords outshine body text.

- **Test all three generators.** A palette might look fine in kitty but break
  in kakoune where more roles are visible simultaneously. Use `just themes try`
  to apply everywhere and check each application.

- **Check both the dark and light ends.** If your surfaces are dark, make sure
  `base-hl` is visibly distinct from `base` — selections need to stand out. For
  light palettes, verify that `base-deep` (used for gutters and status lines)
  is darker than `base`.

## Design rationale

### Why fork-based?

Building a palette from scratch means choosing 13 colors that work together
across three applications, each with different contrast requirements. That's a
lot of variables to get right simultaneously.

Forking lets you change what matters and inherit what works. Want mokume with a
warmer accent? Fork it, change `accent`, validate, done. The surface hierarchy,
text contrast, and semantic colors all remain tested.

Nothing prevents from-scratch palettes — just set `forked_from` to `null` or
omit it. But forking is the recommended path for most use cases.

### Why strict validation?

If a palette could omit `text-4`, every generator would need a fallback
(`text-4.unwrap_or(text-3)` or similar). That's conditional logic multiplied
across every generator, plus edge cases in testing. Worse, a palette that
"works" with a fallback might look subtly wrong — autosuggestions rendering at
keyword brightness, for instance.

Requiring all 13 roles eliminates the entire class of fallback bugs. Generators
call `palette.color(role).unwrap()` knowing it will succeed on any validated
palette.

## Implementation

### TOML schema

The palette entry in `palettes.toml`:

```toml
[palettes.my-palette]
name = "my-palette"
subtitle = "description"
icon = "◆"
builtin = false
forked_from = "mokume"  # optional

[palettes.my-palette.colors]
base-deep = "#rrggbb"
base = "#rrggbb"
base-raised = "#rrggbb"
base-hl = "#rrggbb"
border-sub = "#rrggbb"
border = "#rrggbb"
text-4 = "#rrggbb"
text-3 = "#rrggbb"
text-2 = "#rrggbb"
text-1 = "#rrggbb"
accent = "#rrggbb"
urgent = "#rrggbb"
ok = "#rrggbb"
```

### Validation internals

`Palette::validate()` iterates `ColorRole::ALL` and collects any role not
present in the `colors` map:

```rust
pub fn validate(&self) -> Result<(), Vec<String>> {
    let missing: Vec<String> = ColorRole::ALL
        .iter()
        .filter(|r| !self.colors.contains_key(r))
        .map(|r| r.to_string())
        .collect();

    if missing.is_empty() { Ok(()) } else { Err(missing) }
}
```

`PaletteCollection::validate()` additionally checks that the `active` palette
name exists as a key in the `palettes` map. Both checks run when you execute
`just themes validate`.

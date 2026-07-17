# Garden Shell Code Review — July 2026

Full code review of garden-shell (QML shell, Rust crates, Nix aspects) and its
integration with fern. Three parallel review passes (QML, Rust, Nix/fern) were
run and all critical findings were manually verified against source before
being accepted.

**Status:** Critical/high findings (F1–F5) were fixed in this pass, plus the
fern `nh.nix` quick win. Medium/low findings are documented here for later
work. Rejected findings are recorded so they aren't re-reported by future
reviews.

---

## Critical / High — FIXED

### F1. Fragile palette save path — `_qml/overlays/PaletteEditor.qml`

`save()` wrote palettes.toml via `bash -c "cat > '<path>' << 'GARDEN_EOF' ..."`:

- Path was single-quoted but unescaped (broke on quotes in `$XDG_CONFIG_HOME`).
- TOML body embedded in a heredoc: content containing `GARDEN_EOF` corrupted
  the write.
- `_serializeToml()` did not escape `"` or `\` in string fields (`name`,
  `subtitle`, `forked_from`) — forked palette names with quotes produced
  invalid TOML that garden-themes then failed to parse.

**Fix:** content is now written via `tee`'s stdin (Quickshell `Process.write()`
+ `stdinEnabled`), never passing through a shell. Added `_tomlEscape()` for all
string fields and `_validateWorkingColors()` (`/^#[0-9a-fA-F]{6}$/` for every
`Theme.colorKeyOrder` key) which aborts the save on invalid data.

### F2. Non-atomic file writes — `crates/garden-themes/src/main.rs`

`fs::write` was used directly for `palettes.toml`, theme files,
`palettes.json` cache, and `.manifest.json`. A crash mid-write could corrupt
the palette source of truth, and QML's `FileView { watchChanges: true }` could
observe partially-written `palettes.json`.

**Fix:** added `write_atomic()` (write to `.tmp` sibling, then `fs::rename`)
and used it for all four write sites.

### F3. Silent reload failures — `crates/garden-themes/src/main.rs`

All reload command errors in `reload_kitty` / `reload_fish` / `reload_kakoune`
were discarded (`let _ = ...`, null stdio). If kitty/fish were missing or
sockets failed, the user got "applied N files" with no indication apps didn't
reload. Additionally:

- kakoune reload interpolated the theme path unquoted into `source {}` inside
  `%{ }` (broke on `}` in path).
- fish reload escaped only single quotes when interpolating the path.

**Fix:** every reload path now prints `warning: ...` to stderr on non-zero
exit or spawn error (overall exit code stays 0 — reload is best-effort). The
fish path is passed as an argument (`fish -c 'source $argv[1]' <path>`), never
interpolated. The kakoune path is sent as a kak single-quoted string (with `'`
doubled) and reload is skipped with a warning if the path contains braces or
newlines (which would unbalance the `%{ }` block). `pkill` exit 1 (no kitty
running) is not treated as an error.

### F4. `garden-themes` binary not guaranteed on PATH — `modules/aspects/terminal.nix`

`garden.terminal` sourced files from `~/.config/garden/themes/*` but:

- Did not include `garden.toolkit` (the only aspect installing the
  `garden-themes` binary), and fern includes only `garden.terminal`
  (`fern/modules/user-ada.nix`). The binary worked on this machine only via
  unmanaged state; `Theme.qml` falls back to bare `garden-themes` on PATH.
  (Confirmed live during this review: Quickshell logs showed
  `Process failed to start ... Command: QList("garden-themes", "apply", ...)`.)
- No activation step ever generated `~/.config/garden/themes/` — a fresh
  install got an unthemed terminal until a manual `garden-themes apply`.

**Fix:** `garden.terminal` now includes `garden.toolkit` (den resolves the
diamond with `garden.palette`), and a `home.activation.gardenThemesSeed` entry
(after `writeBoundary` and `gardenPalettes`) runs `garden-themes apply` from
the store path when `~/.config/garden/themes/.manifest.json` does not exist —
seeding fresh machines without clobbering runtime palette selection.

### F5. Missing error handling in polling services — `_qml/services/AudioService.qml`, `BrightnessService.qml`

No stderr handlers, no exit-code checks (silent failure if wpctl/ddcutil
absent or failing), no NaN guards on `parseFloat`/`parseInt`, brightness not
clamped to [0,1] if `current > max`.

**Fix:** both services now log stderr and non-zero exits (once per failure
streak, to avoid spamming the log from a 500ms/3s poll), guard parses with
`isNaN`, and clamp values into [0,1].

### Fern quick win — `fern/modules/cli/nh.nix` — FIXED

Hardcoded `/home/ada/src/fern` → `${config.users.users.ada.home}/src/fern`
with `lib.mkDefault`. (The module is a NixOS aspect, so
`config.home.homeDirectory` is unavailable; the username stays, the home path
is derived.)

---

## Medium / Low — NOT fixed in this pass

1. **`garden.shell` aspect never included by fern.** QML deployment
   (`~/.config/quickshell/garden`) and settings.json seeding rely on a manual
   symlink to the source tree. Deliberate for the hot-reload dev workflow, but
   breaks on a fresh/second machine. Known trade-off; adopting `garden.shell`
   conflicts with the live-source symlink and needs its own design pass
   (e.g. `mkOutOfStoreSymlink` vs store copy).

2. **`garden-themes-output` package (`modules/packages.nix`) is built but
   never deployed anywhere** — dead reference output.

3. **Mutable-file activation scripts (`palette.nix`, `shell.nix`) depend on
   `[ ! -f ]` checks.** If HM ever manages those paths directly, runtime
   palette selection is silently lost. An explanatory contract comment was
   added to `palette.nix` in this pass; the structural fragility remains.

4. **`HexColor` accessors rely on construction invariant for `unwrap()`**
   (safe, but deserves a safety comment); `Result<_, String>` used instead of
   proper error types in garden-core.

5. **TOCTOU windows in stale-symlink cleanup** (`clean_stale_symlinks`).
   Single-user desktop; acceptable.

6. **Host niri aspect included twice in `fern/modules/host-fern.nix`** without
   a comment explaining why.

7. **BarClock timer doesn't guard against clock jumps** (suspend/resume, NTP
   step).

8. **Deep-copy via `JSON.parse(JSON.stringify())` repeated 6× in
   PaletteEditor** — could be a small helper, cosmetic only.

---

## Rejected findings (from review agents, disproven on inspection)

- **"Race condition: apply before file flush"** — `cat`/`tee` exiting means
  the write is visible to subsequent readers; the page cache is coherent. No
  delay timer needed.
- **"Overlays not using OverlayBase / duplicated color map / missing
  singleton refs"** — audited clean; the conventions in CLAUDE.md are
  followed.
- **"Theme.qml applyProcess lacks error handling"** — it already has stderr +
  exit handling (`Theme.qml:108-123` at time of review).

//! Theme generator framework and built-in generators.
//!
//! Each generator implements the [`ThemeGenerator`] trait, which takes a
//! validated [`Palette`] and produces a configuration file as a string.
//! Generators declare the relative output path so the CLI can write them
//! to the correct location under the output directory.
//!
//! # Built-in generators
//!
//! | Generator | Output file                          | Format                |
//! |-----------|--------------------------------------|-----------------------|
//! | [`Kitty`]   | `kitty/garden-theme.conf`            | Kitty color conf      |
//! | [`Fish`]    | `fish/garden-theme.fish`             | Fish universal vars   |
//! | [`Kakoune`] | `kak/garden.kak`                     | Kakoune face decls    |
//!
//! # Adding a new generator
//!
//! 1. Create a new module in `generators/`.
//! 2. Implement [`ThemeGenerator`] for your struct.
//! 3. Add an instance to [`all()`] so the CLI picks it up automatically.
//!
//! # Examples
//!
//! ```no_run
//! use garden_themes::generators::{all, ThemeGenerator};
//! use garden_core::PaletteCollection;
//!
//! let col = PaletteCollection::from_toml("...").unwrap();
//! let palette = col.active_palette().unwrap();
//!
//! for gen in all() {
//!     let content = gen.generate(palette);
//!     println!("--- {} ---\n{content}", gen.relative_path());
//! }
//! ```

pub mod fish;
pub mod kakoune;
pub mod kitty;

use garden_core::Palette;

/// A theme generator that maps a [`Palette`] to a configuration file.
///
/// Implementations are responsible for translating Garden's 13 semantic
/// color roles into the target application's format. The generator
/// should produce a complete, self-contained configuration fragment that
/// can be included or sourced by the target application.
pub trait ThemeGenerator {
    /// Human-readable name for display in CLI output (e.g. `"kitty"`).
    fn name(&self) -> &str;

    /// Relative path under the output directory where the generated
    /// file should be written (e.g. `"kitty/garden-theme.conf"`).
    fn relative_path(&self) -> &str;

    /// Generates the theme configuration for the given palette.
    ///
    /// The returned string is the full file content, ready to be
    /// written to disk. It should include a header comment identifying
    /// it as machine-generated.
    fn generate(&self, palette: &Palette) -> String;
}

/// Returns instances of all built-in theme generators.
///
/// The CLI iterates this list when running `generate` without a
/// `--generator` filter. New generators added to this crate should
/// be registered here.
pub fn all() -> Vec<Box<dyn ThemeGenerator>> {
    vec![
        Box::new(kitty::Kitty),
        Box::new(fish::Fish),
        Box::new(kakoune::Kakoune),
    ]
}

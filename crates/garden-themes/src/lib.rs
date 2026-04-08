//! # garden-themes
//!
//! Theme generation library for the Garden desktop environment.
//!
//! This crate provides the [`generators`] module containing the
//! [`ThemeGenerator`](generators::ThemeGenerator) trait and built-in
//! implementations for kitty and fish. The companion binary
//! (`garden-themes`) wraps this library with a clap CLI.
//!
//! # Architecture
//!
//! ```text
//! palettes.toml
//!     → garden_core::PaletteCollection   (parse + validate)
//!     → generators::all()                (discover generators)
//!     → ThemeGenerator::generate()       (produce config text)
//!     → fs::write()                      (emit files)
//! ```
//!
//! # Examples
//!
//! ```no_run
//! use garden_core::PaletteCollection;
//! use garden_themes::generators::{all, ThemeGenerator};
//! use std::path::Path;
//!
//! let col = PaletteCollection::from_file(Path::new("palettes.toml")).unwrap();
//! col.validate().unwrap();
//! let palette = col.active_palette().unwrap();
//!
//! for gen in all() {
//!     let content = gen.generate(palette);
//!     std::fs::write(gen.relative_path(), content).unwrap();
//! }
//! ```

pub mod generators;

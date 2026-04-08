//! # garden-core
//!
//! Shared type definitions for the Garden desktop environment.
//!
//! This crate provides the foundational data model used across all
//! Garden tools — the theme generators, the infrastructure daemon, the
//! TUI, and the Quickshell QML bridge.
//!
//! ## Modules
//!
//! | Module       | Purpose                                              |
//! |-------------|-------------------------------------------------------|
//! | [`palette`] | 13-role semantic color system and `palettes.toml` I/O |
//! | [`types`]   | Host configuration, connection state, tier model      |
//! | [`events`]  | Typed IPC events for the Garden event bus              |
//!
//! ## Quick start
//!
//! ```no_run
//! use garden_core::{PaletteCollection, ColorRole};
//! use std::path::Path;
//!
//! let col = PaletteCollection::from_file(Path::new("palettes.toml")).unwrap();
//! col.validate().unwrap();
//!
//! let palette = col.active_palette().unwrap();
//! let bg = palette.color(ColorRole::Base).unwrap();
//! println!("background: {bg}");
//! ```

pub mod events;
pub mod palette;
pub mod types;

pub use events::*;
pub use palette::*;
pub use types::*;

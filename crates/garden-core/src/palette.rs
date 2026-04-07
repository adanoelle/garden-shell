//! Palette type system for the Garden color theme pipeline.
//!
//! This module provides the core data model for Garden's 13-role semantic
//! color system. Every palette defines exactly 13 [`ColorRole`] entries,
//! and the [`PaletteCollection`] type represents the full `palettes.json`
//! file including the active palette selection.
//!
//! # Design
//!
//! Garden uses a fixed set of semantic color roles rather than raw ANSI
//! slots. This gives theme generators a consistent vocabulary to map
//! from — each generator decides how the 13 roles translate to its
//! target format (ANSI-16, fish syntax colors, editor scopes, etc.).
//!
//! The 13 roles are grouped into four categories:
//!
//! | Category   | Roles                                         | Purpose                |
//! |-----------|-----------------------------------------------|------------------------|
//! | Surfaces  | `base-deep`, `base`, `base-raised`, `base-hl` | Background layers      |
//! | Borders   | `border-sub`, `border`                        | Dividers and frames    |
//! | Text      | `text-4` … `text-1`                           | Dim → bright hierarchy |
//! | Semantic  | `accent`, `urgent`, `ok`                      | Meaning-bearing color  |
//!
//! # Built-in palettes
//!
//! Garden ships with four palettes inspired by Japanese craft traditions:
//!
//! | Name   | Icon | Character                       |
//! |--------|------|---------------------------------|
//! | mokume | ◐    | Dark — hague blue × warm cream  |
//! | sumi   | ●    | Neutral — charcoal ink × amber  |
//! | kinu   | ○    | Light — raw silk × dark walnut  |
//! | yoru   | ◑    | Night — no blue light × amber   |
//!
//! # Pipeline
//!
//! ```text
//! palettes.json
//!     → PaletteCollection::from_file()
//!     → .validate()
//!     → .active_palette()
//!     → ThemeGenerator::generate(&palette)
//!     → kitty.conf, garden-theme.fish, garden.kak, …
//! ```
//!
//! # Examples
//!
//! Loading and validating palettes:
//!
//! ```no_run
//! use garden_core::palette::{PaletteCollection, ColorRole};
//! use std::path::Path;
//!
//! let col = PaletteCollection::from_file(Path::new("palettes.json")).unwrap();
//! col.validate().unwrap();
//!
//! let palette = col.active_palette().unwrap();
//! println!("{} {} — {}", palette.icon, palette.name, palette.subtitle);
//!
//! // Access individual colors by role.
//! let bg = palette.color(ColorRole::Base).unwrap();
//! let fg = palette.color(ColorRole::Text1).unwrap();
//! println!("bg={bg}  fg={fg}");
//! ```
//!
//! Iterating over all roles:
//!
//! ```no_run
//! use garden_core::palette::{PaletteCollection, ColorRole};
//!
//! # let json = "{}";
//! # let col: PaletteCollection = serde_json::from_str(json).unwrap();
//! let palette = col.active_palette().unwrap();
//! for role in ColorRole::ALL {
//!     if let Some(hex) = palette.color(*role) {
//!         println!("{role}: {hex}");
//!     }
//! }
//! ```

use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::fmt;
use std::path::Path;

// ── HexColor ──────────────────────────────────────────────────────────

/// A validated CSS-style hex color in `#rrggbb` format.
///
/// Values are normalized to lowercase on construction. The inner string
/// is guaranteed to be exactly 7 ASCII characters: `#` followed by six
/// hex digits.
///
/// # Examples
///
/// ```
/// use garden_core::palette::HexColor;
///
/// let color = HexColor::new("#C4796B").unwrap();
/// assert_eq!(color.as_str(), "#c4796b");
/// assert_eq!(color.r(), 0xc4);
/// assert_eq!(color.bare(), "c4796b");
/// ```
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[serde(try_from = "String", into = "String")]
pub struct HexColor(String);

impl HexColor {
    /// Creates a new [`HexColor`] from a `#rrggbb` string.
    ///
    /// The input is trimmed and normalized to lowercase. It must be
    /// exactly 7 characters long, start with `#`, and contain only
    /// ASCII hex digits after the `#`.
    ///
    /// # Errors
    ///
    /// Returns a descriptive error string if the input is malformed:
    /// wrong length, missing `#` prefix, or non-hex characters.
    ///
    /// # Examples
    ///
    /// ```
    /// use garden_core::palette::HexColor;
    ///
    /// assert!(HexColor::new("#c4796b").is_ok());
    /// assert!(HexColor::new("c4796b").is_err());   // missing #
    /// assert!(HexColor::new("#zzzzzz").is_err());   // non-hex
    /// ```
    pub fn new(s: &str) -> Result<Self, String> {
        let s = s.trim();
        if s.len() != 7 {
            return Err(format!("expected 7 chars (#rrggbb), got {}: {s}", s.len()));
        }
        if !s.starts_with('#') {
            return Err(format!("must start with '#': {s}"));
        }
        if !s[1..].chars().all(|c| c.is_ascii_hexdigit()) {
            return Err(format!("invalid hex digits: {s}"));
        }
        Ok(Self(s.to_ascii_lowercase()))
    }

    /// Returns the full `#rrggbb` string, including the leading `#`.
    pub fn as_str(&self) -> &str {
        &self.0
    }

    /// Returns the hex digits without the leading `#`.
    ///
    /// Useful for config formats that expect bare hex values (e.g. some
    /// terminal emulators).
    pub fn bare(&self) -> &str {
        &self.0[1..]
    }

    /// Returns the red channel as a `u8` (0–255).
    pub fn r(&self) -> u8 {
        u8::from_str_radix(&self.0[1..3], 16).unwrap()
    }

    /// Returns the green channel as a `u8` (0–255).
    pub fn g(&self) -> u8 {
        u8::from_str_radix(&self.0[3..5], 16).unwrap()
    }

    /// Returns the blue channel as a `u8` (0–255).
    pub fn b(&self) -> u8 {
        u8::from_str_radix(&self.0[5..7], 16).unwrap()
    }
}

impl TryFrom<String> for HexColor {
    type Error = String;

    fn try_from(s: String) -> Result<Self, String> {
        HexColor::new(&s)
    }
}

impl From<HexColor> for String {
    fn from(c: HexColor) -> String {
        c.0
    }
}

impl fmt::Display for HexColor {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

// ── ColorRole ─────────────────────────────────────────────────────────

/// One of 13 semantic color roles that every Garden palette must define.
///
/// The roles are organized into four groups:
///
/// | Group      | Roles                                         |
/// |------------|-----------------------------------------------|
/// | Surfaces   | `BaseDeep`, `Base`, `BaseRaised`, `BaseHl`    |
/// | Borders    | `BorderSub`, `Border`                         |
/// | Text       | `Text4`, `Text3`, `Text2`, `Text1`            |
/// | Semantic   | `Accent`, `Urgent`, `Ok`                      |
///
/// Variants serialize to kebab-case via `#[serde(rename)]` to match the
/// keys in `palettes.json` (e.g. `BaseDeep` ↔ `"base-deep"`).
#[derive(Debug, Clone, Copy, PartialEq, Eq, Hash, PartialOrd, Ord, Serialize, Deserialize)]
pub enum ColorRole {
    /// Deepest background surface — used for recessed areas and gutters.
    #[serde(rename = "base-deep")]
    BaseDeep,

    /// Primary background surface — the default canvas color.
    #[serde(rename = "base")]
    Base,

    /// Raised surface — cards, floating panels, and elevated elements.
    #[serde(rename = "base-raised")]
    BaseRaised,

    /// Highlighted surface — selection backgrounds and hover states.
    #[serde(rename = "base-hl")]
    BaseHl,

    /// Subtle border — separators and low-emphasis dividers.
    #[serde(rename = "border-sub")]
    BorderSub,

    /// Primary border — window frames and prominent dividers.
    #[serde(rename = "border")]
    Border,

    /// Faintest text — disabled labels, ghost suggestions, comments.
    #[serde(rename = "text-4")]
    Text4,

    /// Muted text — secondary labels, placeholders, keywords.
    #[serde(rename = "text-3")]
    Text3,

    /// Secondary text — body copy, parameters, default terminal text.
    #[serde(rename = "text-2")]
    Text2,

    /// Primary text — headings, commands, high-emphasis content.
    #[serde(rename = "text-1")]
    Text1,

    /// Accent — quoted strings, links, active indicators.
    #[serde(rename = "accent")]
    Accent,

    /// Urgent — errors, destructive actions, critical alerts.
    #[serde(rename = "urgent")]
    Urgent,

    /// Ok — success states, confirmations, healthy indicators.
    #[serde(rename = "ok")]
    Ok,
}

impl ColorRole {
    /// All 13 color roles in canonical order (surfaces → borders → text → semantic).
    pub const ALL: &[ColorRole] = &[
        Self::BaseDeep,
        Self::Base,
        Self::BaseRaised,
        Self::BaseHl,
        Self::BorderSub,
        Self::Border,
        Self::Text4,
        Self::Text3,
        Self::Text2,
        Self::Text1,
        Self::Accent,
        Self::Urgent,
        Self::Ok,
    ];

    /// Returns the kebab-case string representation (e.g. `"base-deep"`).
    pub fn as_str(&self) -> &'static str {
        match self {
            Self::BaseDeep => "base-deep",
            Self::Base => "base",
            Self::BaseRaised => "base-raised",
            Self::BaseHl => "base-hl",
            Self::BorderSub => "border-sub",
            Self::Border => "border",
            Self::Text4 => "text-4",
            Self::Text3 => "text-3",
            Self::Text2 => "text-2",
            Self::Text1 => "text-1",
            Self::Accent => "accent",
            Self::Urgent => "urgent",
            Self::Ok => "ok",
        }
    }
}

impl fmt::Display for ColorRole {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(self.as_str())
    }
}

// ── Palette ───────────────────────────────────────────────────────────

/// A single named palette containing all 13 semantic color roles.
///
/// Built-in palettes (mokume, sumi, kinu, yoru) have `builtin: true`.
/// User-created palettes may set `forked_from` to reference the palette
/// they were derived from.
///
/// # Validation
///
/// Use [`Palette::validate`] to ensure all 13 [`ColorRole`] entries are
/// present. Deserialization alone does not enforce completeness — a
/// palette with missing roles will parse successfully but fail
/// validation.
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Palette {
    /// Display name of the palette (e.g. `"mokume"`).
    pub name: String,

    /// Short description (e.g. `"dark -- hague blue x warm cream"`).
    pub subtitle: String,

    /// Single-character icon for UI display (e.g. `"◐"`).
    pub icon: String,

    /// Whether this palette ships with Garden and cannot be deleted.
    pub builtin: bool,

    /// If this palette was created by forking another, the parent's name.
    #[serde(skip_serializing_if = "Option::is_none")]
    pub forked_from: Option<String>,

    /// The 13 semantic color definitions.
    pub colors: BTreeMap<ColorRole, HexColor>,
}

impl Palette {
    /// Validates that all 13 [`ColorRole`] entries are present.
    ///
    /// # Errors
    ///
    /// Returns a list of missing role names if any are absent.
    ///
    /// # Examples
    ///
    /// ```
    /// use garden_core::palette::{Palette, ColorRole, HexColor};
    /// use std::collections::BTreeMap;
    ///
    /// let palette = Palette {
    ///     name: "empty".into(),
    ///     subtitle: String::new(),
    ///     icon: String::new(),
    ///     builtin: false,
    ///     forked_from: None,
    ///     colors: BTreeMap::new(),
    /// };
    /// let err = palette.validate().unwrap_err();
    /// assert_eq!(err.len(), 13); // all roles missing
    /// ```
    pub fn validate(&self) -> Result<(), Vec<String>> {
        let missing: Vec<String> = ColorRole::ALL
            .iter()
            .filter(|r| !self.colors.contains_key(r))
            .map(|r| r.to_string())
            .collect();

        if missing.is_empty() {
            std::result::Result::Ok(())
        } else {
            Err(missing)
        }
    }

    /// Looks up the [`HexColor`] for a given [`ColorRole`].
    ///
    /// Returns `None` if the role is not present (which would indicate
    /// an invalid palette — see [`Palette::validate`]).
    pub fn color(&self, role: ColorRole) -> Option<&HexColor> {
        self.colors.get(&role)
    }
}

// ── PaletteCollection ─────────────────────────────────────────────────

/// The top-level structure of `palettes.json`: a set of named palettes
/// and an `active` key selecting which one is currently in use.
///
/// # Examples
///
/// ```no_run
/// use garden_core::palette::PaletteCollection;
///
/// let json = std::fs::read_to_string("palettes.json").unwrap();
/// let col = PaletteCollection::from_json(&json).unwrap();
/// col.validate().unwrap();
///
/// for (name, palette) in &col.palettes {
///     println!("{} {} — {}", palette.icon, name, palette.subtitle);
/// }
/// ```
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PaletteCollection {
    /// The key into [`palettes`](Self::palettes) identifying the
    /// currently active palette.
    pub active: String,

    /// All available palettes, keyed by name.
    pub palettes: BTreeMap<String, Palette>,
}

impl PaletteCollection {
    /// Parses a [`PaletteCollection`] from a JSON string.
    ///
    /// # Errors
    ///
    /// Returns an error message if the JSON is malformed or if any
    /// [`HexColor`] value fails validation.
    pub fn from_json(json: &str) -> Result<Self, String> {
        serde_json::from_str(json).map_err(|e| format!("failed to parse palettes JSON: {e}"))
    }

    /// Reads and parses a [`PaletteCollection`] from a file path.
    ///
    /// # Errors
    ///
    /// Returns an error message if the file cannot be read or if the
    /// contents fail to parse.
    pub fn from_file(path: &Path) -> Result<Self, String> {
        let contents = std::fs::read_to_string(path)
            .map_err(|e| format!("failed to read {}: {e}", path.display()))?;
        Self::from_json(&contents)
    }

    /// Returns a reference to the currently active palette, or `None`
    /// if the `active` key does not match any palette name.
    pub fn active_palette(&self) -> Option<&Palette> {
        self.palettes.get(&self.active)
    }

    /// Validates the entire collection.
    ///
    /// Checks that:
    /// - The [`active`](Self::active) palette exists in the collection.
    /// - Every palette has all 13 [`ColorRole`] entries.
    ///
    /// # Errors
    ///
    /// Returns a list of human-readable error strings describing all
    /// validation failures found.
    pub fn validate(&self) -> Result<(), Vec<String>> {
        let mut errors = Vec::new();

        if !self.palettes.contains_key(&self.active) {
            errors.push(format!("active palette '{}' not found", self.active));
        }

        for (name, palette) in &self.palettes {
            if let Err(missing) = palette.validate() {
                errors.push(format!(
                    "palette '{}' missing roles: {}",
                    name,
                    missing.join(", ")
                ));
            }
        }

        if errors.is_empty() {
            std::result::Result::Ok(())
        } else {
            Err(errors)
        }
    }
}

// ── Tests ─────────────────────────────────────────────────────────────

#[cfg(test)]
mod tests {
    use super::*;

    const PALETTES_JSON: &str = include_str!("../../../_config/palettes.json");

    #[test]
    fn parse_and_roundtrip() {
        let col: PaletteCollection = serde_json::from_str(PALETTES_JSON).unwrap();
        let json = serde_json::to_string_pretty(&col).unwrap();
        let col2: PaletteCollection = serde_json::from_str(&json).unwrap();
        assert_eq!(col.active, col2.active);
        assert_eq!(col.palettes.len(), col2.palettes.len());
    }

    #[test]
    fn all_builtins_have_13_roles() {
        let col: PaletteCollection = serde_json::from_str(PALETTES_JSON).unwrap();
        assert!(
            col.validate().is_ok(),
            "validation errors: {:?}",
            col.validate()
        );
        for (name, palette) in &col.palettes {
            assert_eq!(
                palette.colors.len(),
                13,
                "palette '{name}' has {} roles, expected 13",
                palette.colors.len()
            );
        }
    }

    #[test]
    fn active_palette_found() {
        let col: PaletteCollection = serde_json::from_str(PALETTES_JSON).unwrap();
        let active = col.active_palette().expect("active palette should exist");
        assert_eq!(active.name, "mokume");
    }

    #[test]
    fn hex_color_valid() {
        let c = HexColor::new("#c4796b").unwrap();
        assert_eq!(c.r(), 0xc4);
        assert_eq!(c.g(), 0x79);
        assert_eq!(c.b(), 0x6b);
        assert_eq!(c.as_str(), "#c4796b");
        assert_eq!(c.bare(), "c4796b");
    }

    #[test]
    fn hex_color_normalizes_case() {
        let c = HexColor::new("#C4796B").unwrap();
        assert_eq!(c.as_str(), "#c4796b");
    }

    #[test]
    fn hex_color_rejects_invalid() {
        assert!(HexColor::new("c4796b").is_err()); // missing #
        assert!(HexColor::new("#c479").is_err()); // too short
        assert!(HexColor::new("#c4796b00").is_err()); // too long
        assert!(HexColor::new("#gggggg").is_err()); // non-hex digits
    }

    #[test]
    fn color_role_serde_roundtrip() {
        for role in ColorRole::ALL {
            let json = serde_json::to_string(role).unwrap();
            let parsed: ColorRole = serde_json::from_str(&json).unwrap();
            assert_eq!(*role, parsed);
        }
    }

    #[test]
    fn color_role_serializes_kebab_case() {
        assert_eq!(
            serde_json::to_string(&ColorRole::BaseDeep).unwrap(),
            "\"base-deep\""
        );
        assert_eq!(
            serde_json::to_string(&ColorRole::BaseHl).unwrap(),
            "\"base-hl\""
        );
        assert_eq!(
            serde_json::to_string(&ColorRole::Text1).unwrap(),
            "\"text-1\""
        );
        assert_eq!(
            serde_json::to_string(&ColorRole::BorderSub).unwrap(),
            "\"border-sub\""
        );
    }

    #[test]
    fn palette_validate_detects_missing() {
        let mut palette = Palette {
            name: "test".into(),
            subtitle: "test".into(),
            icon: "x".into(),
            builtin: false,
            forked_from: None,
            colors: BTreeMap::new(),
        };
        let err = palette.validate().unwrap_err();
        assert_eq!(err.len(), 13);

        // Add one role — should have 12 missing.
        palette
            .colors
            .insert(ColorRole::Base, HexColor::new("#000000").unwrap());
        let err = palette.validate().unwrap_err();
        assert_eq!(err.len(), 12);
    }
}

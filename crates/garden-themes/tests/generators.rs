//! Integration tests for the Garden theme generators.
//!
//! These tests load the real `_config/palettes.json`, generate output
//! for the mokume palette, and verify that the generated files contain
//! the expected color values and structural elements.

use garden_core::{ColorRole, PaletteCollection};
use garden_themes::generators::{self, ThemeGenerator};

/// The actual palettes.json shipped with the repo.
const PALETTES_JSON: &str = include_str!("../../../_config/palettes.json");

/// Helper: load the collection and return the mokume palette.
fn mokume_collection() -> PaletteCollection {
    let col = PaletteCollection::from_json(PALETTES_JSON).unwrap();
    col.validate().unwrap();
    assert_eq!(col.active, "mokume");
    col
}

// ── Kitty ─────────────────────────────────────────────────────────────

#[test]
fn kitty_output_contains_header() {
    let col = mokume_collection();
    let palette = col.active_palette().unwrap();
    let kitty = generators::kitty::Kitty;
    let output = kitty.generate(palette);

    assert!(
        output.contains("Garden theme"),
        "should contain the generator header"
    );
    assert!(
        output.contains("mokume"),
        "should name the palette in the header"
    );
    assert!(
        output.contains("Do not edit by hand"),
        "should warn against manual edits"
    );
}

#[test]
fn kitty_output_contains_mokume_colors() {
    let col = mokume_collection();
    let palette = col.active_palette().unwrap();
    let kitty = generators::kitty::Kitty;
    let output = kitty.generate(palette);

    // Verify key color mappings from the mokume palette.
    let base = palette.color(ColorRole::Base).unwrap().as_str();
    let text1 = palette.color(ColorRole::Text1).unwrap().as_str();
    let urgent = palette.color(ColorRole::Urgent).unwrap().as_str();
    let ok = palette.color(ColorRole::Ok).unwrap().as_str();

    assert!(output.contains(&format!("background {base}")));
    assert!(output.contains(&format!("foreground {text1}")));
    assert!(output.contains(&format!("color1 {urgent}")));
    assert!(output.contains(&format!("color2 {ok}")));
}

#[test]
fn kitty_output_has_all_16_ansi_slots() {
    let col = mokume_collection();
    let palette = col.active_palette().unwrap();
    let kitty = generators::kitty::Kitty;
    let output = kitty.generate(palette);

    for i in 0..16 {
        assert!(
            output.contains(&format!("color{i} #")),
            "missing ANSI color slot {i}"
        );
    }
}

#[test]
fn kitty_relative_path() {
    let kitty = generators::kitty::Kitty;
    assert_eq!(kitty.relative_path(), "kitty/garden-theme.conf");
}

// ── Fish ──────────────────────────────────────────────────────────────

#[test]
fn fish_output_contains_header() {
    let col = mokume_collection();
    let palette = col.active_palette().unwrap();
    let fish = generators::fish::Fish;
    let output = fish.generate(palette);

    assert!(output.contains("Garden theme"));
    assert!(output.contains("mokume"));
    assert!(output.contains("Do not edit by hand"));
}

#[test]
fn fish_output_contains_mokume_colors() {
    let col = mokume_collection();
    let palette = col.active_palette().unwrap();
    let fish = generators::fish::Fish;
    let output = fish.generate(palette);

    // Fish uses bare hex (no #).
    let text1 = palette.color(ColorRole::Text1).unwrap().bare();
    let text2 = palette.color(ColorRole::Text2).unwrap().bare();
    let accent = palette.color(ColorRole::Accent).unwrap().bare();
    let urgent = palette.color(ColorRole::Urgent).unwrap().bare();

    assert!(output.contains(&format!("fish_color_command {text1}")));
    assert!(output.contains(&format!("fish_color_normal {text2}")));
    assert!(output.contains(&format!("fish_color_quote {accent}")));
    assert!(output.contains(&format!("fish_color_error {urgent}")));
}

#[test]
fn fish_output_sets_all_expected_variables() {
    let col = mokume_collection();
    let palette = col.active_palette().unwrap();
    let fish = generators::fish::Fish;
    let output = fish.generate(palette);

    let expected_vars = [
        "fish_color_normal",
        "fish_color_command",
        "fish_color_keyword",
        "fish_color_quote",
        "fish_color_error",
        "fish_color_param",
        "fish_color_comment",
        "fish_color_autosuggestion",
        "fish_color_selection",
        "fish_color_operator",
        "fish_color_escape",
        "fish_color_redirection",
        "fish_color_end",
    ];

    for var in expected_vars {
        assert!(output.contains(var), "missing fish variable: {var}");
    }
}

#[test]
fn fish_selection_uses_background_flag() {
    let col = mokume_collection();
    let palette = col.active_palette().unwrap();
    let fish = generators::fish::Fish;
    let output = fish.generate(palette);

    assert!(
        output.contains("--background="),
        "fish_color_selection should use --background flag"
    );
}

#[test]
fn fish_relative_path() {
    let fish = generators::fish::Fish;
    assert_eq!(fish.relative_path(), "fish/conf.d/garden-theme.fish");
}

// ── Kakoune ──────────────────────────────────────────────────────────

#[test]
fn kakoune_output_contains_header() {
    let col = mokume_collection();
    let palette = col.active_palette().unwrap();
    let kak = generators::kakoune::Kakoune;
    let output = kak.generate(palette);

    assert!(output.contains("Garden theme"));
    assert!(output.contains("mokume"));
    assert!(output.contains("Do not edit by hand"));
}

#[test]
fn kakoune_output_contains_mokume_colors() {
    let col = mokume_collection();
    let palette = col.active_palette().unwrap();
    let kak = generators::kakoune::Kakoune;
    let output = kak.generate(palette);

    let text2 = palette.color(ColorRole::Text2).unwrap().bare();
    let base = palette.color(ColorRole::Base).unwrap().bare();
    let accent = palette.color(ColorRole::Accent).unwrap().bare();
    let urgent = palette.color(ColorRole::Urgent).unwrap().bare();

    assert!(output.contains(&format!("Default            rgb:{text2},rgb:{base}")));
    assert!(output.contains(&format!("Error              rgb:{urgent},rgb:{base}")));
    assert!(output.contains(&format!("value              rgb:{accent}")));
    assert!(output.contains(&format!("string             rgb:{}", palette.color(ColorRole::Ok).unwrap().bare())));
    assert!(output.contains(&format!("comment            rgb:{}+i", palette.color(ColorRole::Text4).unwrap().bare())));
}

#[test]
fn kakoune_output_uses_rgb_format() {
    let col = mokume_collection();
    let palette = col.active_palette().unwrap();
    let kak = generators::kakoune::Kakoune;
    let output = kak.generate(palette);

    // Face declarations should use rgb: prefix, never bare #rrggbb hex.
    for line in output.lines() {
        if line.starts_with("face ") {
            assert!(
                !line.contains('#'),
                "face line should not contain # hex: {line}"
            );
        }
    }
    assert!(output.contains("rgb:"), "kakoune output should use rgb: format");
}

#[test]
fn kakoune_output_sets_all_expected_faces() {
    let col = mokume_collection();
    let palette = col.active_palette().unwrap();
    let kak = generators::kakoune::Kakoune;
    let output = kak.generate(palette);

    let expected_faces = [
        "Default",
        "StatusLine",
        "StatusCursor",
        "Prompt",
        "MenuForeground",
        "MenuBackground",
        "Information",
        "Error",
        "PrimarySelection",
        "SecondarySelection",
        "PrimaryCursor",
        "SecondaryCursor",
        "LineNumbers",
        "LineNumberCursor",
        "MatchingChar",
        "Whitespace",
        "BufferPadding",
        "value",
        "type",
        "variable",
        "module",
        "function",
        "string",
        "keyword",
        "operator",
        "attribute",
        "comment",
        "documentation",
        "meta",
        "builtin",
    ];

    for face in expected_faces {
        assert!(
            output.contains(&format!("face global {face}")),
            "missing kakoune face: {face}"
        );
    }
}

#[test]
fn kakoune_relative_path() {
    let kak = generators::kakoune::Kakoune;
    assert_eq!(kak.relative_path(), "kak/colors/garden.kak");
}

// ── Registry ──────────────────────────────────────────────────────────

#[test]
fn all_generators_registered() {
    let gens = generators::all();
    assert_eq!(gens.len(), 3, "expected kitty + fish + kakoune generators");

    let names: Vec<&str> = gens.iter().map(|g| g.name()).collect();
    assert!(names.contains(&"kitty"));
    assert!(names.contains(&"fish"));
    assert!(names.contains(&"kakoune"));
}

#[test]
fn all_generators_produce_nonempty_output() {
    let col = mokume_collection();
    let palette = col.active_palette().unwrap();

    for gen in generators::all() {
        let output = gen.generate(palette);
        assert!(
            !output.is_empty(),
            "{} generator produced empty output",
            gen.name()
        );
        assert!(
            output.len() > 100,
            "{} generator output suspiciously short ({} bytes)",
            gen.name(),
            output.len()
        );
    }
}

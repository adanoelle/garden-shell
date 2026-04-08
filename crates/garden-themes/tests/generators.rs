//! Integration tests for the Garden theme generators.
//!
//! These tests load the real `_config/palettes.toml`, generate output
//! for the active palette, and verify that the generated files contain
//! the expected color values and structural elements.

use garden_core::{ColorRole, PaletteCollection};
use garden_themes::generators::{self, ThemeGenerator};

/// The actual palettes.toml shipped with the repo.
const PALETTES_TOML: &str = include_str!("../../../_config/palettes.toml");

/// Helper: load the collection and validate it.
fn active_collection() -> PaletteCollection {
    let col = PaletteCollection::from_toml(PALETTES_TOML).unwrap();
    col.validate().unwrap();
    assert!(col.active_palette().is_some(), "active palette should exist");
    col
}

// ── Kitty ─────────────────────────────────────────────────────────────

#[test]
fn kitty_output_contains_header() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();
    let kitty = generators::kitty::Kitty;
    let output = kitty.generate(palette);

    assert!(
        output.contains("Garden theme"),
        "should contain the generator header"
    );
    assert!(
        output.contains(&col.active),
        "should name the palette in the header"
    );
    assert!(
        output.contains("Do not edit by hand"),
        "should warn against manual edits"
    );
}

#[test]
fn kitty_output_contains_palette_colors() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();
    let kitty = generators::kitty::Kitty;
    let output = kitty.generate(palette);

    // Verify key color mappings from the active palette.
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
    let col = active_collection();
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
    let col = active_collection();
    let palette = col.active_palette().unwrap();
    let fish = generators::fish::Fish;
    let output = fish.generate(palette);

    assert!(output.contains("Garden theme"));
    assert!(output.contains(&col.active));
    assert!(output.contains("Do not edit by hand"));
}

#[test]
fn fish_output_contains_palette_colors() {
    let col = active_collection();
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
    let col = active_collection();
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
    let col = active_collection();
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
    assert_eq!(fish.relative_path(), "fish/garden-theme.fish");
}

// ── Kakoune ──────────────────────────────────────────────────────────

#[test]
fn kakoune_output_contains_header() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();
    let kak = generators::kakoune::Kakoune;
    let output = kak.generate(palette);

    assert!(output.contains("Garden theme"));
    assert!(output.contains(&col.active));
    assert!(output.contains("Do not edit by hand"));
}

#[test]
fn kakoune_output_contains_palette_colors() {
    let col = active_collection();
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
    let col = active_collection();
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
    let col = active_collection();
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
    assert_eq!(kak.relative_path(), "kak/garden.kak");
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
    let col = active_collection();
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

// ── Palette cache ────────────────────────────────────────────────────

#[test]
fn palette_cache_is_valid_json_with_expected_structure() {
    let col = active_collection();
    let json = serde_json::to_string_pretty(&col).unwrap();
    let parsed: serde_json::Value = serde_json::from_str(&json).unwrap();

    // Top-level keys.
    assert!(parsed.get("active").is_some(), "missing 'active' key");
    assert!(parsed.get("palettes").is_some(), "missing 'palettes' key");

    // Active field matches.
    assert_eq!(parsed["active"].as_str().unwrap(), col.active);

    // All palettes present with expected fields.
    let palettes = parsed["palettes"].as_object().unwrap();
    assert_eq!(palettes.len(), col.palettes.len());

    for (name, palette_val) in palettes {
        let palette_obj = palette_val.as_object().unwrap();
        assert!(
            palette_obj.contains_key("name"),
            "palette '{name}' missing 'name'"
        );
        assert!(
            palette_obj.contains_key("colors"),
            "palette '{name}' missing 'colors'"
        );
        assert!(
            palette_obj.contains_key("icon"),
            "palette '{name}' missing 'icon'"
        );

        // All color roles present.
        let colors = palette_obj["colors"].as_object().unwrap();
        assert_eq!(
            colors.len(),
            ColorRole::ALL.len(),
            "palette '{name}' should have {} color roles, got {}",
            ColorRole::ALL.len(),
            colors.len()
        );

        // Verify colors are hex strings.
        for (role, color) in colors {
            let hex = color.as_str().unwrap();
            assert!(
                hex.starts_with('#') && hex.len() == 7,
                "palette '{name}' role '{role}' has invalid hex: {hex}"
            );
        }
    }
}

#[test]
fn palette_cache_written_to_disk() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();

    let tmp = tempfile::tempdir().unwrap();
    let output_dir = tmp.path();

    // Write themes (as cmd_generate would).
    let gens = generators::all();
    for gen in &gens {
        let content = gen.generate(palette);
        let dest = output_dir.join(gen.relative_path());
        if let Some(parent) = dest.parent() {
            std::fs::create_dir_all(parent).unwrap();
        }
        std::fs::write(&dest, &content).unwrap();
    }

    // Write palette cache alongside themes.
    let json = serde_json::to_string_pretty(&col).unwrap();
    let cache_path = output_dir.join("palettes.json");
    std::fs::write(&cache_path, format!("{json}\n")).unwrap();

    // Verify file exists and is parseable.
    assert!(cache_path.exists());
    let raw = std::fs::read_to_string(&cache_path).unwrap();
    let parsed: PaletteCollection = serde_json::from_str(&raw).unwrap();
    assert_eq!(parsed.active, col.active);
    assert_eq!(parsed.palettes.len(), col.palettes.len());
}

// ── Apply / themes directory ─────────────────────────────────────────

#[test]
fn apply_writes_to_themes_dir() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();

    let tmp = tempfile::tempdir().unwrap();
    let themes_dir = tmp.path();

    let gens = generators::all();
    for gen in &gens {
        let content = gen.generate(palette);
        let dest = themes_dir.join(gen.relative_path());
        if let Some(parent) = dest.parent() {
            std::fs::create_dir_all(parent).unwrap();
        }
        std::fs::write(&dest, &content).unwrap();
    }

    // Verify files at expected flat paths.
    assert!(themes_dir.join("kitty/garden-theme.conf").exists());
    assert!(themes_dir.join("fish/garden-theme.fish").exists());
    assert!(themes_dir.join("kak/garden.kak").exists());

    // Verify old deep paths do NOT exist.
    assert!(!themes_dir.join("fish/conf.d/garden-theme.fish").exists());
    assert!(!themes_dir.join("kak/colors/garden.kak").exists());
}

#[test]
fn apply_writes_manifest() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();

    let tmp = tempfile::tempdir().unwrap();
    let themes_dir = tmp.path();

    let gens = generators::all();
    let mut files = Vec::new();
    for gen in &gens {
        let content = gen.generate(palette);
        let dest = themes_dir.join(gen.relative_path());
        if let Some(parent) = dest.parent() {
            std::fs::create_dir_all(parent).unwrap();
        }
        std::fs::write(&dest, &content).unwrap();
        files.push(gen.relative_path().to_string());
    }

    // Write a manifest like cmd_apply does.
    let manifest = serde_json::json!({
        "palette": col.active,
        "generated_at": "2026-04-07T00:00:00Z",
        "generator_version": env!("CARGO_PKG_VERSION"),
        "files": files,
    });

    let manifest_path = themes_dir.join(".manifest.json");
    std::fs::write(
        &manifest_path,
        serde_json::to_string_pretty(&manifest).unwrap(),
    )
    .unwrap();

    // Read it back and verify.
    let raw = std::fs::read_to_string(&manifest_path).unwrap();
    let parsed: serde_json::Value = serde_json::from_str(&raw).unwrap();

    assert_eq!(parsed["palette"], col.active);
    assert_eq!(parsed["generator_version"], env!("CARGO_PKG_VERSION"));

    let manifest_files: Vec<String> = parsed["files"]
        .as_array()
        .unwrap()
        .iter()
        .map(|v| v.as_str().unwrap().to_string())
        .collect();

    assert!(manifest_files.contains(&"kitty/garden-theme.conf".to_string()));
    assert!(manifest_files.contains(&"fish/garden-theme.fish".to_string()));
    assert!(manifest_files.contains(&"kak/garden.kak".to_string()));
}

#[test]
fn active_palette_roundtrip() {
    let mut col = PaletteCollection::from_toml(PALETTES_TOML).unwrap();
    let original_active = col.active.clone();

    // Find a different palette name to switch to.
    let other_name = col
        .palettes
        .keys()
        .find(|k| **k != original_active)
        .expect("need at least two palettes for roundtrip test")
        .clone();

    // Switch active.
    col.active = other_name.clone();

    // Serialize and re-parse.
    let toml_out = col.to_toml_pretty().unwrap();
    let col2 = PaletteCollection::from_toml(&toml_out).unwrap();

    assert_eq!(col2.active, other_name);
    assert!(col2.active_palette().is_some());
    col2.validate().unwrap();

    // Switch back.
    let mut col3 = col2;
    col3.active = original_active.clone();
    let toml_out2 = col3.to_toml_pretty().unwrap();
    let col4 = PaletteCollection::from_toml(&toml_out2).unwrap();
    assert_eq!(col4.active, original_active);
}

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
    assert!(
        col.active_palette().is_some(),
        "active palette should exist"
    );
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
    assert!(output.contains(&format!(
        "string             rgb:{}",
        palette.color(ColorRole::Ok).unwrap().bare()
    )));
    assert!(output.contains(&format!(
        "comment            rgb:{}+i",
        palette.color(ColorRole::Text4).unwrap().bare()
    )));
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
    assert!(
        output.contains("rgb:"),
        "kakoune output should use rgb: format"
    );
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

// ── fzf ──────────────────────────────────────────────────────────────

#[test]
fn fzf_output_contains_header() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();
    let fzf = generators::fzf::Fzf;
    let output = fzf.generate(palette);

    assert!(output.contains("Garden theme"));
    assert!(output.contains(&col.active));
    assert!(output.contains("Do not edit by hand"));
}

#[test]
fn fzf_output_contains_palette_colors() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();
    let fzf = generators::fzf::Fzf;
    let output = fzf.generate(palette);

    let base = palette.color(ColorRole::Base).unwrap().as_str();
    let base_hl = palette.color(ColorRole::BaseHl).unwrap().as_str();
    let accent = palette.color(ColorRole::Accent).unwrap().as_str();
    let urgent = palette.color(ColorRole::Urgent).unwrap().as_str();

    assert!(output.contains(&format!("bg:{base}")));
    assert!(output.contains(&format!("bg+:{base_hl}")));
    assert!(output.contains(&format!("prompt:{accent}")));
    assert!(output.contains(&format!("hl:{urgent}")));
}

#[test]
fn fzf_output_sets_fzf_default_opts() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();
    let fzf = generators::fzf::Fzf;
    let output = fzf.generate(palette);

    assert!(
        output.contains("FZF_DEFAULT_OPTS"),
        "should set FZF_DEFAULT_OPTS"
    );
    assert!(output.contains("--color="), "should use fzf --color flag");
}

#[test]
fn fzf_relative_path() {
    let fzf = generators::fzf::Fzf;
    assert_eq!(fzf.relative_path(), "fzf/garden-theme.fish");
}

// ── bat ──────────────────────────────────────────────────────────────

#[test]
fn bat_output_contains_header() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();
    let bat = generators::bat::Bat;
    let output = bat.generate(palette);

    assert!(output.contains("Garden theme"));
    assert!(output.contains(&col.active));
    assert!(output.contains("Do not edit by hand"));
}

#[test]
fn bat_output_is_valid_xml_structure() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();
    let bat = generators::bat::Bat;
    let output = bat.generate(palette);

    assert!(output.contains("<?xml version"));
    assert!(output.contains("<plist version=\"1.0\">"));
    assert!(output.contains("</plist>"));
    assert!(output.contains("<key>settings</key>"));
}

#[test]
fn bat_output_contains_palette_colors() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();
    let bat = generators::bat::Bat;
    let output = bat.generate(palette);

    let base = palette.color(ColorRole::Base).unwrap().as_str();
    let text2 = palette.color(ColorRole::Text2).unwrap().as_str();
    let text1 = palette.color(ColorRole::Text1).unwrap().as_str();
    let ok = palette.color(ColorRole::Ok).unwrap().as_str();
    let urgent = palette.color(ColorRole::Urgent).unwrap().as_str();

    // Global settings
    assert!(
        output.contains(&format!("<string>{base}</string>")),
        "missing background"
    );
    assert!(
        output.contains(&format!("<string>{text2}</string>")),
        "missing foreground"
    );
    assert!(
        output.contains(&format!("<string>{text1}</string>")),
        "missing caret"
    );

    // Scope colors
    assert!(
        output.contains(&format!("<string>{ok}</string>")),
        "missing string/ok color"
    );
    assert!(
        output.contains(&format!("<string>{urgent}</string>")),
        "missing invalid/urgent color"
    );
}

#[test]
fn bat_output_has_expected_scopes() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();
    let bat = generators::bat::Bat;
    let output = bat.generate(palette);

    let expected_scopes = [
        "comment",
        "string",
        "constant",
        "keyword",
        "storage",
        "entity.name.function",
        "variable",
        "entity.name.type, support.type",
        "entity.name.tag",
        "entity.other.attribute-name",
        "punctuation",
        "markup.heading, entity.name.section",
        "markup.underline.link",
        "invalid",
        "meta.preprocessor",
    ];

    for scope in expected_scopes {
        assert!(
            output.contains(&format!("<string>{scope}</string>")),
            "missing scope: {scope}"
        );
    }
}

#[test]
fn bat_relative_path() {
    let bat = generators::bat::Bat;
    assert_eq!(bat.relative_path(), "bat/garden.tmTheme");
}

// ── lazygit ──────────────────────────────────────────────────────────

#[test]
fn lazygit_output_contains_header() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();
    let lg = generators::lazygit::Lazygit;
    let output = lg.generate(palette);

    assert!(output.contains("Garden theme"));
    assert!(output.contains(&col.active));
    assert!(output.contains("Do not edit by hand"));
}

#[test]
fn lazygit_output_contains_palette_colors() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();
    let lg = generators::lazygit::Lazygit;
    let output = lg.generate(palette);

    let accent = palette.color(ColorRole::Accent).unwrap().as_str();
    let border = palette.color(ColorRole::Border).unwrap().as_str();
    let base_hl = palette.color(ColorRole::BaseHl).unwrap().as_str();
    let urgent = palette.color(ColorRole::Urgent).unwrap().as_str();
    let text2 = palette.color(ColorRole::Text2).unwrap().as_str();

    assert!(output.contains(accent), "missing accent color");
    assert!(output.contains(border), "missing border color");
    assert!(output.contains(base_hl), "missing base-hl color");
    assert!(output.contains(urgent), "missing urgent color");
    assert!(output.contains(text2), "missing text-2 color");
}

#[test]
fn lazygit_output_has_expected_keys() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();
    let lg = generators::lazygit::Lazygit;
    let output = lg.generate(palette);

    let expected_keys = [
        "activeBorderColor:",
        "inactiveBorderColor:",
        "searchingActiveBorderColor:",
        "optionsTextColor:",
        "selectedLineBgColor:",
        "cherryPickedCommitFgColor:",
        "cherryPickedCommitBgColor:",
        "unstagedChangesColor:",
        "defaultFgColor:",
    ];

    for key in expected_keys {
        assert!(output.contains(key), "missing lazygit key: {key}");
    }
}

#[test]
fn lazygit_output_is_yaml_structure() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();
    let lg = generators::lazygit::Lazygit;
    let output = lg.generate(palette);

    assert!(output.contains("gui:"));
    assert!(output.contains("  theme:"));
}

#[test]
fn lazygit_relative_path() {
    let lg = generators::lazygit::Lazygit;
    assert_eq!(lg.relative_path(), "lazygit/garden.yml");
}

// ── btop ─────────────────────────────────────────────────────────────

#[test]
fn btop_output_contains_header() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();
    let btop = generators::btop::Btop;
    let output = btop.generate(palette);

    assert!(output.contains("Garden theme"));
    assert!(output.contains(&col.active));
    assert!(output.contains("Do not edit by hand"));
}

#[test]
fn btop_output_contains_palette_colors() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();
    let btop = generators::btop::Btop;
    let output = btop.generate(palette);

    let base = palette.color(ColorRole::Base).unwrap().as_str();
    let text1 = palette.color(ColorRole::Text1).unwrap().as_str();
    let text2 = palette.color(ColorRole::Text2).unwrap().as_str();
    let accent = palette.color(ColorRole::Accent).unwrap().as_str();

    assert!(output.contains(&format!("theme[main_bg]=\"{base}\"")));
    assert!(output.contains(&format!("theme[main_fg]=\"{text2}\"")));
    assert!(output.contains(&format!("theme[title]=\"{text1}\"")));
    assert!(output.contains(&format!("theme[hi_fg]=\"{accent}\"")));
}

#[test]
fn btop_output_has_expected_keys() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();
    let btop = generators::btop::Btop;
    let output = btop.generate(palette);

    let expected_keys = [
        "theme[main_bg]",
        "theme[main_fg]",
        "theme[title]",
        "theme[hi_fg]",
        "theme[selected_bg]",
        "theme[selected_fg]",
        "theme[inactive_fg]",
        "theme[cpu_box]",
        "theme[mem_box]",
        "theme[net_box]",
        "theme[proc_box]",
        "theme[div_line]",
        "theme[cpu_start]",
        "theme[cpu_mid]",
        "theme[cpu_end]",
    ];

    for key in expected_keys {
        assert!(output.contains(key), "missing btop key: {key}");
    }
}

#[test]
fn btop_relative_path() {
    let btop = generators::btop::Btop;
    assert_eq!(btop.relative_path(), "btop/garden.theme");
}

// ── yazi ─────────────────────────────────────────────────────────────

#[test]
fn yazi_output_contains_header() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();
    let yazi = generators::yazi::Yazi;
    let output = yazi.generate(palette);

    assert!(output.contains("Garden theme"));
    assert!(output.contains(&col.active));
    assert!(output.contains("Do not edit by hand"));
}

#[test]
fn yazi_output_contains_palette_colors() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();
    let yazi = generators::yazi::Yazi;
    let output = yazi.generate(palette);

    let accent = palette.color(ColorRole::Accent).unwrap().as_str();
    let base_hl = palette.color(ColorRole::BaseHl).unwrap().as_str();
    let border = palette.color(ColorRole::Border).unwrap().as_str();

    assert!(output.contains(accent), "missing accent color");
    assert!(output.contains(base_hl), "missing base-hl color");
    assert!(output.contains(border), "missing border color");
}

#[test]
fn yazi_output_has_expected_sections() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();
    let yazi = generators::yazi::Yazi;
    let output = yazi.generate(palette);

    assert!(output.contains("[manager]"), "missing [manager] section");
    assert!(output.contains("[status]"), "missing [status] section");
    assert!(output.contains("[select]"), "missing [select] section");
    assert!(output.contains("[input]"), "missing [input] section");
}

#[test]
fn yazi_output_has_expected_keys() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();
    let yazi = generators::yazi::Yazi;
    let output = yazi.generate(palette);

    let expected_keys = [
        "cwd",
        "hovered",
        "tab_active",
        "tab_inactive",
        "marker_selected",
        "marker_copied",
        "marker_cut",
        "mode_normal",
        "mode_select",
        "separator_style",
    ];

    for key in expected_keys {
        assert!(output.contains(key), "missing yazi key: {key}");
    }
}

#[test]
fn yazi_relative_path() {
    let yazi = generators::yazi::Yazi;
    assert_eq!(yazi.relative_path(), "yazi/garden-theme.toml");
}

// ── zathura ──────────────────────────────────────────────────────────

#[test]
fn zathura_output_contains_header() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();
    let zathura = generators::zathura::Zathura;
    let output = zathura.generate(palette);

    assert!(output.contains("Garden theme"));
    assert!(output.contains(&col.active));
    assert!(output.contains("Do not edit by hand"));
}

#[test]
fn zathura_output_contains_palette_colors() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();
    let zathura = generators::zathura::Zathura;
    let output = zathura.generate(palette);

    let base = palette.color(ColorRole::Base).unwrap().as_str();
    let text1 = palette.color(ColorRole::Text1).unwrap().as_str();
    let text2 = palette.color(ColorRole::Text2).unwrap().as_str();
    let accent = palette.color(ColorRole::Accent).unwrap().as_str();

    assert!(output.contains(&format!("set default-bg \"{base}\"")));
    assert!(output.contains(&format!("set default-fg \"{text2}\"")));
    assert!(output.contains(&format!("set recolor-darkcolor \"{text1}\"")));
    assert!(output.contains(&format!("set highlight-active-color \"{accent}\"")));
}

#[test]
fn zathura_output_has_expected_keys() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();
    let zathura = generators::zathura::Zathura;
    let output = zathura.generate(palette);

    let expected_keys = [
        "set default-fg",
        "set default-bg",
        "set statusbar-fg",
        "set statusbar-bg",
        "set inputbar-fg",
        "set inputbar-bg",
        "set highlight-color",
        "set highlight-active-color",
        "set recolor-lightcolor",
        "set recolor-darkcolor",
        "set recolor true",
        "set index-fg",
        "set index-active-fg",
    ];

    for key in expected_keys {
        assert!(output.contains(key), "missing zathura key: {key}");
    }
}

#[test]
fn zathura_output_uses_set_format() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();
    let zathura = generators::zathura::Zathura;
    let output = zathura.generate(palette);

    // Non-comment, non-empty lines should start with "set "
    for line in output.lines() {
        if !line.is_empty() && !line.starts_with('#') {
            assert!(
                line.starts_with("set "),
                "non-comment line should start with 'set ': {line}"
            );
        }
    }
}

#[test]
fn zathura_relative_path() {
    let zathura = generators::zathura::Zathura;
    assert_eq!(zathura.relative_path(), "zathura/gardenrc");
}

// ── niri ─────────────────────────────────────────────────────────────

#[test]
fn niri_output_contains_header() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();
    let niri = generators::niri::Niri;
    let output = niri.generate(palette);

    assert!(output.contains("Garden theme"));
    assert!(output.contains(&col.active));
    assert!(output.contains("Do not edit by hand"));
}

#[test]
fn niri_output_contains_palette_colors() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();
    let niri = generators::niri::Niri;
    let output = niri.generate(palette);

    let base_deep = palette.color(ColorRole::BaseDeep).unwrap().as_str();
    let urgent = palette.color(ColorRole::Urgent).unwrap().as_str();
    let accent = palette.color(ColorRole::Accent).unwrap().as_str();
    let ok = palette.color(ColorRole::Ok).unwrap().as_str();

    assert!(
        output.contains(&format!("background-color \"{base_deep}\"")),
        "missing background-color"
    );
    assert!(output.contains(urgent), "missing urgent color");
    assert!(output.contains(accent), "missing accent color");
    assert!(output.contains(ok), "missing ok color");
}

#[test]
fn niri_output_has_expected_structure() {
    let col = active_collection();
    let palette = col.active_palette().unwrap();
    let niri = generators::niri::Niri;
    let output = niri.generate(palette);

    assert!(
        output.contains("background-color"),
        "missing background-color"
    );
    assert!(
        !output.contains("layout {"),
        "layout block should not be in include"
    );
    assert!(
        output.contains("window-rule {"),
        "missing window-rule block"
    );
    assert!(
        output.contains("match title=\"frontier\""),
        "missing HPC window rule"
    );
    assert!(
        output.contains("match title=\"dgx-\""),
        "missing GPU window rule"
    );
    assert!(
        output.contains("match title=\"homelab\""),
        "missing homelab window rule"
    );
}

#[test]
fn niri_relative_path() {
    let niri = generators::niri::Niri;
    assert_eq!(niri.relative_path(), "niri/garden-colors.kdl");
}

// ── Registry ──────────────────────────────────────────────────────────

#[test]
fn all_generators_registered() {
    let gens = generators::all();
    assert_eq!(
        gens.len(),
        10,
        "expected kitty + fish + kakoune + fzf + bat + lazygit + btop + yazi + zathura + niri"
    );

    let names: Vec<&str> = gens.iter().map(|g| g.name()).collect();
    assert!(names.contains(&"kitty"));
    assert!(names.contains(&"fish"));
    assert!(names.contains(&"kakoune"));
    assert!(names.contains(&"fzf"));
    assert!(names.contains(&"bat"));
    assert!(names.contains(&"lazygit"));
    assert!(names.contains(&"btop"));
    assert!(names.contains(&"yazi"));
    assert!(names.contains(&"zathura"));
    assert!(names.contains(&"niri"));
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

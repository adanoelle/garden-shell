//! CLI entry point for the Garden theme generator.
//!
//! Reads `palettes.toml`, validates the palette data, and generates
//! theme configuration files for each registered [`ThemeGenerator`].
//!
//! # Usage
//!
//! ```text
//! garden-themes validate <path>
//! garden-themes list <path>
//! garden-themes generate --palettes <path> [--name <palette>] --output <dir>
//! garden-themes apply [--palettes <path>] [--name <palette>]
//! ```

use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

use anyhow::{bail, Context, Result};
use chrono::Utc;
use clap::{Parser, Subcommand};
use garden_core::{Palette, PaletteCollection};
use garden_themes::generators;
use serde::Serialize;

/// Garden theme generator — produces application configs from palettes.toml.
#[derive(Parser)]
#[command(name = "garden-themes", version, about)]
struct Cli {
    #[command(subcommand)]
    command: Cmd,
}

#[derive(Subcommand)]
enum Cmd {
    /// Parse and validate a palettes.toml file, reporting any errors.
    Validate {
        /// Path to the palettes.toml file.
        path: PathBuf,
    },

    /// List all palette names, marking the active one.
    List {
        /// Path to the palettes.toml file.
        path: PathBuf,
    },

    /// Generate theme files for one or all palettes.
    Generate {
        /// Path to the palettes.toml file.
        #[arg(long)]
        palettes: PathBuf,

        /// Generate for a specific palette instead of the active one.
        #[arg(long)]
        name: Option<String>,

        /// Output directory for generated files.
        #[arg(long)]
        output: PathBuf,
    },

    /// Generate themes into ~/.config/garden/themes/ for live use.
    Apply {
        /// Path to the palettes.toml file.
        /// Defaults to $XDG_CONFIG_HOME/garden/palettes.toml.
        #[arg(long)]
        palettes: Option<PathBuf>,

        /// Use a specific palette instead of the active one.
        /// Also updates the `active` field in palettes.toml.
        #[arg(long)]
        name: Option<String>,
    },
}

/// Manifest written to `.manifest.json` after a successful `apply`.
#[derive(Debug, Serialize)]
struct Manifest {
    palette: String,
    generated_at: String,
    generator_version: String,
    files: Vec<String>,
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Cmd::Validate { path } => cmd_validate(&path),
        Cmd::List { path } => cmd_list(&path),
        Cmd::Generate {
            palettes,
            name,
            output,
        } => cmd_generate(&palettes, name.as_deref(), &output),
        Cmd::Apply { palettes, name } => cmd_apply(palettes.as_deref(), name.as_deref()),
    }
}

// ── Helpers ──────────────────────────────────────────────────────────

/// Loads and validates a palette collection from a TOML file.
fn load_palettes(path: &Path) -> Result<PaletteCollection> {
    let col = PaletteCollection::from_file(path)
        .map_err(|e| anyhow::anyhow!(e))
        .context("failed to load palettes")?;

    col.validate()
        .map_err(|errors| anyhow::anyhow!("validation failed:\n  {}", errors.join("\n  ")))?;

    Ok(col)
}

// ── Commands ─────────────────────────────────────────────────────────

/// Parses and validates a `palettes.toml` file, printing diagnostics.
fn cmd_validate(path: &Path) -> Result<()> {
    let col = PaletteCollection::from_file(path)
        .map_err(|e| anyhow::anyhow!(e))
        .context("failed to load palettes")?;

    match col.validate() {
        Ok(()) => {
            println!(
                "ok: {} palette(s), active = \"{}\"",
                col.palettes.len(),
                col.active
            );
            Ok(())
        }
        Err(errors) => {
            for err in &errors {
                eprintln!("error: {err}");
            }
            bail!("{} validation error(s)", errors.len());
        }
    }
}

/// Lists all palettes with their icon, name, and subtitle.
fn cmd_list(path: &Path) -> Result<()> {
    let col = PaletteCollection::from_file(path)
        .map_err(|e| anyhow::anyhow!(e))
        .context("failed to load palettes")?;

    for (key, palette) in &col.palettes {
        let marker = if *key == col.active { " (active)" } else { "" };
        println!(
            "  {} {} — {}{}",
            palette.icon, palette.name, palette.subtitle, marker
        );
    }
    Ok(())
}

/// Generates theme files for the selected (or active) palette.
fn cmd_generate(palettes_path: &Path, name: Option<&str>, output: &Path) -> Result<()> {
    let col = load_palettes(palettes_path)?;

    let palette_name = name.unwrap_or(&col.active);
    let palette = col
        .palettes
        .get(palette_name)
        .with_context(|| format!("palette '{palette_name}' not found"))?;

    let written = write_themes(palette, output)?;
    write_palette_cache(&col, output)?;

    println!(
        "generated {} file(s) for palette \"{}\"",
        written.len(),
        palette_name
    );
    Ok(())
}

/// Generates themes into `$XDG_CONFIG_HOME/garden/themes/` for live use.
fn cmd_apply(palettes_path: Option<&Path>, name: Option<&str>) -> Result<()> {
    let config_home = xdg_config_home()?;
    let garden_dir = config_home.join("garden");

    let palettes_file = match palettes_path {
        Some(p) => p.to_path_buf(),
        None => garden_dir.join("palettes.toml"),
    };

    let mut col = load_palettes(&palettes_file)?;

    // If --name is given, update the active palette and write it back.
    let palette_name = match name {
        Some(n) => {
            if !col.palettes.contains_key(n) {
                bail!("palette '{n}' not found");
            }
            if col.active != n {
                col.active = n.to_string();
                let toml_out = col
                    .to_toml_pretty()
                    .map_err(|e| anyhow::anyhow!(e))
                    .context("failed to serialize palettes")?;
                fs::write(&palettes_file, format!("{toml_out}\n"))
                    .with_context(|| {
                        format!("failed to write {}", palettes_file.display())
                    })?;
                println!("  active palette → \"{n}\"");
            }
            n.to_string()
        }
        None => col.active.clone(),
    };

    let palette = col
        .palettes
        .get(&palette_name)
        .with_context(|| format!("palette '{palette_name}' not found"))?;

    let themes_dir = garden_dir.join("themes");

    // Detect and warn about stale Nix store symlinks before writing.
    clean_stale_symlinks(&themes_dir)?;

    let written = write_themes(palette, &themes_dir)?;
    write_palette_cache(&col, &themes_dir)?;

    // Write manifest.
    let mut manifest_files: Vec<String> = written
        .iter()
        .filter_map(|p| p.strip_prefix(&themes_dir).ok())
        .map(|p| p.to_string_lossy().into_owned())
        .collect();
    manifest_files.push("palettes.json".to_string());

    let manifest = Manifest {
        palette: palette_name.clone(),
        generated_at: Utc::now().format("%Y-%m-%dT%H:%M:%SZ").to_string(),
        generator_version: env!("CARGO_PKG_VERSION").to_string(),
        files: manifest_files,
    };

    let manifest_path = themes_dir.join(".manifest.json");
    let manifest_json =
        serde_json::to_string_pretty(&manifest).context("failed to serialize manifest")?;
    fs::write(&manifest_path, format!("{manifest_json}\n"))
        .with_context(|| format!("failed to write {}", manifest_path.display()))?;
    println!("  wrote {}", manifest_path.display());

    println!(
        "applied {} file(s) for palette \"{}\"",
        written.len(),
        palette_name
    );

    // Reload running applications.
    reload_kitty(&themes_dir);
    reload_fish(&themes_dir);
    reload_kakoune(&themes_dir);

    Ok(())
}

// ── Theme writing ───────────────────────────────────────────────────

/// Writes the full palette collection as JSON to `{output_root}/palettes.json`.
///
/// This cache allows QML (which has `JSON.parse()` but no TOML parser)
/// to read palette data via `FileView { watchChanges: true }`. The file
/// is regenerated on every `generate` and `apply` invocation.
fn write_palette_cache(col: &PaletteCollection, output_root: &Path) -> Result<()> {
    fs::create_dir_all(output_root)
        .with_context(|| format!("failed to create directory {}", output_root.display()))?;

    let json = serde_json::to_string_pretty(col).context("failed to serialize palette cache")?;
    let dest = output_root.join("palettes.json");
    fs::write(&dest, format!("{json}\n"))
        .with_context(|| format!("failed to write {}", dest.display()))?;

    println!("  wrote {}", dest.display());
    Ok(())
}

/// Generates theme files for all registered generators, writing them
/// under `output_root`. Returns the list of files written.
fn write_themes(palette: &Palette, output_root: &Path) -> Result<Vec<PathBuf>> {
    let generators = generators::all();
    let mut written = Vec::with_capacity(generators.len());

    for gen in &generators {
        let content = gen.generate(palette);
        let dest = output_root.join(gen.relative_path());

        if let Some(parent) = dest.parent() {
            fs::create_dir_all(parent)
                .with_context(|| format!("failed to create directory {}", parent.display()))?;
        }

        fs::write(&dest, &content)
            .with_context(|| format!("failed to write {}", dest.display()))?;

        println!("  wrote {}", dest.display());
        written.push(dest);
    }

    Ok(written)
}

/// Resolves `$XDG_CONFIG_HOME`, falling back to `$HOME/.config`.
fn xdg_config_home() -> Result<PathBuf> {
    if let Ok(xdg) = std::env::var("XDG_CONFIG_HOME") {
        if !xdg.is_empty() {
            return Ok(PathBuf::from(xdg));
        }
    }
    let home = std::env::var("HOME").context("neither $XDG_CONFIG_HOME nor $HOME is set")?;
    Ok(PathBuf::from(home).join(".config"))
}

// ── Stale symlink cleanup ───────────────────────────────────────────

/// Removes stale symlinks in `themes_dir` that point into `/nix/store/`,
/// warning the user about each one. Non-symlink files and valid symlinks
/// are left untouched.
fn clean_stale_symlinks(themes_dir: &Path) -> Result<()> {
    if !themes_dir.exists() {
        return Ok(());
    }

    // Walk one level of subdirectories (e.g. themes/kitty/, themes/kak/).
    for entry in fs::read_dir(themes_dir).context("failed to read themes directory")? {
        let entry = entry?;
        let path = entry.path();

        if path.is_dir() {
            clean_stale_symlinks_in(&path)?;
        } else {
            check_and_remove_stale_symlink(&path)?;
        }
    }
    Ok(())
}

fn clean_stale_symlinks_in(dir: &Path) -> Result<()> {
    for entry in fs::read_dir(dir)? {
        let entry = entry?;
        check_and_remove_stale_symlink(&entry.path())?;
    }
    Ok(())
}

fn check_and_remove_stale_symlink(path: &Path) -> Result<()> {
    let meta = match fs::symlink_metadata(path) {
        Ok(m) => m,
        Err(_) => return Ok(()),
    };

    if !meta.is_symlink() {
        return Ok(());
    }

    if let Ok(target) = fs::read_link(path) {
        if target.to_string_lossy().starts_with("/nix/store/") {
            eprintln!(
                "  warning: removing stale Nix store symlink {}",
                path.display()
            );
            fs::remove_file(path)
                .with_context(|| format!("failed to remove symlink {}", path.display()))?;
        }
    }
    Ok(())
}

// ── Application reloads ─────────────────────────────────────────────

/// Tells running kitty instances to pick up the new theme.
///
/// Two-pronged approach:
/// 1. `kitty @ set-colors --all` for the current instance (immediate,
///    updates in-memory colors without config reload).
/// 2. `pkill -USR1 kitty` to signal ALL kitty processes to reload
///    their config. This picks up the new theme via the `include`
///    directive in kitty.conf — which must point to the mutable
///    themes directory, not the Nix store.
fn reload_kitty(themes_dir: &Path) {
    let theme_file = themes_dir.join("kitty/garden-theme.conf");
    if !theme_file.exists() {
        return;
    }

    // Immediate update for the current kitty instance (if run from inside kitty).
    let mut args = vec!["@".to_string()];
    if let Ok(socket) = std::env::var("KITTY_LISTEN_ON") {
        if !socket.is_empty() {
            args.push("--to".to_string());
            args.push(socket);
        }
    }
    args.extend([
        "set-colors".to_string(),
        "--all".to_string(),
        "--configured".to_string(),
        theme_file.to_string_lossy().into_owned(),
    ]);

    let _ = Command::new("kitty")
        .args(&args)
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();

    // Signal all kitty processes to reload config (picks up new include).
    let sigusr1 = Command::new("pkill")
        .args(["-USR1", "kitty"])
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();

    if matches!(sigusr1, Ok(s) if s.success()) {
        println!("  reloaded kitty");
    }
}

/// Sources the fish theme file to update universal variables.
///
/// Uses `fish -c 'source <file>'` which sets universal variables that
/// propagate to all running fish sessions immediately.
fn reload_fish(themes_dir: &Path) {
    let theme_file = themes_dir.join("fish/garden-theme.fish");
    if !theme_file.exists() {
        return;
    }

    let status = Command::new("fish")
        .args(["-c", &format!("source '{}'", theme_file.display())])
        .stdin(Stdio::null())
        .stdout(Stdio::null())
        .stderr(Stdio::null())
        .status();

    if matches!(status, Ok(s) if s.success()) {
        println!("  reloaded fish");
    }
}

/// Sends the theme to all running kakoune sessions.
///
/// Iterates kakoune sessions via `kak -l` and pipes the theme file
/// to each one via `kak -p <session>`.
fn reload_kakoune(themes_dir: &Path) {
    let theme_file = themes_dir.join("kak/garden.kak");
    if !theme_file.exists() {
        return;
    }

    let sessions = match Command::new("kak").arg("-l").output() {
        Ok(output) if output.status.success() => output,
        _ => return,
    };

    let session_list = String::from_utf8_lossy(&sessions.stdout);
    let mut reloaded = 0;

    for session in session_list.lines() {
        let session = session.trim();
        if session.is_empty() {
            continue;
        }

        let status = Command::new("kak")
            .args(["-p", session])
            .stdin(Stdio::piped())
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .spawn()
            .and_then(|mut child| {
                if let Some(ref mut stdin) = child.stdin {
                    let _ = writeln!(stdin, "try %{{ source {} }}", theme_file.display());
                }
                child.wait()
            });

        if matches!(status, Ok(s) if s.success()) {
            reloaded += 1;
        }
    }

    if reloaded > 0 {
        println!("  reloaded {reloaded} kakoune session(s)");
    }
}

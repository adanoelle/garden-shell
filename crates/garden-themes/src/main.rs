//! CLI entry point for the Garden theme generator.
//!
//! Reads `palettes.json`, validates the palette data, and generates
//! theme configuration files for each registered [`ThemeGenerator`].
//!
//! # Usage
//!
//! ```text
//! garden-themes validate <path>
//! garden-themes list <path>
//! garden-themes generate --palettes <path> [--name <palette>] --output <dir>
//! ```

use std::fs;
use std::path::PathBuf;

use anyhow::{bail, Context, Result};
use clap::{Parser, Subcommand};
use garden_core::PaletteCollection;
use garden_themes::generators;

/// Garden theme generator — produces application configs from palettes.json.
#[derive(Parser)]
#[command(name = "garden-themes", version, about)]
struct Cli {
    #[command(subcommand)]
    command: Command,
}

#[derive(Subcommand)]
enum Command {
    /// Parse and validate a palettes.json file, reporting any errors.
    Validate {
        /// Path to the palettes.json file.
        path: PathBuf,
    },

    /// List all palette names, marking the active one.
    List {
        /// Path to the palettes.json file.
        path: PathBuf,
    },

    /// Generate theme files for one or all palettes.
    Generate {
        /// Path to the palettes.json file.
        #[arg(long)]
        palettes: PathBuf,

        /// Generate for a specific palette instead of the active one.
        #[arg(long)]
        name: Option<String>,

        /// Output directory for generated files.
        #[arg(long)]
        output: PathBuf,
    },
}

fn main() -> Result<()> {
    let cli = Cli::parse();

    match cli.command {
        Command::Validate { path } => cmd_validate(&path),
        Command::List { path } => cmd_list(&path),
        Command::Generate {
            palettes,
            name,
            output,
        } => cmd_generate(&palettes, name.as_deref(), &output),
    }
}

/// Parses and validates a `palettes.json` file, printing diagnostics.
fn cmd_validate(path: &PathBuf) -> Result<()> {
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
fn cmd_list(path: &PathBuf) -> Result<()> {
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
fn cmd_generate(palettes_path: &PathBuf, name: Option<&str>, output: &PathBuf) -> Result<()> {
    let col = PaletteCollection::from_file(palettes_path)
        .map_err(|e| anyhow::anyhow!(e))
        .context("failed to load palettes")?;

    col.validate()
        .map_err(|errors| anyhow::anyhow!("validation failed:\n  {}", errors.join("\n  ")))?;

    let palette_name = name.unwrap_or(&col.active);
    let palette = col
        .palettes
        .get(palette_name)
        .with_context(|| format!("palette '{palette_name}' not found"))?;

    let generators = generators::all();
    for gen in &generators {
        let content = gen.generate(palette);
        let dest = output.join(gen.relative_path());

        if let Some(parent) = dest.parent() {
            fs::create_dir_all(parent)
                .with_context(|| format!("failed to create directory {}", parent.display()))?;
        }

        fs::write(&dest, &content)
            .with_context(|| format!("failed to write {}", dest.display()))?;

        println!("  wrote {}", dest.display());
    }

    println!(
        "generated {} file(s) for palette \"{}\"",
        generators.len(),
        palette_name
    );
    Ok(())
}

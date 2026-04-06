use clap::Parser;

#[derive(Parser)]
#[command(name = "garden-ctl", about = "Garden infrastructure CLI")]
enum Cli {
    /// Show daemon status
    Status,
    /// Watch events in real time
    Watch,
    /// Check host health
    Health,
}

fn main() {
    let _cli = Cli::parse();
    println!("garden-ctl (stub)");
}

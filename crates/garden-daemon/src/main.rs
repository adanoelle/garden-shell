use anyhow::Result;

fn main() -> Result<()> {
    tracing_subscriber::fmt::init();
    tracing::info!("garden-daemon starting (stub)");
    Ok(())
}

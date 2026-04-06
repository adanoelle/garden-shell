use serde::{Deserialize, Serialize};

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum HostTier {
    Critical,
    Standard,
    Local,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum ConnectionState {
    Connected,
    Disconnected,
    Degraded,
    Unknown,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct HostConfig {
    pub name: String,
    pub tier: HostTier,
    pub address: String,
    pub user: String,
}

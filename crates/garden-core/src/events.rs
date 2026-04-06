use serde::{Deserialize, Serialize};

use crate::ConnectionState;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub enum GardenEvent {
    ConnectionChanged {
        host: String,
        state: ConnectionState,
    },
    JobSubmitted {
        id: String,
        host: String,
    },
    JobCompleted {
        id: String,
        exit_code: i32,
    },
    HealthCheck {
        host: String,
        healthy: bool,
    },
}

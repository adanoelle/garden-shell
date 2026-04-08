# Garden Infrastructure — Design Context

> Rust-based systems layer: SSH management, connection monitoring,
> job orchestration, and a TUI control plane for distributed HPC
> research computing.

**Last updated:** 2026-03-12
**Related docs:** `00-overview.md`, `01-design-philosophy.md`, `03-palette-and-theming.md`

---

## 1. Overview

Garden Infrastructure is a Rust workspace that provides the reliable
systems layer beneath Garden Shell. It manages SSH connections to remote
compute resources, monitors connection health, tracks SLURM jobs, and
coordinates autoresearch agents — all exposed via a Unix socket API
that the shell, TUI, and CLI consume.

### The Three Concerns

```
MONITORING        What's connected? What's healthy? What changed?
ORCHESTRATION     What experiments to run? Where? When? In what order?
OBSERVATION       What's happening right now? (shell = ambient, TUI = detailed)
```

These are separated so each can evolve independently:
- Monitoring is a daemon (always on, lightweight)
- Orchestration is a separate process (complex, iterated frequently)
- Observation is presentation (shell + TUI, multiple views of same data)

---

## 2. Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                        │
│                                                             │
│  Garden Shell (Quickshell/QML)     Ratatui Control Plane    │
│  ├─ bar connection dots            ├─ connection dashboard   │
│  ├─ host indicator                 ├─ job queue view         │
│  ├─ notifications                  ├─ experiment history     │
│  └─ ambient, glanceable            ├─ resource utilization   │
│                                    └─ detailed, interactive  │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                    QUERY INTERFACE                           │
│                                                             │
│  garden-ctl (CLI)                                           │
│  ├─ garden-ctl status              (connection health)       │
│  ├─ garden-ctl jobs                (SLURM job list)          │
│  ├─ garden-ctl submit              (submit experiment)       │
│  ├─ garden-ctl connect frontier    (establish connection)    │
│  └─ garden-ctl watch               (streaming event output)  │
│                                                             │
│  Unix socket: ~/.local/run/garden/daemon.sock                │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                    CORE DAEMON                               │
│                                                             │
│  garden-daemon (systemd user service)                        │
│  ├─ ConnectionMonitor              (SSH socket watcher)      │
│  ├─ HealthChecker                  (periodic keepalive)      │
│  ├─ JobTracker                     (SLURM state polling)     │
│  ├─ EventBus                       (pub/sub for all state)   │
│  └─ IPC Server                     (Unix socket API)         │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                    AUTORESEARCH (separate process)            │
│                                                             │
│  garden-autoresearch                                         │
│  ├─ Scheduler                      (experiment queue)        │
│  ├─ SlurmBridge                    (job submission)          │
│  ├─ MetricsCollector               (result gathering)        │
│  └─ AgentCoordinator               (multi-agent workflows)   │
│  Communicates with daemon via same Unix socket API            │
│                                                             │
├─────────────────────────────────────────────────────────────┤
│                    HOST INTERFACE                             │
│                                                             │
│  SSH ControlMaster sockets     (~/.ssh/sockets/)             │
│  ├─ ada@frontier-login01-22                                  │
│  ├─ ada@dgx-alpha-22                                         │
│  ├─ ada@dgx-beta-22                                          │
│  └─ ada@homelab-22                                           │
│                                                             │
│  Remote commands via SSH (sbatch, squeue, nvidia-smi, etc.)  │
└─────────────────────────────────────────────────────────────┘
```

### Key Architectural Decisions
- **Daemon is persistent** — systemd user service, always running
- **Autoresearch is separate** — its own process communicating with
  the daemon, so it can be iterated/restarted independently
- **Storage starts with SQLite** — hexagonal architecture with
  trait-based storage port allows swap to DuckDB/Postgres later
- **Single workspace** — all crates in one Cargo workspace for
  synchronized types and easy cross-crate development

---

## 3. SSH Management

### The Problem
ORNL compute resources (Frontier, Andes, Summit) require physical
token authentication (RSA SecurID / YubiKey). Each SSH connection
needs a physical interaction. In an agent-orchestrated workflow with
dozens of SLURM operations per hour, re-authenticating each time
is not viable.

### Solution: ControlMaster Multiplexing

Authenticate once, reuse for all operations within a time window.

**SSH Config** (generated from NixOS configuration):
```
Host frontier* andes* summit*
    HostName %h.olcf.ornl.gov
    User ada
    ProxyJump bastion.olcf.ornl.gov
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 8h
    ServerAliveInterval 60
    ServerAliveCountMax 3

Host dgx-*
    User ada
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 8h
    ServerAliveInterval 30
    ServerAliveCountMax 3

Host homelab*
    User ada
    ControlMaster auto
    ControlPath ~/.ssh/sockets/%r@%h-%p
    ControlPersist 12h
```

### ControlPersist Windows
- **OLCF (8h):** full work session; re-auth once in the morning
- **DGX (8h):** full work session; matches OLCF for consistency
- **Homelab (12h):** personal hardware, low risk, long window

### Socket Directory as Connection Registry

`~/.ssh/sockets/` contains active ControlMaster sockets.
The daemon monitors this directory with inotify:
- Socket appears → `ConnectionEstablished` event
- Socket disappears → `ConnectionLost` event
- `ssh -O check` fails → `ConnectionStale` event

### Host Detection — Three-Layer System

1. **SSH config auto-import** — daemon reads `~/.ssh/config` at startup,
   discovers all Host entries, populates host registry with default tier
2. **Tier assignment via patterns** — glob patterns assign hosts to tiers:
   ```
   hpc:  frontier*, summit*, andes*    → urgent (earthy red)
   gpu:  dgx-*                         → accent (warm gold)
   home: homelab*                      → ok (muted green)
   ```
3. **Window title matching** — for focused-window host indicator in the
   shell bar, matches terminal window titles against the host registry

### Host Tiers

Constrained to named tiers using palette semantic roles:
```
hpc       → color: "urgent"    — production supercomputers,
                                  mistakes are expensive and visible
gpu       → color: "accent"    — GPU compute, powerful but recoverable
home      → color: "ok"        — personal hardware, low stakes
cloud     → color: "text-2"    — ephemeral instances (future)
unknown   → color: "text-3"    — detected but uncategorized
(local)   → no indicator       — you're home
```

### Nested SSH / Jump Hosts
- Bar indicator shows **final destination** (where commands execute)
- Tooltip/inspect shows **full chain** (local → bastion → destination)
- Chain detection via SSH config `ProxyJump` directives (more reliable
  than runtime process tree inspection)

### NixOS Configuration

```nix
gardenShell.ssh = {
  socketDir = "~/.ssh/sockets";

  hostGroups = {
    olcf = {
      hosts = ["frontier*" "andes*" "summit*"];
      proxyJump = "bastion.olcf.ornl.gov";
      user = "ada";
      controlPersist = "8h";
      keepAliveInterval = 60;
      tier = "hpc";
    };
    gpu = {
      hosts = ["dgx-*"];
      user = "ada";
      controlPersist = "8h";
      keepAliveInterval = 30;
      tier = "gpu";
    };
    home = {
      hosts = ["homelab*"];
      user = "ada";
      controlPersist = "12h";
      tier = "home";
    };
  };

  monitoredConnections = [
    "frontier-login01"
    "dgx-alpha"
    "dgx-beta"
    "homelab"
  ];

  showConnectionHealth = true;
};
```

Generates both `~/.ssh/config` and the daemon's host configuration.

---

## 4. Connection Health Monitoring

### Bar Integration (via Garden Shell)

When bar is in full density mode, connection health dots appear
in the metrics zone:

```
▪ frontier  ▪ dgx-α  ▪ dgx-β      cpu 8%  mem 4.1g
```

- **▪ (solid, tier color)** — socket alive, last health check passed
- **▫ (hollow)** — socket exists but last keepalive failed
- **absent** — no connection

### Health Check Mechanism

The daemon periodically runs `ssh -O check <host>` against each
monitored socket:
- Default interval: 5 minutes (configurable)
- On failure: emit `HealthCheckFailed` event, mark connection stale
- On 3 consecutive failures: emit `ConnectionLost` event

### Authentication Lifecycle

```
morning:
  you run `ssh frontier` (or `garden-ctl connect frontier`)
  → physical token prompt appears
  → you authenticate
  → ControlMaster socket created
  → daemon detects socket → ConnectionEstablished event
  → bar shows solid health dot
  → agents can now use the connection

8 hours later (or on network disruption):
  → ControlPersist expires or keepalive fails
  → daemon detects → ConnectionLost event
  → bar shows absent dot
  → notification: "frontier connection lost — re-authenticate"
  → agents queue pending work → AuthenticationNeeded event

you re-authenticate:
  → cycle repeats
  → agents resume queued work automatically
```

### Queue-and-Notify on Connection Drop

When the daemon detects a connection loss for a host with active
or pending agent work:
1. All pending SSH commands for that host are queued (not dropped)
2. `AuthenticationNeeded` event fires
3. Shell shows notification: "frontier connection needed — please
   re-authenticate" with a "reconnect" action
4. Clicking "reconnect" opens a terminal with `ssh <host>` pre-filled
5. After authentication, daemon detects new socket, dequeues work,
   agents resume automatically

---

## 5. Event System

### EventBus

All state changes in the daemon are events. Clients subscribe to
the events they care about.

```rust
pub enum GardenEvent {
    // Connection lifecycle
    ConnectionEstablished { host: String, tier: HostTier, timestamp: DateTime<Utc> },
    ConnectionLost { host: String, reason: String, timestamp: DateTime<Utc> },
    ConnectionStale { host: String, timestamp: DateTime<Utc> },
    AuthenticationNeeded { host: String, queued_commands: usize },

    // Job lifecycle
    JobSubmitted { id: JobId, host: String, config: ExperimentConfig },
    JobStateChanged { id: JobId, old_state: JobState, new_state: JobState },
    JobCompleted { id: JobId, result: JobResult, wall_time: Duration },
    JobFailed { id: JobId, error: String },

    // Agent lifecycle
    AgentStarted { name: String },
    AgentAction { name: String, action: String },
    AgentError { name: String, error: String },
    AgentIdle { name: String, reason: String },

    // Health
    HealthCheckPassed { host: String, latency_ms: u64 },
    HealthCheckFailed { host: String, error: String },
}
```

### Client Subscriptions

```
Garden Shell subscribes to:
  ConnectionEstablished, ConnectionLost, ConnectionStale,
  AuthenticationNeeded, HealthCheckFailed,
  JobCompleted, JobFailed

Ratatui TUI subscribes to:
  (everything — it's the detailed view)

Autoresearch subscribes to:
  ConnectionEstablished, ConnectionLost, AuthenticationNeeded,
  JobStateChanged, JobCompleted, JobFailed
```

### Streaming Interface

`garden-ctl watch --json` streams events as newline-delimited JSON:
```json
{"type":"ConnectionEstablished","host":"frontier-login01","tier":"hpc","timestamp":"2026-03-12T14:15:00Z"}
{"type":"HealthCheckPassed","host":"frontier-login01","latency_ms":42}
{"type":"JobSubmitted","id":"48291","host":"frontier-login01","config":"sweep_v3.toml"}
```

Garden Shell consumes this via a Quickshell `Process` with streaming
stdout parsing.

---

## 6. Crate Architecture

### Workspace Structure

```
garden-infra/
  Cargo.toml                    # workspace root

  crates/
    garden-core/                # shared types, traits, EventBus
      src/
        lib.rs
        events.rs               # GardenEvent enum
        hosts.rs                # HostConfig, HostTier, ConnectionState
        jobs.rs                 # JobId, JobState, ExperimentConfig
        ports.rs                # RemoteExecutor, StoragePort traits
        config.rs               # configuration types

    garden-ssh/                 # SSH ControlMaster adapter
      src/
        lib.rs
        monitor.rs              # inotify socket directory watcher
        health.rs               # periodic keepalive checker
        executor.rs             # RemoteExecutor implementation
        config_parser.rs        # SSH config file parser

    garden-daemon/              # long-running infrastructure service
      src/
        main.rs
        server.rs               # Unix socket IPC server
        job_tracker.rs          # SLURM state polling
        state.rs                # aggregated daemon state

    garden-ctl/                 # CLI tool
      src/
        main.rs                 # clap-based CLI

    garden-tui/                 # Ratatui control plane
      src/
        main.rs
        app.rs                  # application state + event loop
        theme.rs                # Garden palette for Ratatui
        ui/
          connections.rs        # connection health panel
          jobs.rs               # SLURM job panel
          agents.rs             # agent status panel
          events.rs             # event log panel
          layout.rs             # panel arrangement

    garden-autoresearch/        # experiment orchestration (separate binary)
      src/
        lib.rs
        main.rs                 # runs as independent process
        scheduler.rs            # experiment queue + scheduling logic
        slurm.rs                # SLURM script generation (train.py template)
        metrics.rs              # metrics collection + emission protocol
        config.rs               # ExperimentConfig parsing
        agents/
          mod.rs
          trainer.rs            # training run agent
          evaluator.rs          # evaluation suite agent
          sweeper.rs            # hyperparameter sweep agent
          collector.rs          # result collection agent

  config/
    palettes.json               # shared palette (for TUI theme)
```

### Dependency Graph

```
garden-core          (no internal deps — types and traits only)
  ↑
garden-ssh           (depends on garden-core)
  ↑
garden-daemon        (depends on garden-core, garden-ssh)
  ↑
garden-ctl           (depends on garden-core — talks to daemon via socket)
garden-tui           (depends on garden-core — talks to daemon via socket)
garden-autoresearch  (depends on garden-core — talks to daemon via socket)
```

The critical boundary: `garden-autoresearch` depends only on `garden-core`
types and the daemon's socket API. It does not depend on `garden-ssh`
directly. All SSH operations go through the daemon. This means autoresearch
can be developed, tested, and deployed independently.

---

## 7. Core Traits (Hexagonal Architecture)

```rust
// ─── Storage Port ───
#[async_trait]
pub trait StoragePort: Send + Sync {
    // Jobs
    async fn record_submission(&self, job: &JobSubmission) -> Result<JobId>;
    async fn update_job_state(&self, id: JobId, state: JobState) -> Result<()>;
    async fn get_job(&self, id: JobId) -> Result<Option<Job>>;
    async fn list_jobs(&self, filter: JobFilter) -> Result<Vec<Job>>;

    // Experiments
    async fn record_experiment(&self, exp: &Experiment) -> Result<ExperimentId>;
    async fn get_experiment(&self, id: ExperimentId) -> Result<Option<Experiment>>;
    async fn list_experiments(&self, filter: ExpFilter) -> Result<Vec<Experiment>>;

    // Metrics
    async fn store_metrics(&self, job_id: JobId, metrics: &Metrics) -> Result<()>;
    async fn get_metrics(&self, job_id: JobId) -> Result<Vec<Metrics>>;

    // Connection logs
    async fn log_connection_event(&self, event: &ConnectionEvent) -> Result<()>;
    async fn connection_history(&self, host: &str, since: DateTime<Utc>) -> Result<Vec<ConnectionEvent>>;
}

// ─── Remote Execution Port ───
#[async_trait]
pub trait RemoteExecutor: Send + Sync {
    async fn exec(&self, host: &str, command: &str) -> Result<ExecOutput>;
    async fn exec_with_timeout(&self, host: &str, command: &str, timeout: Duration) -> Result<ExecOutput>;
    async fn transfer_to(&self, host: &str, local: &Path, remote: &Path) -> Result<()>;
    async fn transfer_from(&self, host: &str, remote: &Path, local: &Path) -> Result<()>;
    fn connection_status(&self, host: &str) -> ConnectionState;
}

// ─── Notification Port ───
#[async_trait]
pub trait NotificationEmitter: Send + Sync {
    async fn notify(&self, notification: GardenNotification) -> Result<()>;
}
```

Initial adapters:
- `StoragePort` → SQLite (swap to DuckDB when analytical queries bottleneck)
- `RemoteExecutor` → SSH ControlMaster
- `NotificationEmitter` → D-Bus desktop notifications (Garden Shell picks these up)

---

## 8. Autoresearch System

### Relationship to Daemon
Autoresearch runs as a **separate process** that communicates with
the daemon via the Unix socket API. This separation means:
- Autoresearch can be restarted without affecting monitoring
- The daemon can run without autoresearch (pure infra monitoring)
- Autoresearch can be iterated rapidly without daemon rebuilds
- Multiple autoresearch instances could run for different projects

### Core Flow

```
1. Define experiment config (TOML)
2. Autoresearch reads config, generates SLURM script
3. Autoresearch calls daemon API → daemon executes sbatch via SSH
4. Daemon tracks job state via squeue polling
5. Daemon fires JobStateChanged events
6. Autoresearch responds to events:
   - JobCompleted → collect metrics, schedule next experiment
   - JobFailed → log error, optionally retry
   - ConnectionLost → queue pending work, wait for reconnect
7. Results stored in SQLite via daemon's StoragePort
```

### Remaining Gaps (from autoresearch-hpc.md)
- [ ] `train.py` template — standardized training script format
- [ ] SLURM script generation — translating ExperimentConfig to sbatch
- [ ] Metrics emission protocol — how training jobs report metrics back
- [ ] Security model — partially addressed by ControlMaster auth lifecycle

### Agent Architecture

Autoresearch uses multiple cooperating agents:

```
Scheduler       — decides what to run next based on results so far
Trainer         — submits training runs, monitors convergence
Evaluator       — runs evaluation suites on checkpoints
Sweeper         — manages hyperparameter searches
Collector       — gathers results, metrics, artifacts from remote hosts
```

Agents communicate through the EventBus. The Scheduler makes decisions;
the other agents execute. This mirrors the Karpathy-style autonomous
experimentation workflow where the system continuously proposes, runs,
evaluates, and learns from experiments.

---

## 9. Ratatui Control Plane

### Purpose
Detailed interactive view of the entire infrastructure state.
Opened in a terminal as a page in the `system` or `research` channel.

### Layout

```
┌─ connections ──────────────────────┬─ jobs ─────────────────────────────┐
│                                    │                                     │
│ ● frontier-login01     4h 12m      │ 48291  train_v3     RUNNING  0:18   │
│   socket: alive, 3 sessions        │ 48292  eval_suite   PENDING  --     │
│   last check: 2s ago               │ 48293  sweep_lr     RUNNING  0:04   │
│                                    │ 48294  baseline_2   QUEUED   --     │
│ ● dgx-α.internal      2h 38m      │                                     │
│   socket: alive, 1 session         │ ┌─ 48291 detail ─────────────────┐ │
│   gpu: 2/4 in use                  │ │ nodes: 4                       │ │
│                                    │ │ wall: 0:18:42 / 0:30:00        │ │
│ ● dgx-β.internal      2h 38m      │ │ config: sweep_v3.toml          │ │
│   socket: alive, 0 sessions        │ │ output: /lustre/ada/exp/48291  │ │
│                                    │ │ metrics: loss=0.342 lr=3e-4    │ │
│ ○ homelab.local        disconnected │ └────────────────────────────────┘ │
│   last seen: 1d ago                │                                     │
│                                    │                                     │
├─ agents ───────────────────────────┼─ event log ─────────────────────────┤
│                                    │                                     │
│ scheduler    idle                  │ 14:32:08  job 48293 RUNNING         │
│   next: eval_suite when 48291 done │ 14:28:15  job 48293 submitted       │
│                                    │ 14:25:01  health check ok (all)     │
│ collector    watching 48291, 48293  │ 14:20:00  health check ok (all)     │
│   last metric: 12s ago             │ 14:18:42  job 48291 RUNNING         │
│                                    │ 14:18:40  job 48291 submitted       │
│ monitor      polling (30s cycle)    │ 14:15:00  connection: frontier up   │
│                                    │ 14:14:52  auth completed: frontier  │
└────────────────────────────────────┴─────────────────────────────────────┘
```

### Navigation
- `h/j/k/l` between panels
- `Enter` to expand details
- `Tab` to cycle panels
- `/` to filter event log
- `q` to quit
- Vim-style keybindings throughout

### Theming
Ratatui colors derived from `palettes.json` — same palette generator
pipeline as the shell and all other apps. The TUI feels like Garden.

---

## 10. CLI Reference

```
garden-ctl status [host]                    # connection health
garden-ctl status --json                    # machine-readable
garden-ctl jobs [--host HOST] [--state S]   # SLURM job list
garden-ctl jobs --json                      # machine-readable
garden-ctl submit EXPERIMENT.toml           # submit experiment
garden-ctl connect HOST                     # open terminal for auth
garden-ctl disconnect HOST                  # close ControlMaster
garden-ctl watch [--json]                   # stream events
garden-ctl watch --filter CONNECTION        # filter event types
garden-ctl health                           # run health check now
garden-ctl agents                           # list autoresearch agents
garden-ctl config                           # show daemon configuration
```

---

## 11. NixOS Integration

### Systemd User Service

```nix
systemd.user.services.garden-daemon = {
  description = "Garden infrastructure daemon";
  wantedBy = ["default.target"];
  after = ["network.target"];
  serviceConfig = {
    ExecStart = "${pkgs.garden-infra}/bin/garden-daemon";
    Restart = "on-failure";
    RestartSec = 5;
    Environment = [
      "GARDEN_CONFIG_DIR=%h/.config/garden"
      "GARDEN_SSH_SOCKET_DIR=%h/.ssh/sockets"
      "GARDEN_DB_PATH=%h/.local/share/garden/garden.db"
      "GARDEN_SOCKET_PATH=%t/garden/daemon.sock"
    ];
  };
};
```

### SSH Config Generation

The NixOS module generates `~/.ssh/config` from `gardenShell.ssh`
configuration, including all ControlMaster settings, ProxyJump
directives, and keepalive intervals.

### Flake Structure

```nix
{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    garden-infra.url = "github:ada/garden-infra";
  };

  outputs = { self, nixpkgs, garden-infra, ... }: {
    nixosConfigurations.workstation = nixpkgs.lib.nixosSystem {
      modules = [
        garden-infra.nixosModules.default
        ./configuration.nix
      ];
    };
  };
}
```

---

## 12. Build Order

1. **garden-core** — types, traits, EventBus
2. **garden-ssh** — ControlMaster monitor, health checker, executor
3. **garden-daemon** — systemd service, IPC server, basic state
4. **garden-ctl** — CLI with `status`, `watch`, `connect`, `health`
5. **Shell integration** — `garden-ctl watch --json` consumed by Quickshell
6. **garden-tui** — Ratatui control plane with connection + event panels
7. **garden-autoresearch: core** — scheduler, SlurmBridge basics
8. **garden-autoresearch: agents** — trainer, evaluator, sweeper, collector
9. **garden-tui: job + agent panels** — detailed views
10. **Metrics pipeline** — metrics emission from remote jobs to SQLite
11. **NixOS module** — full SSH config + systemd service generation

---

## 13. Open Questions (Infrastructure-Specific)

- [ ] Should garden-daemon manage its own SQLite WAL checkpointing,
      or rely on SQLite defaults?
- [ ] Autoresearch ↔ daemon communication: structured RPC (e.g. tonic/gRPC)
      over the Unix socket, or simpler JSON-lines protocol?
- [ ] Should the TUI support multiple daemon connections (e.g. monitoring
      a remote daemon on a colleague's machine)?
- [ ] Job metrics: pull-based (daemon polls remote files) or push-based
      (training script sends metrics to daemon)?
- [ ] Should connection health checks run more frequently when agents
      have pending work? (adaptive interval)
- [ ] garden-autoresearch: should experiment configs be TOML, JSON, or
      a custom DSL?
- [ ] How to handle SLURM allocation quotas — should the scheduler be
      aware of project allocation limits?
- [ ] Should the daemon expose a REST API in addition to Unix socket,
      for potential web UI or remote monitoring?
- [ ] Log retention: how long to keep event history in SQLite?
      Auto-archive after N days?
- [ ] Should garden-ctl support shell completions (bash, zsh, fish, nushell)?

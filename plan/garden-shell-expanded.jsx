import { useState, useEffect, useCallback, useRef } from "react";

// ═══════════════════════════════════════════════════
// Garden Shell — Expanded Desktop Shell Mockup
// Are.na structure × PC-98 materiality × Farrow & Ball warmth
// ═══════════════════════════════════════════════════

const P = {
  surface: "#2c3444",
  surfaceDeep: "#232b38",
  surfaceRaised: "#343d4f",
  surfaceHighlight: "#3d4759",
  border: "#4a5568",
  borderSubtle: "#3a4456",
  borderFaint: "#323b4b",
  textPrimary: "#d4c5a9",
  textSecondary: "#8b9bb0",
  textMuted: "#6b7a8d",
  textFaint: "#505e70",
  accent: "#c9b88c",
  urgent: "#c4796b",
  barBg: "#252d3b",
  lockBg: "#1e2430",
};

const DITHER_DENSE = `url("data:image/svg+xml,%3Csvg width='2' height='2' xmlns='http://www.w3.org/2000/svg'%3E%3Crect x='0' y='0' width='1' height='1' fill='%23232b38' fill-opacity='0.88'/%3E%3Crect x='1' y='1' width='1' height='1' fill='%23232b38' fill-opacity='0.88'/%3E%3C/svg%3E")`;

const DITHER_LIGHT = `url("data:image/svg+xml,%3Csvg width='4' height='4' xmlns='http://www.w3.org/2000/svg'%3E%3Crect x='0' y='0' width='1' height='1' fill='%23232b38' fill-opacity='0.5'/%3E%3Crect x='2' y='2' width='1' height='1' fill='%23232b38' fill-opacity='0.5'/%3E%3C/svg%3E")`;

const DITHER_LOCK = `url("data:image/svg+xml,%3Csvg width='6' height='6' xmlns='http://www.w3.org/2000/svg'%3E%3Crect x='0' y='0' width='1' height='1' fill='%23d4c5a9' fill-opacity='0.025'/%3E%3Crect x='3' y='3' width='1' height='1' fill='%23d4c5a9' fill-opacity='0.025'/%3E%3C/svg%3E")`;

const F = {
  sans: "'M PLUS 1p', 'Noto Sans JP', system-ui, sans-serif",
  mono: "'IBM Plex Mono', monospace",
};

const WORKSPACES = [
  { name: "studio", windows: 3, active: false },
  { name: "research", windows: 2, active: true },
  { name: "writing", windows: 1, active: false },
  { name: "music", windows: 0, active: false },
  { name: "system", windows: 1, active: false },
];

const APPS = [
  { name: "Clip Studio Paint", type: "application" },
  { name: "Aseprite", type: "application" },
  { name: "Obsidian", type: "application" },
  { name: "Garden", type: "application" },
  { name: "Ghostty", type: "terminal" },
  { name: "Firefox", type: "browser" },
  { name: "Strudel REPL", type: "application" },
  { name: "Zathura", type: "viewer" },
  { name: "Ardour", type: "application" },
  { name: "Godot", type: "application" },
  { name: "Typst", type: "editor" },
  { name: "Helix", type: "editor" },
];

const NOTIFICATIONS = [
  { app: "slurm", body: "Job 48291 completed on frontier — 4 nodes, 12m wall time", time: "2m ago" },
  { app: "garden", body: "New block added to restaurant channel", time: "8m ago" },
];

// ─── Time Hook ───
function useTime() {
  const [time, setTime] = useState(new Date());
  useEffect(() => {
    const id = setInterval(() => setTime(new Date()), 1000);
    return () => clearInterval(id);
  }, []);
  return time;
}

function formatTime(t) {
  return t.getHours().toString().padStart(2, "0") + ":" + t.getMinutes().toString().padStart(2, "0");
}
function formatSeconds(t) {
  return t.getSeconds().toString().padStart(2, "0");
}
function formatDate(t) {
  return t.toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" }).toLowerCase();
}
function formatDateLong(t) {
  return t.toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric", year: "numeric" }).toLowerCase();
}

// ═══════════════════════════════════════════════════
// BAR — Three density modes
// ═══════════════════════════════════════════════════

function BarFull({ onLauncher, time }) {
  return (
    <div style={{
      height: 34, background: P.barBg, borderBottom: `1px solid ${P.borderSubtle}`,
      display: "flex", alignItems: "center", padding: "0 16px",
      fontFamily: F.sans, userSelect: "none", position: "relative", zIndex: 100,
    }}>
      {WORKSPACES.map((ws, i) => (
        <div key={ws.name} style={{
          padding: "4px 12px", fontSize: 12, height: 34,
          fontWeight: ws.active ? 700 : 400,
          color: ws.active ? P.textPrimary : ws.windows > 0 ? P.textSecondary : P.textMuted,
          letterSpacing: "0.02em", cursor: "pointer",
          borderRight: `1px solid ${P.borderSubtle}`,
          display: "flex", alignItems: "center", gap: 6,
          background: ws.active ? P.surfaceHighlight : "transparent",
          transition: "all 0.15s ease",
        }}>
          {ws.name}
          {ws.windows > 0 && (
            <span style={{ fontSize: 10, color: P.textMuted, fontFamily: F.mono }}>{ws.windows}</span>
          )}
        </div>
      ))}

      <div style={{
        position: "absolute", left: "50%", transform: "translateX(-50%)",
        display: "flex", alignItems: "baseline", gap: 8,
      }}>
        <span style={{ fontSize: 14, fontWeight: 500, color: P.textPrimary, fontFamily: F.mono, letterSpacing: "0.05em" }}>
          {formatTime(time)}
        </span>
        <span style={{ fontSize: 10, color: P.textMuted, letterSpacing: "0.06em" }}>
          {formatDate(time)}
        </span>
      </div>

      <div style={{
        marginLeft: "auto", display: "flex", alignItems: "center", gap: 16,
        fontFamily: F.mono, fontSize: 10, color: P.textMuted, letterSpacing: "0.03em",
      }}>
        <span>cpu <span style={{ color: P.textSecondary }}>8%</span></span>
        <span>mem <span style={{ color: P.textSecondary }}>4.1g</span></span>
        <span>vol <span style={{ color: P.textSecondary }}>72</span></span>
        <span>net <span style={{ color: P.textSecondary }}>↑2.1 ↓14.8</span></span>
        <div style={{ width: 1, height: 14, background: P.borderSubtle }} />
        <span onClick={onLauncher} style={{ color: P.textSecondary, cursor: "pointer", fontSize: 11, fontFamily: F.sans, fontWeight: 500 }}>/</span>
      </div>
    </div>
  );
}

function BarStandard({ onLauncher, time }) {
  return (
    <div style={{
      height: 30, background: P.barBg, borderBottom: `1px solid ${P.borderSubtle}`,
      display: "flex", alignItems: "center", padding: "0 16px",
      fontFamily: F.sans, userSelect: "none", position: "relative", zIndex: 100,
    }}>
      {WORKSPACES.map((ws) => (
        <div key={ws.name} style={{
          padding: "3px 10px", fontSize: 11,
          fontWeight: ws.active ? 700 : 400,
          color: ws.active ? P.textPrimary : ws.windows > 0 ? P.textSecondary : P.textFaint,
          letterSpacing: "0.02em", cursor: "pointer",
          display: "flex", alignItems: "center",
          transition: "all 0.15s ease",
        }}>
          {ws.name}
        </div>
      ))}

      <div style={{
        position: "absolute", left: "50%", transform: "translateX(-50%)",
        display: "flex", alignItems: "baseline", gap: 8,
      }}>
        <span style={{ fontSize: 13, fontWeight: 500, color: P.textPrimary, fontFamily: F.mono, letterSpacing: "0.05em" }}>
          {formatTime(time)}
        </span>
      </div>

      <div style={{
        marginLeft: "auto", display: "flex", alignItems: "center", gap: 12,
        fontFamily: F.mono, fontSize: 10, color: P.textMuted,
      }}>
        <span onClick={onLauncher} style={{ color: P.textSecondary, cursor: "pointer", fontSize: 11, fontFamily: F.sans, fontWeight: 500 }}>/</span>
      </div>
    </div>
  );
}

function BarMinimal({ time }) {
  const [hovered, setHovered] = useState(false);
  return (
    <div
      onMouseEnter={() => setHovered(true)}
      onMouseLeave={() => setHovered(false)}
      style={{
        height: hovered ? 30 : 2,
        background: hovered ? P.barBg : P.borderSubtle,
        borderBottom: hovered ? `1px solid ${P.borderSubtle}` : "none",
        display: "flex", alignItems: "center", justifyContent: "center",
        fontFamily: F.sans, userSelect: "none", position: "relative", zIndex: 100,
        transition: "height 0.2s ease, background 0.2s ease",
        overflow: "hidden",
      }}
    >
      {hovered && (
        <div style={{
          display: "flex", alignItems: "baseline", gap: 12,
          animation: "fadeInSoft 0.15s ease",
        }}>
          {WORKSPACES.filter(w => w.active || w.windows > 0).map((ws) => (
            <span key={ws.name} style={{
              fontSize: 10,
              fontWeight: ws.active ? 700 : 400,
              color: ws.active ? P.textPrimary : P.textMuted,
              cursor: "pointer",
            }}>
              {ws.name}
            </span>
          ))}
          <span style={{ color: P.borderSubtle }}>·</span>
          <span style={{ fontSize: 12, fontWeight: 500, color: P.textPrimary, fontFamily: F.mono, letterSpacing: "0.05em" }}>
            {formatTime(time)}
          </span>
        </div>
      )}
    </div>
  );
}

// ═══════════════════════════════════════════════════
// LAUNCHER
// ═══════════════════════════════════════════════════

function Launcher({ open, onClose }) {
  const [query, setQuery] = useState("");
  const [sel, setSel] = useState(0);
  const inputRef = useRef(null);

  const filtered = APPS.filter(a => a.name.toLowerCase().includes(query.toLowerCase()));

  useEffect(() => { setSel(0); }, [query]);
  useEffect(() => {
    if (!open) { setQuery(""); setSel(0); }
    else { setTimeout(() => inputRef.current?.focus(), 50); }
  }, [open]);

  const handleKey = useCallback((e) => {
    if (!open) return;
    if (e.key === "Escape") onClose();
    else if (e.key === "ArrowDown") { e.preventDefault(); setSel(i => Math.min(i + 1, filtered.length - 1)); }
    else if (e.key === "ArrowUp") { e.preventDefault(); setSel(i => Math.max(i - 1, 0)); }
  }, [open, filtered.length, onClose]);

  useEffect(() => {
    window.addEventListener("keydown", handleKey);
    return () => window.removeEventListener("keydown", handleKey);
  }, [handleKey]);

  if (!open) return null;

  return (
    <div onClick={onClose} style={{ position: "fixed", inset: 0, zIndex: 200, display: "flex", alignItems: "flex-start", justifyContent: "center", paddingTop: 120 }}>
      <div style={{ position: "absolute", inset: 0, backgroundImage: DITHER_DENSE, backgroundRepeat: "repeat", imageRendering: "pixelated", animation: "fadeInSoft 0.12s ease" }} />
      <div onClick={e => e.stopPropagation()} style={{
        width: 460, background: P.surface, border: `1px solid ${P.border}`,
        position: "relative", zIndex: 1, fontFamily: F.sans,
        animation: "slideUp 0.15s ease",
      }}>
        <div style={{ padding: "0 16px", height: 44, display: "flex", alignItems: "center", borderBottom: `1px solid ${P.border}` }}>
          <span style={{ color: P.textFaint, marginRight: 8, fontSize: 13, fontFamily: F.mono }}>/</span>
          <input ref={inputRef} autoFocus value={query} onChange={e => setQuery(e.target.value)}
            placeholder="search applications..."
            style={{ width: "100%", background: "transparent", border: "none", outline: "none", color: P.textPrimary, fontSize: 14, fontFamily: F.sans, letterSpacing: "0.01em" }}
          />
        </div>
        <div style={{ maxHeight: 340, overflowY: "auto" }}>
          {filtered.map((app, i) => (
            <div key={app.name} onMouseEnter={() => setSel(i)} style={{
              padding: "10px 16px", display: "flex", justifyContent: "space-between", alignItems: "center",
              background: i === sel ? P.surfaceHighlight : "transparent",
              borderBottom: i < filtered.length - 1 ? `1px solid ${P.borderFaint}` : "none",
              cursor: "pointer", transition: "background 0.08s ease",
            }}>
              <span style={{ fontSize: 13, fontWeight: i === sel ? 600 : 400, color: i === sel ? P.textPrimary : P.textSecondary, letterSpacing: "0.01em" }}>{app.name}</span>
              <span style={{ fontSize: 10, color: P.textMuted, fontFamily: F.mono, letterSpacing: "0.04em" }}>{app.type}</span>
            </div>
          ))}
          {filtered.length === 0 && (
            <div style={{ padding: "24px 16px", fontSize: 12, color: P.textMuted, textAlign: "center" }}>no results</div>
          )}
        </div>
        <div style={{
          padding: "6px 16px", borderTop: `1px solid ${P.borderFaint}`,
          display: "flex", gap: 16, fontFamily: F.mono, fontSize: 9, color: P.textFaint, letterSpacing: "0.04em",
        }}>
          <span><span style={{ color: P.textMuted }}>↑↓</span> navigate</span>
          <span><span style={{ color: P.textMuted }}>↵</span> launch</span>
          <span><span style={{ color: P.textMuted }}>esc</span> close</span>
        </div>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════
// NOTIFICATIONS
// ═══════════════════════════════════════════════════

function NotificationStack({ notifications, visible }) {
  if (!visible || !notifications.length) return null;
  return (
    <div style={{ position: "fixed", top: 50, right: 16, zIndex: 150, display: "flex", flexDirection: "column", gap: 6 }}>
      {notifications.map((n, i) => (
        <div key={i} style={{
          width: 272, background: P.surfaceRaised, border: `1px solid ${P.border}`,
          padding: "10px 14px", fontFamily: F.sans,
          animation: `slideIn 0.2s ease-out ${i * 0.06}s both`,
        }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: 5 }}>
            <span style={{ fontSize: 11, fontWeight: 700, color: P.textPrimary, letterSpacing: "0.02em" }}>{n.app}</span>
            <span style={{ fontSize: 9, color: P.textFaint, fontFamily: F.mono, letterSpacing: "0.04em" }}>{n.time}</span>
          </div>
          <div style={{ fontSize: 12, color: P.textSecondary, lineHeight: 1.5 }}>{n.body}</div>
          {/* Thin dismiss progress line */}
          <div style={{
            marginTop: 8, height: 1, background: P.borderSubtle, position: "relative", overflow: "hidden",
          }}>
            <div style={{
              position: "absolute", top: 0, left: 0, height: 1,
              background: P.textMuted, width: "100%",
              animation: `shrink 10s linear ${i * 0.06}s forwards`,
            }} />
          </div>
        </div>
      ))}
    </div>
  );
}

// ═══════════════════════════════════════════════════
// LOCK SCREEN
// ═══════════════════════════════════════════════════

function LockScreen({ onUnlock, time }) {
  const [password, setPassword] = useState("");
  const [shake, setShake] = useState(false);
  const inputRef = useRef(null);

  useEffect(() => {
    setTimeout(() => inputRef.current?.focus(), 300);
  }, []);

  const handleSubmit = () => {
    if (password.length > 0) {
      onUnlock();
    } else {
      setShake(true);
      setTimeout(() => setShake(false), 400);
    }
  };

  return (
    <div style={{
      position: "fixed", inset: 0, zIndex: 1000,
      background: P.lockBg, display: "flex", flexDirection: "column",
      alignItems: "center", justifyContent: "center",
      fontFamily: F.sans, animation: "fadeInSoft 0.4s ease",
    }}>
      {/* Subtle dithered texture over the entire lock screen */}
      <div style={{
        position: "absolute", inset: 0,
        backgroundImage: DITHER_LOCK, backgroundRepeat: "repeat",
        imageRendering: "pixelated", pointerEvents: "none",
      }} />

      {/* Thin border frame inset from edges */}
      <div style={{
        position: "absolute",
        top: 24, left: 24, right: 24, bottom: 24,
        border: `1px solid ${P.borderFaint}`,
        pointerEvents: "none",
      }} />

      {/* Time — large, centered, typographic */}
      <div style={{ position: "relative", zIndex: 1, textAlign: "center", marginBottom: 48 }}>
        <div style={{
          fontSize: 96, fontWeight: 300, color: P.textPrimary,
          fontFamily: F.mono, letterSpacing: "0.08em", lineHeight: 1,
          opacity: 0.9,
        }}>
          {formatTime(time)}
        </div>
        <div style={{
          fontSize: 40, fontWeight: 300, color: P.textMuted,
          fontFamily: F.mono, letterSpacing: "0.08em", lineHeight: 1,
          marginTop: 4, opacity: 0.4,
        }}>
          {formatSeconds(time)}
        </div>
        <div style={{
          fontSize: 13, color: P.textMuted, letterSpacing: "0.12em",
          marginTop: 20, textTransform: "lowercase",
        }}>
          {formatDateLong(time)}
        </div>
      </div>

      {/* Login input */}
      <div style={{
        position: "relative", zIndex: 1, width: 320, textAlign: "center",
        animation: shake ? "shakeX 0.3s ease" : "none",
      }}>
        <div style={{
          fontSize: 11, color: P.textFaint, letterSpacing: "0.06em",
          marginBottom: 12, fontFamily: F.mono,
        }}>
          ada@nix
        </div>
        <div style={{
          border: `1px solid ${P.border}`, background: P.surfaceDeep,
          display: "flex", alignItems: "center", height: 40,
          padding: "0 14px",
        }}>
          <input
            ref={inputRef}
            type="password"
            value={password}
            onChange={e => setPassword(e.target.value)}
            onKeyDown={e => e.key === "Enter" && handleSubmit()}
            placeholder="password"
            style={{
              width: "100%", background: "transparent", border: "none",
              outline: "none", color: P.textPrimary, fontSize: 14,
              fontFamily: F.mono, letterSpacing: "0.1em",
            }}
          />
        </div>
        <div style={{
          marginTop: 10, fontSize: 9, color: P.textFaint,
          fontFamily: F.mono, letterSpacing: "0.05em",
        }}>
          press enter to unlock
        </div>
      </div>

      {/* Bottom info line */}
      <div style={{
        position: "absolute", bottom: 36, left: 0, right: 0,
        display: "flex", justifyContent: "center", gap: 24,
        fontFamily: F.mono, fontSize: 9, color: P.textFaint,
        letterSpacing: "0.05em", zIndex: 1,
      }}>
        <span>nixos 24.11</span>
        <span>·</span>
        <span>hyprland</span>
        <span>·</span>
        <span>garden shell</span>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════
// DESKTOP CLOCK OVERLAY
// ═══════════════════════════════════════════════════

function DesktopClock({ time, visible }) {
  if (!visible) return null;
  return (
    <div style={{
      position: "absolute", bottom: 60, left: 40,
      fontFamily: F.mono, zIndex: 50, pointerEvents: "none",
      animation: "fadeInSoft 0.5s ease",
    }}>
      <div style={{
        fontSize: 80, fontWeight: 300, color: P.textPrimary,
        letterSpacing: "0.06em", lineHeight: 1, opacity: 0.12,
      }}>
        {formatTime(time)}
      </div>
      <div style={{
        fontSize: 14, color: P.textPrimary, opacity: 0.08,
        letterSpacing: "0.15em", marginTop: 8, textTransform: "lowercase",
      }}>
        {formatDateLong(time)}
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════
// DESKTOP CONTENT (simulated tiled windows)
// ═══════════════════════════════════════════════════

function DesktopContent({ showClock, time }) {
  return (
    <div style={{ flex: 1, background: P.surface, display: "grid", gridTemplateColumns: "1fr 1fr", gap: 0, overflow: "hidden", position: "relative" }}>
      {/* Terminal */}
      <div style={{ borderRight: `1px solid ${P.border}`, borderBottom: `1px solid ${P.border}`, padding: 16, fontFamily: F.mono, fontSize: 12, color: P.textSecondary, lineHeight: 1.8, overflow: "hidden" }}>
        <div style={{ color: P.textMuted, marginBottom: 8, fontSize: 10, letterSpacing: "0.06em" }}>ghostty — research</div>
        <div>
          <span style={{ color: P.accent }}>ada</span>
          <span style={{ color: P.textMuted }}>@</span>
          <span style={{ color: P.textSecondary }}>nix</span>
          <span style={{ color: P.textMuted }}> ~/autoresearch </span>
          <span style={{ color: P.textPrimary }}>$</span>
        </div>
        <div style={{ color: P.textMuted }}>ssh login01.frontier.olcf.ornl.gov</div>
        <div style={{ marginTop: 8 }}>
          <span style={{ color: P.urgent }}>ada</span>
          <span style={{ color: P.textMuted }}>@</span>
          <span style={{ color: P.urgent }}>frontier-login01</span>
          <span style={{ color: P.textMuted }}> ~ </span>
          <span style={{ color: P.textPrimary }}>$</span>
        </div>
        <div style={{ color: P.textMuted }}>squeue -u ada --format="%.8i %.12j %.8T %.10M %.4D"</div>
        <div style={{ marginTop: 4, color: P.textSecondary, opacity: 0.7, fontSize: 11 }}>
          JOBID &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;NAME &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;STATE &nbsp;&nbsp;&nbsp;TIME &nbsp;NODES<br />
          48291 &nbsp;&nbsp;&nbsp;&nbsp;train_v3 &nbsp;&nbsp;&nbsp;RUNNING &nbsp;0:08:42 &nbsp;4<br />
          48292 &nbsp;&nbsp;&nbsp;&nbsp;eval_suite &nbsp;PENDING &nbsp;0:00:00 &nbsp;2<br />
        </div>
        <div style={{ marginTop: 8 }}>
          <span style={{ color: P.urgent }}>ada</span>
          <span style={{ color: P.textMuted }}>@</span>
          <span style={{ color: P.urgent }}>frontier-login01</span>
          <span style={{ color: P.textMuted }}> ~ </span>
          <span style={{ color: P.textPrimary }}>$</span>
          <span style={{ display: "inline-block", width: 7, height: 13, background: P.textPrimary, marginLeft: 4, opacity: 0.7, animation: "blink 1s step-end infinite" }} />
        </div>
      </div>

      {/* Obsidian */}
      <div style={{ borderBottom: `1px solid ${P.border}`, padding: 16, fontFamily: F.sans, fontSize: 13, color: P.textSecondary, lineHeight: 1.8, overflow: "hidden" }}>
        <div style={{ color: P.textMuted, marginBottom: 8, fontSize: 10, letterSpacing: "0.06em", fontFamily: F.mono }}>obsidian — autoresearch-hpc.md</div>
        <div style={{ color: P.textPrimary, fontSize: 16, fontWeight: 700, marginBottom: 12 }}>Autoresearch: Agent-Driven HPC</div>
        <div style={{ color: P.textSecondary, marginBottom: 12, fontSize: 12 }}>
          The system coordinates autonomous ML experiments on
          Genesis-class supercomputers via a hexagonal architecture
          with trait-based storage ports.
        </div>
        <div style={{ color: P.textMuted, fontSize: 11, fontFamily: F.mono, marginBottom: 6 }}>## remaining gaps</div>
        <div style={{ color: P.textSecondary, fontSize: 12, paddingLeft: 12, borderLeft: `2px solid ${P.borderSubtle}`, lineHeight: 1.7 }}>
          train.py template<br />
          SLURM script generation<br />
          metrics emission protocol<br />
          security model
        </div>
      </div>

      {/* Code */}
      <div style={{ borderRight: `1px solid ${P.border}`, padding: 16, fontFamily: F.mono, fontSize: 11, color: P.textMuted, lineHeight: 1.8, overflow: "hidden" }}>
        <div style={{ marginBottom: 8, fontSize: 10, letterSpacing: "0.06em" }}>helix — src/agent/scheduler.rs</div>
        <div style={{ color: P.textFaint }}>
          <span style={{ color: P.textMuted }}>use</span> <span style={{ color: P.textSecondary }}>crate::storage::StoragePort</span>;<br />
          <span style={{ color: P.textMuted }}>use</span> <span style={{ color: P.textSecondary }}>crate::slurm::SlurmBridge</span>;<br />
          <br />
          <span style={{ color: P.textFaint }}>/// Schedules experiment runs on the cluster</span><br />
          <span style={{ color: P.textMuted }}>pub struct</span> <span style={{ color: P.accent }}>Scheduler</span> {"{"}<br />
          &nbsp;&nbsp;<span style={{ color: P.textSecondary }}>storage</span>: Box{"<"}dyn StoragePort{">"}, <br />
          &nbsp;&nbsp;<span style={{ color: P.textSecondary }}>bridge</span>: SlurmBridge,<br />
          &nbsp;&nbsp;<span style={{ color: P.textSecondary }}>max_concurrent</span>: <span style={{ color: P.textMuted }}>usize</span>,<br />
          {"}"}<br />
          <br />
          <span style={{ color: P.textMuted }}>impl</span> <span style={{ color: P.accent }}>Scheduler</span> {"{"}<br />
          &nbsp;&nbsp;<span style={{ color: P.textMuted }}>pub async fn</span> <span style={{ color: P.textSecondary }}>submit</span>(<br />
          &nbsp;&nbsp;&nbsp;&nbsp;&{"&"}self,<br />
          &nbsp;&nbsp;&nbsp;&nbsp;config: &{"&"}<span style={{ color: P.textSecondary }}>ExperimentConfig</span>,<br />
          &nbsp;&nbsp;) -{">"} <span style={{ color: P.textMuted }}>Result</span>{"<"}<span style={{ color: P.textSecondary }}>JobId</span>{">"} {"{"}<br />
        </div>
      </div>

      {/* Garden mini */}
      <div style={{ padding: 16, fontFamily: F.sans, overflow: "hidden" }}>
        <div style={{ color: P.textMuted, marginBottom: 8, fontSize: 10, letterSpacing: "0.06em", fontFamily: F.mono }}>garden — channels</div>
        <div style={{ color: P.textPrimary, fontSize: 14, fontWeight: 700, marginBottom: 4 }}>Garden</div>
        <div style={{ fontSize: 10, color: P.textMuted, marginBottom: 12, letterSpacing: "0.03em" }}>7 channels · 44 blocks</div>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 6 }}>
          {[
            { name: "Hiromix", n: 6 }, { name: "interiors", n: 5 },
            { name: "doors", n: 6 }, { name: "JDM", n: 8 },
            { name: "restaurant", n: 13 }, { name: "tattoo.manga", n: 5 },
          ].map(ch => (
            <div key={ch.name} style={{ border: `1px solid ${P.borderSubtle}`, padding: "6px 8px" }}>
              <div style={{ fontSize: 11, fontWeight: 600, color: P.textPrimary }}>{ch.name}</div>
              <div style={{ fontSize: 9, color: P.textMuted, fontFamily: F.mono, marginTop: 2 }}>{ch.n} blocks</div>
            </div>
          ))}
        </div>
      </div>

      <DesktopClock time={time} visible={showClock} />
    </div>
  );
}

// ═══════════════════════════════════════════════════
// MAIN SHELL
// ═══════════════════════════════════════════════════

export default function GardenShellExpanded() {
  const time = useTime();
  const [barMode, setBarMode] = useState("full"); // full | standard | minimal
  const [launcherOpen, setLauncherOpen] = useState(false);
  const [showNotifs, setShowNotifs] = useState(true);
  const [locked, setLocked] = useState(false);
  const [showClock, setShowClock] = useState(false);

  useEffect(() => {
    const handler = (e) => {
      if (e.key === "/" && !launcherOpen && !locked) {
        e.preventDefault();
        setLauncherOpen(true);
      }
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [launcherOpen, locked]);

  useEffect(() => {
    const id = setTimeout(() => setShowNotifs(false), 15000);
    return () => clearTimeout(id);
  }, []);

  return (
    <div style={{ width: "100%", height: "100vh", display: "flex", flexDirection: "column", background: P.surface, overflow: "hidden", position: "relative" }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=M+PLUS+1p:wght@300;400;500;700&family=IBM+Plex+Mono:wght@300;400;500&display=swap');
        * { box-sizing: border-box; margin: 0; padding: 0; }
        ::placeholder { color: ${P.textFaint}; opacity: 1; }
        ::-webkit-scrollbar { width: 3px; }
        ::-webkit-scrollbar-track { background: transparent; }
        ::-webkit-scrollbar-thumb { background: ${P.border}; }
        @keyframes blink { 50% { opacity: 0; } }
        @keyframes slideIn { from { transform: translateX(16px); opacity: 0; } to { transform: translateX(0); opacity: 1; } }
        @keyframes slideUp { from { transform: translateY(8px); opacity: 0; } to { transform: translateY(0); opacity: 1; } }
        @keyframes fadeInSoft { from { opacity: 0; } to { opacity: 1; } }
        @keyframes shakeX { 0%, 100% { transform: translateX(0); } 25% { transform: translateX(-6px); } 75% { transform: translateX(6px); } }
        @keyframes shrink { from { width: 100%; } to { width: 0%; } }
      `}</style>

      {locked && <LockScreen time={time} onUnlock={() => setLocked(false)} />}

      {!locked && (
        <>
          {barMode === "full" && <BarFull time={time} onLauncher={() => setLauncherOpen(true)} />}
          {barMode === "standard" && <BarStandard time={time} onLauncher={() => setLauncherOpen(true)} />}
          {barMode === "minimal" && <BarMinimal time={time} />}

          <DesktopContent showClock={showClock} time={time} />

          <NotificationStack notifications={NOTIFICATIONS} visible={showNotifs} />

          <Launcher open={launcherOpen} onClose={() => setLauncherOpen(false)} />

          {/* Control strip — for demo purposes */}
          <div style={{
            position: "fixed", bottom: 0, left: 0, right: 0, height: 28,
            background: P.barBg, borderTop: `1px solid ${P.borderSubtle}`,
            display: "flex", alignItems: "center", justifyContent: "center", gap: 8,
            fontFamily: F.mono, fontSize: 9, color: P.textMuted, letterSpacing: "0.04em",
            zIndex: 100, userSelect: "none",
          }}>
            <span style={{ color: P.textFaint, marginRight: 4 }}>bar:</span>
            {["full", "standard", "minimal"].map(m => (
              <span key={m} onClick={() => setBarMode(m)} style={{
                padding: "2px 8px", cursor: "pointer",
                color: barMode === m ? P.textPrimary : P.textMuted,
                background: barMode === m ? P.surfaceHighlight : "transparent",
                border: `1px solid ${barMode === m ? P.border : "transparent"}`,
                transition: "all 0.12s ease",
              }}>{m}</span>
            ))}
            <span style={{ color: P.borderSubtle, margin: "0 4px" }}>·</span>
            <span onClick={() => setShowNotifs(true)} style={{ padding: "2px 8px", cursor: "pointer", color: P.textMuted, border: `1px solid transparent` }}>
              notifs
            </span>
            <span onClick={() => setLocked(true)} style={{ padding: "2px 8px", cursor: "pointer", color: P.textMuted, border: `1px solid transparent` }}>
              lock
            </span>
            <span onClick={() => setShowClock(c => !c)} style={{
              padding: "2px 8px", cursor: "pointer",
              color: showClock ? P.textPrimary : P.textMuted,
              background: showClock ? P.surfaceHighlight : "transparent",
              border: `1px solid ${showClock ? P.border : "transparent"}`,
            }}>
              clock
            </span>
            <span style={{ color: P.borderSubtle, margin: "0 4px" }}>·</span>
            <span style={{ color: P.textFaint }}>press <span style={{ color: P.textMuted }}>/</span> to search</span>
          </div>
        </>
      )}
    </div>
  );
}

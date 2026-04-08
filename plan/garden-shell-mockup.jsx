import { useState, useEffect, useCallback } from "react";

// Garden Shell — Desktop shell mockup
// Design language: Are.na structure × PC-98 materiality × Farrow & Ball warmth

const PALETTE = {
  surface: "#2c3444",        // Dark blue-slate (Garden background)
  surfaceRaised: "#343d4f",  // Slightly lighter for cards/panels
  surfaceHighlight: "#3d4759", // Selected/hover state
  border: "#4a5568",         // Thin grid lines
  borderSubtle: "#3a4456",   // Quieter borders
  textPrimary: "#d4c5a9",    // Warm cream
  textSecondary: "#8b9bb0",  // Muted blue-gray
  textMuted: "#6b7a8d",      // Even more muted for metadata
  accent: "#c9b88c",         // Warm gold, used very sparingly
  urgent: "#c4796b",         // Earthy red for alerts only
  barBg: "#252d3b",          // Slightly darker for bar
};

// PC-98 inspired dithering pattern as inline SVG data URI
const DITHER_PATTERN = `url("data:image/svg+xml,%3Csvg width='4' height='4' xmlns='http://www.w3.org/2000/svg'%3E%3Crect x='0' y='0' width='1' height='1' fill='%23252d3b' fill-opacity='0.7'/%3E%3Crect x='2' y='2' width='1' height='1' fill='%23252d3b' fill-opacity='0.7'/%3E%3C/svg%3E")`;

const DITHER_PATTERN_DENSE = `url("data:image/svg+xml,%3Csvg width='2' height='2' xmlns='http://www.w3.org/2000/svg'%3E%3Crect x='0' y='0' width='1' height='1' fill='%23252d3b' fill-opacity='0.85'/%3E%3Crect x='1' y='1' width='1' height='1' fill='%23252d3b' fill-opacity='0.85'/%3E%3C/svg%3E")`;

const FONT = {
  family: "'M PLUS 1p', 'Noto Sans JP', 'Noto Sans', system-ui, sans-serif",
  mono: "'IBM Plex Mono', 'JetBrains Mono', monospace",
};

// ─── Workspaces ───
const WORKSPACES = [
  { name: "studio", windows: 3, active: false },
  { name: "research", windows: 2, active: true },
  { name: "writing", windows: 1, active: false },
  { name: "music", windows: 0, active: false },
  { name: "system", windows: 1, active: false },
];

// ─── Launcher apps ───
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

// ─── Notifications ───
const NOTIFICATIONS = [
  {
    app: "slurm",
    body: "Job 48291 completed on frontier — 4 nodes, 12m wall time",
    time: "2m ago",
  },
  {
    app: "garden",
    body: "New block added to restaurant channel",
    time: "8m ago",
  },
];

// ─── Bar Component ───
function Bar({ onLauncherToggle, launcherOpen }) {
  const [time, setTime] = useState(new Date());

  useEffect(() => {
    const id = setInterval(() => setTime(new Date()), 1000);
    return () => clearInterval(id);
  }, []);

  const hours = time.getHours().toString().padStart(2, "0");
  const minutes = time.getMinutes().toString().padStart(2, "0");
  const dateStr = time.toLocaleDateString("en-US", {
    weekday: "short",
    month: "short",
    day: "numeric",
  }).toLowerCase();

  return (
    <div style={{
      height: 34,
      background: PALETTE.barBg,
      borderBottom: `1px solid ${PALETTE.borderSubtle}`,
      display: "flex",
      alignItems: "center",
      padding: "0 16px",
      fontFamily: FONT.family,
      position: "relative",
      zIndex: 100,
      userSelect: "none",
    }}>
      {/* Left: Workspaces */}
      <div style={{ display: "flex", gap: 0, alignItems: "center" }}>
        {WORKSPACES.map((ws) => (
          <div
            key={ws.name}
            style={{
              padding: "4px 12px",
              fontSize: 12,
              fontWeight: ws.active ? 700 : 400,
              color: ws.active
                ? PALETTE.textPrimary
                : ws.windows > 0
                ? PALETTE.textSecondary
                : PALETTE.textMuted,
              letterSpacing: "0.02em",
              cursor: "pointer",
              borderRight: `1px solid ${PALETTE.borderSubtle}`,
              height: 34,
              display: "flex",
              alignItems: "center",
              background: ws.active ? PALETTE.surfaceHighlight : "transparent",
              transition: "color 0.15s ease",
            }}
          >
            {ws.name}
            {ws.windows > 0 && (
              <span style={{
                fontSize: 10,
                color: PALETTE.textMuted,
                marginLeft: 6,
                fontFamily: FONT.mono,
              }}>
                {ws.windows}
              </span>
            )}
          </div>
        ))}
      </div>

      {/* Center: Clock */}
      <div style={{
        position: "absolute",
        left: "50%",
        transform: "translateX(-50%)",
        display: "flex",
        alignItems: "baseline",
        gap: 8,
      }}>
        <span style={{
          fontSize: 14,
          fontWeight: 500,
          color: PALETTE.textPrimary,
          fontFamily: FONT.mono,
          letterSpacing: "0.05em",
        }}>
          {hours}:{minutes}
        </span>
        <span style={{
          fontSize: 10,
          color: PALETTE.textMuted,
          letterSpacing: "0.06em",
          textTransform: "lowercase",
        }}>
          {dateStr}
        </span>
      </div>

      {/* Right: System metrics */}
      <div style={{
        marginLeft: "auto",
        display: "flex",
        alignItems: "center",
        gap: 16,
        fontFamily: FONT.mono,
        fontSize: 10,
        color: PALETTE.textMuted,
        letterSpacing: "0.03em",
      }}>
        <span>cpu <span style={{ color: PALETTE.textSecondary }}>8%</span></span>
        <span>mem <span style={{ color: PALETTE.textSecondary }}>4.1g</span></span>
        <span>vol <span style={{ color: PALETTE.textSecondary }}>72</span></span>
        <div style={{
          width: 1,
          height: 14,
          background: PALETTE.borderSubtle,
        }} />
        <span
          onClick={onLauncherToggle}
          style={{
            color: launcherOpen ? PALETTE.textPrimary : PALETTE.textSecondary,
            cursor: "pointer",
            fontSize: 11,
            fontFamily: FONT.family,
            fontWeight: 500,
            letterSpacing: "0.02em",
          }}
        >
          /
        </span>
      </div>
    </div>
  );
}

// ─── Launcher Component ───
function Launcher({ open, onClose }) {
  const [query, setQuery] = useState("");
  const [selectedIndex, setSelectedIndex] = useState(0);

  const filtered = APPS.filter((app) =>
    app.name.toLowerCase().includes(query.toLowerCase())
  );

  useEffect(() => {
    setSelectedIndex(0);
  }, [query]);

  const handleKeyDown = useCallback(
    (e) => {
      if (!open) return;
      if (e.key === "Escape") {
        onClose();
      } else if (e.key === "ArrowDown") {
        e.preventDefault();
        setSelectedIndex((i) => Math.min(i + 1, filtered.length - 1));
      } else if (e.key === "ArrowUp") {
        e.preventDefault();
        setSelectedIndex((i) => Math.max(i - 1, 0));
      }
    },
    [open, filtered.length, onClose]
  );

  useEffect(() => {
    window.addEventListener("keydown", handleKeyDown);
    return () => window.removeEventListener("keydown", handleKeyDown);
  }, [handleKeyDown]);

  useEffect(() => {
    if (!open) {
      setQuery("");
      setSelectedIndex(0);
    }
  }, [open]);

  if (!open) return null;

  return (
    <div
      onClick={onClose}
      style={{
        position: "fixed",
        inset: 0,
        zIndex: 200,
        display: "flex",
        alignItems: "flex-start",
        justifyContent: "center",
        paddingTop: 140,
      }}
    >
      {/* Dithered backdrop — PC-98 style */}
      <div style={{
        position: "absolute",
        inset: 0,
        backgroundImage: DITHER_PATTERN_DENSE,
        backgroundRepeat: "repeat",
        imageRendering: "pixelated",
      }} />

      {/* Search panel */}
      <div
        onClick={(e) => e.stopPropagation()}
        style={{
          width: 480,
          background: PALETTE.surface,
          border: `1px solid ${PALETTE.border}`,
          position: "relative",
          zIndex: 1,
          fontFamily: FONT.family,
        }}
      >
        {/* Search input */}
        <div style={{
          padding: "0 16px",
          height: 44,
          display: "flex",
          alignItems: "center",
          borderBottom: `1px solid ${PALETTE.border}`,
        }}>
          <input
            autoFocus
            value={query}
            onChange={(e) => setQuery(e.target.value)}
            placeholder="search applications..."
            style={{
              width: "100%",
              background: "transparent",
              border: "none",
              outline: "none",
              color: PALETTE.textPrimary,
              fontSize: 14,
              fontFamily: FONT.family,
              letterSpacing: "0.01em",
            }}
          />
        </div>

        {/* Results */}
        <div style={{ maxHeight: 320, overflowY: "auto" }}>
          {filtered.map((app, i) => (
            <div
              key={app.name}
              style={{
                padding: "10px 16px",
                display: "flex",
                justifyContent: "space-between",
                alignItems: "center",
                background:
                  i === selectedIndex
                    ? PALETTE.surfaceHighlight
                    : "transparent",
                borderBottom:
                  i < filtered.length - 1
                    ? `1px solid ${PALETTE.borderSubtle}`
                    : "none",
                cursor: "pointer",
                transition: "background 0.1s ease",
              }}
              onMouseEnter={() => setSelectedIndex(i)}
            >
              <span style={{
                fontSize: 13,
                fontWeight: i === selectedIndex ? 600 : 400,
                color:
                  i === selectedIndex
                    ? PALETTE.textPrimary
                    : PALETTE.textSecondary,
                letterSpacing: "0.01em",
              }}>
                {app.name}
              </span>
              <span style={{
                fontSize: 10,
                color: PALETTE.textMuted,
                letterSpacing: "0.04em",
                fontFamily: FONT.mono,
              }}>
                {app.type}
              </span>
            </div>
          ))}
          {filtered.length === 0 && (
            <div style={{
              padding: "20px 16px",
              fontSize: 12,
              color: PALETTE.textMuted,
              textAlign: "center",
            }}>
              no results
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// ─── Notification Component ───
function Notification({ notif, style }) {
  return (
    <div style={{
      width: 280,
      background: PALETTE.surfaceRaised,
      border: `1px solid ${PALETTE.border}`,
      padding: "10px 14px",
      fontFamily: FONT.family,
      ...style,
    }}>
      <div style={{
        display: "flex",
        justifyContent: "space-between",
        alignItems: "baseline",
        marginBottom: 6,
      }}>
        <span style={{
          fontSize: 11,
          fontWeight: 700,
          color: PALETTE.textPrimary,
          letterSpacing: "0.02em",
        }}>
          {notif.app}
        </span>
        <span style={{
          fontSize: 9,
          color: PALETTE.textMuted,
          fontFamily: FONT.mono,
          letterSpacing: "0.04em",
        }}>
          {notif.time}
        </span>
      </div>
      <div style={{
        fontSize: 12,
        color: PALETTE.textSecondary,
        lineHeight: 1.5,
        letterSpacing: "0.01em",
      }}>
        {notif.body}
      </div>
    </div>
  );
}

// ─── Desktop Content (simulated) ───
function DesktopContent() {
  return (
    <div style={{
      flex: 1,
      background: PALETTE.surface,
      display: "grid",
      gridTemplateColumns: "1fr 1fr",
      gap: 0,
      overflow: "hidden",
    }}>
      {/* Simulated terminal window */}
      <div style={{
        borderRight: `1px solid ${PALETTE.border}`,
        borderBottom: `1px solid ${PALETTE.border}`,
        padding: 16,
        fontFamily: FONT.mono,
        fontSize: 12,
        color: PALETTE.textSecondary,
        lineHeight: 1.8,
        overflow: "hidden",
      }}>
        <div style={{ color: PALETTE.textMuted, marginBottom: 8, fontSize: 10, letterSpacing: "0.06em" }}>
          ghostty — research
        </div>
        <div>
          <span style={{ color: PALETTE.accent }}>ada</span>
          <span style={{ color: PALETTE.textMuted }}>@</span>
          <span style={{ color: PALETTE.textSecondary }}>nix</span>
          <span style={{ color: PALETTE.textMuted }}> ~/autoresearch </span>
          <span style={{ color: PALETTE.textPrimary }}>$</span>
        </div>
        <div style={{ color: PALETTE.textMuted }}>cargo build --release 2&gt;&amp;1 | tail -5</div>
        <div style={{ marginTop: 4, color: PALETTE.textSecondary, opacity: 0.7 }}>
          Compiling autoresearch-agent v0.1.0<br />
          Compiling slurm-bridge v0.1.0<br />
          Compiling metrics-emit v0.1.0<br />
          &nbsp;&nbsp;&nbsp;Finished `release` profile [optimized]<br />
        </div>
        <div style={{ marginTop: 8 }}>
          <span style={{ color: PALETTE.accent }}>ada</span>
          <span style={{ color: PALETTE.textMuted }}>@</span>
          <span style={{ color: PALETTE.textSecondary }}>nix</span>
          <span style={{ color: PALETTE.textMuted }}> ~/autoresearch </span>
          <span style={{ color: PALETTE.textPrimary }}>$</span>
          <span style={{
            display: "inline-block",
            width: 7,
            height: 14,
            background: PALETTE.textPrimary,
            marginLeft: 4,
            opacity: 0.8,
            animation: "blink 1s step-end infinite",
          }} />
        </div>
      </div>

      {/* Simulated Obsidian / markdown editor */}
      <div style={{
        borderBottom: `1px solid ${PALETTE.border}`,
        padding: 16,
        fontFamily: FONT.family,
        fontSize: 13,
        color: PALETTE.textSecondary,
        lineHeight: 1.8,
        overflow: "hidden",
      }}>
        <div style={{ color: PALETTE.textMuted, marginBottom: 8, fontSize: 10, letterSpacing: "0.06em", fontFamily: FONT.mono }}>
          obsidian — autoresearch-hpc.md
        </div>
        <div style={{ color: PALETTE.textPrimary, fontSize: 16, fontWeight: 700, marginBottom: 12 }}>
          Autoresearch: Agent-Driven HPC Experimentation
        </div>
        <div style={{ color: PALETTE.textSecondary, marginBottom: 8 }}>
          The system coordinates autonomous ML experiments on 
          Genesis-class supercomputers via a hexagonal architecture 
          with trait-based storage ports.
        </div>
        <div style={{ color: PALETTE.textMuted, fontSize: 11, fontFamily: FONT.mono, marginBottom: 8 }}>
          ## remaining gaps
        </div>
        <div style={{ color: PALETTE.textSecondary, fontSize: 12, paddingLeft: 12, borderLeft: `2px solid ${PALETTE.borderSubtle}` }}>
          train.py template<br />
          SLURM script generation<br />
          metrics emission protocol<br />
          security model
        </div>
      </div>

      {/* Simulated browser / docs */}
      <div style={{
        borderRight: `1px solid ${PALETTE.border}`,
        padding: 16,
        fontFamily: FONT.family,
        fontSize: 12,
        color: PALETTE.textSecondary,
        lineHeight: 1.7,
        overflow: "hidden",
      }}>
        <div style={{ color: PALETTE.textMuted, marginBottom: 8, fontSize: 10, letterSpacing: "0.06em", fontFamily: FONT.mono }}>
          firefox — quickshell docs
        </div>
        <div style={{ color: PALETTE.textPrimary, fontSize: 14, fontWeight: 600, marginBottom: 8 }}>
          PanelWindow
        </div>
        <div style={{ color: PALETTE.textSecondary, marginBottom: 12 }}>
          A Wayland-specific panel that docks to screen edges
          and reserves space in the compositor layout.
        </div>
        <div style={{
          background: PALETTE.barBg,
          border: `1px solid ${PALETTE.borderSubtle}`,
          padding: 12,
          fontFamily: FONT.mono,
          fontSize: 11,
          color: PALETTE.textMuted,
          lineHeight: 1.7,
        }}>
          <span style={{ color: PALETTE.accent }}>PanelWindow</span> {"{"}<br />
          &nbsp;&nbsp;anchors.top: <span style={{ color: PALETTE.textSecondary }}>true</span><br />
          &nbsp;&nbsp;anchors.left: <span style={{ color: PALETTE.textSecondary }}>true</span><br />
          &nbsp;&nbsp;anchors.right: <span style={{ color: PALETTE.textSecondary }}>true</span><br />
          &nbsp;&nbsp;implicitHeight: <span style={{ color: PALETTE.textSecondary }}>34</span><br />
          {"}"}
        </div>
      </div>

      {/* Simulated Garden */}
      <div style={{
        padding: 16,
        fontFamily: FONT.family,
        overflow: "hidden",
      }}>
        <div style={{ color: PALETTE.textMuted, marginBottom: 8, fontSize: 10, letterSpacing: "0.06em", fontFamily: FONT.mono }}>
          garden — channels
        </div>
        <div style={{ color: PALETTE.textPrimary, fontSize: 14, fontWeight: 700, marginBottom: 4 }}>
          Garden
        </div>
        <div style={{
          fontSize: 10,
          color: PALETTE.textMuted,
          marginBottom: 12,
          letterSpacing: "0.03em",
        }}>
          7 channels · 44 blocks
        </div>
        <div style={{ display: "grid", gridTemplateColumns: "1fr 1fr", gap: 8 }}>
          {["Hiromix", "interiors", "doors", "JDM"].map((ch, i) => (
            <div key={ch} style={{
              border: `1px solid ${PALETTE.border}`,
              padding: "8px 10px",
            }}>
              <div style={{
                height: 40,
                background: PALETTE.surfaceHighlight,
                marginBottom: 6,
                display: "flex",
                alignItems: "center",
                justifyContent: "center",
                fontSize: 9,
                color: PALETTE.textMuted,
                fontFamily: FONT.mono,
              }}>
                {[6, 5, 6, 8][i]} blocks
              </div>
              <div style={{
                fontSize: 11,
                fontWeight: 600,
                color: PALETTE.textPrimary,
              }}>
                {ch}
              </div>
            </div>
          ))}
        </div>
      </div>
    </div>
  );
}

// ─── Main Shell ───
export default function GardenShell() {
  const [launcherOpen, setLauncherOpen] = useState(false);
  const [showNotifs, setShowNotifs] = useState(true);

  useEffect(() => {
    const handler = (e) => {
      if (e.key === "/" && !launcherOpen) {
        e.preventDefault();
        setLauncherOpen(true);
      }
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [launcherOpen]);

  // Auto-dismiss notifications
  useEffect(() => {
    const id = setTimeout(() => setShowNotifs(false), 12000);
    return () => clearTimeout(id);
  }, []);

  return (
    <div style={{
      width: "100%",
      height: "100vh",
      display: "flex",
      flexDirection: "column",
      background: PALETTE.surface,
      overflow: "hidden",
      position: "relative",
    }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=M+PLUS+1p:wght@300;400;500;700&family=IBM+Plex+Mono:wght@300;400;500&display=swap');
        
        * { box-sizing: border-box; margin: 0; padding: 0; }
        
        ::placeholder {
          color: ${PALETTE.textMuted};
          opacity: 1;
        }
        
        ::-webkit-scrollbar {
          width: 4px;
        }
        ::-webkit-scrollbar-track {
          background: transparent;
        }
        ::-webkit-scrollbar-thumb {
          background: ${PALETTE.border};
        }
        
        @keyframes blink {
          50% { opacity: 0; }
        }
        
        @keyframes slideIn {
          from {
            transform: translateX(20px);
            opacity: 0;
          }
          to {
            transform: translateX(0);
            opacity: 1;
          }
        }
        
        @keyframes fadeIn {
          from { opacity: 0; }
          to { opacity: 1; }
        }
      `}</style>

      <Bar
        onLauncherToggle={() => setLauncherOpen(!launcherOpen)}
        launcherOpen={launcherOpen}
      />

      <DesktopContent />

      {/* Notifications — right edge */}
      {showNotifs && (
        <div style={{
          position: "fixed",
          top: 50,
          right: 16,
          zIndex: 150,
          display: "flex",
          flexDirection: "column",
          gap: 8,
        }}>
          {NOTIFICATIONS.map((n, i) => (
            <Notification
              key={i}
              notif={n}
              style={{
                animation: `slideIn 0.2s ease-out ${i * 0.08}s both`,
              }}
            />
          ))}
        </div>
      )}

      <Launcher
        open={launcherOpen}
        onClose={() => setLauncherOpen(false)}
      />

      {/* Hint bar */}
      <div style={{
        position: "fixed",
        bottom: 0,
        left: 0,
        right: 0,
        height: 24,
        background: PALETTE.barBg,
        borderTop: `1px solid ${PALETTE.borderSubtle}`,
        display: "flex",
        alignItems: "center",
        justifyContent: "center",
        gap: 24,
        fontFamily: FONT.mono,
        fontSize: 9,
        color: PALETTE.textMuted,
        letterSpacing: "0.05em",
        zIndex: 100,
      }}>
        <span>press <span style={{ color: PALETTE.textSecondary }}>/</span> to search</span>
        <span>·</span>
        <span><span style={{ color: PALETTE.textSecondary }}>↑↓</span> navigate</span>
        <span>·</span>
        <span><span style={{ color: PALETTE.textSecondary }}>esc</span> close</span>
      </div>
    </div>
  );
}

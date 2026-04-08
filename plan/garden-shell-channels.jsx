import { useState, useEffect, useCallback, useRef } from "react";

// ═══════════════════════════════════════════════════
// Garden Shell — Channel-Focused Bar
// Active channel expands to show pages
// Inactive channels collapse to dots
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
  dotActive: "#d4c5a9",
  dotOccupied: "#6b7a8d",
  dotEmpty: "#3a4456",
};

const F = {
  sans: "'M PLUS 1p', 'Noto Sans JP', system-ui, sans-serif",
  mono: "'IBM Plex Mono', monospace",
};

const DITHER_DENSE = `url("data:image/svg+xml,%3Csvg width='2' height='2' xmlns='http://www.w3.org/2000/svg'%3E%3Crect x='0' y='0' width='1' height='1' fill='%23232b38' fill-opacity='0.88'/%3E%3Crect x='1' y='1' width='1' height='1' fill='%23232b38' fill-opacity='0.88'/%3E%3C/svg%3E")`;

// ─── Workspace Data Model ───
const CHANNELS = [
  {
    name: "studio",
    pages: [
      { name: "clip-studio", label: "clip studio" },
      { name: "aseprite", label: "aseprite" },
      { name: "godot", label: "godot" },
    ],
    activePage: 0,
    barMode: "minimal",
  },
  {
    name: "research",
    pages: [
      { name: "helix", label: "helix" },
      { name: "frontier", label: "frontier" },
      { name: "docs", label: "docs" },
    ],
    activePage: 0,
    barMode: "full",
  },
  {
    name: "writing",
    pages: [
      { name: "obsidian", label: "obsidian" },
      { name: "typst", label: "typst" },
    ],
    activePage: 0,
    barMode: "standard",
  },
  {
    name: "music",
    pages: [
      { name: "ardour", label: "ardour" },
      { name: "strudel", label: "strudel" },
      { name: "guitar", label: "guitar" },
    ],
    activePage: 1,
    barMode: "minimal",
  },
  {
    name: "system",
    pages: [
      { name: "config", label: "config" },
      { name: "monitor", label: "monitor" },
    ],
    activePage: 0,
    barMode: "full",
  },
];

function useTime() {
  const [time, setTime] = useState(new Date());
  useEffect(() => {
    const id = setInterval(() => setTime(new Date()), 1000);
    return () => clearInterval(id);
  }, []);
  return time;
}

function fmt(t) {
  return t.getHours().toString().padStart(2, "0") + ":" + t.getMinutes().toString().padStart(2, "0");
}
function fmtDate(t) {
  return t.toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" }).toLowerCase();
}
function fmtDateLong(t) {
  return t.toLocaleDateString("en-US", { weekday: "long", month: "long", day: "numeric", year: "numeric" }).toLowerCase();
}
function fmtSec(t) {
  return t.getSeconds().toString().padStart(2, "0");
}

// ═══════════════════════════════════════════════════
// CHANNEL DOT — collapsed indicator for inactive channels
// ═══════════════════════════════════════════════════

function ChannelDot({ channel, isActive, onSelect, hoveredChannel, onHover, onLeave }) {
  const isHovered = hoveredChannel === channel.name;
  const hasPages = channel.pages.length > 0;

  if (isActive) return null; // active channel rendered separately

  return (
    <div
      onMouseEnter={() => onHover(channel.name)}
      onMouseLeave={onLeave}
      onClick={() => onSelect(channel.name)}
      style={{
        display: "flex",
        alignItems: "center",
        gap: 0,
        cursor: "pointer",
        height: 34,
        padding: "0 2px",
        position: "relative",
      }}
    >
      {/* The dot */}
      <div style={{
        width: 5,
        height: 5,
        borderRadius: "50%",
        background: hasPages ? P.dotOccupied : P.dotEmpty,
        transition: "all 0.2s ease",
        opacity: isHovered ? 0 : 1,
        flexShrink: 0,
      }} />

      {/* Expanded label on hover */}
      <div style={{
        overflow: "hidden",
        maxWidth: isHovered ? 120 : 0,
        opacity: isHovered ? 1 : 0,
        transition: "max-width 0.25s cubic-bezier(0.4, 0, 0.2, 1), opacity 0.2s ease",
        whiteSpace: "nowrap",
        display: "flex",
        alignItems: "center",
      }}>
        <span style={{
          fontSize: 11,
          color: P.textSecondary,
          fontWeight: 400,
          letterSpacing: "0.02em",
          padding: "0 6px",
          fontFamily: F.sans,
        }}>
          {channel.name}
        </span>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════
// ACTIVE CHANNEL — expanded with page tabs
// ═══════════════════════════════════════════════════

function ActiveChannel({ channel, onPageSelect }) {
  return (
    <div style={{
      display: "flex",
      alignItems: "center",
      height: 34,
      gap: 0,
    }}>
      {/* Channel name */}
      <div style={{
        fontSize: 12,
        fontWeight: 700,
        color: P.textPrimary,
        letterSpacing: "0.02em",
        paddingRight: 10,
        fontFamily: F.sans,
        borderRight: `1px solid ${P.borderSubtle}`,
        height: 34,
        display: "flex",
        alignItems: "center",
      }}>
        {channel.name}
      </div>

      {/* Pages */}
      <div style={{
        display: "flex",
        alignItems: "center",
        gap: 0,
      }}>
        {channel.pages.map((page, i) => {
          const isActive = i === channel.activePage;
          return (
            <div
              key={page.name}
              onClick={() => onPageSelect(i)}
              style={{
                fontSize: 11,
                color: isActive ? P.textPrimary : P.textMuted,
                fontWeight: isActive ? 600 : 400,
                letterSpacing: "0.02em",
                padding: "0 10px",
                height: 34,
                display: "flex",
                alignItems: "center",
                cursor: "pointer",
                background: isActive ? P.surfaceHighlight : "transparent",
                borderRight: `1px solid ${P.borderFaint}`,
                transition: "all 0.12s ease",
                fontFamily: F.sans,
                position: "relative",
              }}
            >
              {page.label}
              {/* Active page underline */}
              {isActive && (
                <div style={{
                  position: "absolute",
                  bottom: 0,
                  left: 10,
                  right: 10,
                  height: 1,
                  background: P.textPrimary,
                  opacity: 0.4,
                }} />
              )}
            </div>
          );
        })}
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════
// BAR
// ═══════════════════════════════════════════════════

function Bar({ channels, activeChannel, onChannelSelect, onPageSelect, barMode, onLauncher, time }) {
  const [hoveredChannel, setHoveredChannel] = useState(null);
  const active = channels.find(c => c.name === activeChannel);

  const showMetrics = barMode === "full";

  return (
    <div style={{
      height: 34,
      background: P.barBg,
      borderBottom: `1px solid ${P.borderSubtle}`,
      display: "flex",
      alignItems: "center",
      padding: "0 12px",
      fontFamily: F.sans,
      userSelect: "none",
      position: "relative",
      zIndex: 100,
      gap: 6,
    }}>
      {/* Channel navigation: dots for inactive, expanded for active */}
      <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
        {channels.map((ch) => {
          if (ch.name === activeChannel) {
            return (
              <ActiveChannel
                key={ch.name}
                channel={ch}
                onPageSelect={(pageIdx) => onPageSelect(ch.name, pageIdx)}
              />
            );
          }
          return (
            <ChannelDot
              key={ch.name}
              channel={ch}
              isActive={false}
              onSelect={onChannelSelect}
              hoveredChannel={hoveredChannel}
              onHover={setHoveredChannel}
              onLeave={() => setHoveredChannel(null)}
            />
          );
        })}
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
          fontSize: 13,
          fontWeight: 500,
          color: P.textPrimary,
          fontFamily: F.mono,
          letterSpacing: "0.05em",
        }}>
          {fmt(time)}
        </span>
        <span style={{
          fontSize: 10,
          color: P.textMuted,
          letterSpacing: "0.06em",
        }}>
          {fmtDate(time)}
        </span>
      </div>

      {/* Right: metrics (conditional) + launcher */}
      <div style={{
        marginLeft: "auto",
        display: "flex",
        alignItems: "center",
        gap: 14,
        fontFamily: F.mono,
        fontSize: 10,
        color: P.textMuted,
        letterSpacing: "0.03em",
      }}>
        {showMetrics && (
          <>
            <span>cpu <span style={{ color: P.textSecondary }}>8%</span></span>
            <span>mem <span style={{ color: P.textSecondary }}>4.1g</span></span>
            <span>vol <span style={{ color: P.textSecondary }}>72</span></span>
            <div style={{ width: 1, height: 12, background: P.borderSubtle }} />
          </>
        )}
        <span
          onClick={onLauncher}
          style={{
            color: P.textSecondary,
            cursor: "pointer",
            fontSize: 11,
            fontFamily: F.sans,
            fontWeight: 500,
          }}
        >
          /
        </span>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════
// CHANNEL SWITCHER OVERLAY (Super+Tab)
// ═══════════════════════════════════════════════════

function ChannelSwitcher({ open, channels, activeChannel, onSelect, onClose }) {
  const [sel, setSel] = useState(0);

  useEffect(() => {
    if (open) {
      const idx = channels.findIndex(c => c.name === activeChannel);
      setSel(idx >= 0 ? idx : 0);
    }
  }, [open, activeChannel, channels]);

  const handleKey = useCallback((e) => {
    if (!open) return;
    if (e.key === "Escape") onClose();
    else if (e.key === "ArrowDown" || e.key === "Tab") {
      e.preventDefault();
      setSel(i => (i + 1) % channels.length);
    } else if (e.key === "ArrowUp") {
      e.preventDefault();
      setSel(i => (i - 1 + channels.length) % channels.length);
    } else if (e.key === "Enter") {
      e.preventDefault();
      onSelect(channels[sel].name);
    }
  }, [open, channels, sel, onClose, onSelect]);

  useEffect(() => {
    window.addEventListener("keydown", handleKey);
    return () => window.removeEventListener("keydown", handleKey);
  }, [handleKey]);

  if (!open) return null;

  return (
    <div onClick={onClose} style={{
      position: "fixed", inset: 0, zIndex: 200,
      display: "flex", alignItems: "flex-start", justifyContent: "center", paddingTop: 100,
    }}>
      <div style={{
        position: "absolute", inset: 0,
        backgroundImage: DITHER_DENSE, backgroundRepeat: "repeat",
        imageRendering: "pixelated", animation: "fadeInSoft 0.1s ease",
      }} />
      <div onClick={e => e.stopPropagation()} style={{
        width: 380, background: P.surface, border: `1px solid ${P.border}`,
        position: "relative", zIndex: 1, fontFamily: F.sans,
        animation: "slideUp 0.12s ease",
      }}>
        {/* Header */}
        <div style={{
          padding: "10px 16px",
          borderBottom: `1px solid ${P.border}`,
          fontSize: 10,
          color: P.textMuted,
          fontFamily: F.mono,
          letterSpacing: "0.06em",
        }}>
          channels
        </div>

        {/* Channel list */}
        {channels.map((ch, i) => {
          const isSel = i === sel;
          const isCurrent = ch.name === activeChannel;
          return (
            <div
              key={ch.name}
              onMouseEnter={() => setSel(i)}
              onClick={() => onSelect(ch.name)}
              style={{
                padding: "12px 16px",
                background: isSel ? P.surfaceHighlight : "transparent",
                borderBottom: i < channels.length - 1 ? `1px solid ${P.borderFaint}` : "none",
                cursor: "pointer",
                transition: "background 0.08s ease",
              }}
            >
              <div style={{
                display: "flex",
                justifyContent: "space-between",
                alignItems: "baseline",
                marginBottom: 6,
              }}>
                <span style={{
                  fontSize: 13,
                  fontWeight: isCurrent ? 700 : isSel ? 600 : 400,
                  color: isCurrent ? P.textPrimary : isSel ? P.textPrimary : P.textSecondary,
                  letterSpacing: "0.02em",
                }}>
                  {ch.name}
                </span>
                <span style={{
                  fontSize: 9,
                  color: P.textFaint,
                  fontFamily: F.mono,
                  letterSpacing: "0.04em",
                }}>
                  {ch.pages.length} {ch.pages.length === 1 ? "page" : "pages"}
                </span>
              </div>
              {/* Pages listed below */}
              <div style={{
                display: "flex",
                gap: 0,
                flexWrap: "wrap",
              }}>
                {ch.pages.map((page, pi) => {
                  const isActivePage = pi === ch.activePage;
                  return (
                    <span key={page.name} style={{
                      fontSize: 10,
                      color: isActivePage ? P.textSecondary : P.textFaint,
                      fontWeight: isActivePage ? 500 : 400,
                      fontFamily: F.mono,
                      letterSpacing: "0.03em",
                    }}>
                      {page.label}
                      {pi < ch.pages.length - 1 && (
                        <span style={{ color: P.textFaint, margin: "0 6px" }}>·</span>
                      )}
                    </span>
                  );
                })}
              </div>
            </div>
          );
        })}

        {/* Footer hints */}
        <div style={{
          padding: "6px 16px",
          borderTop: `1px solid ${P.borderFaint}`,
          display: "flex",
          gap: 16,
          fontFamily: F.mono,
          fontSize: 9,
          color: P.textFaint,
          letterSpacing: "0.04em",
        }}>
          <span><span style={{ color: P.textMuted }}>↑↓</span> select</span>
          <span><span style={{ color: P.textMuted }}>↵</span> switch</span>
          <span><span style={{ color: P.textMuted }}>esc</span> close</span>
        </div>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════
// APP LAUNCHER
// ═══════════════════════════════════════════════════

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
        position: "relative", zIndex: 1, fontFamily: F.sans, animation: "slideUp 0.15s ease",
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
              <span style={{ fontSize: 13, fontWeight: i === sel ? 600 : 400, color: i === sel ? P.textPrimary : P.textSecondary }}>{app.name}</span>
              <span style={{ fontSize: 10, color: P.textMuted, fontFamily: F.mono, letterSpacing: "0.04em" }}>{app.type}</span>
            </div>
          ))}
          {filtered.length === 0 && <div style={{ padding: "24px 16px", fontSize: 12, color: P.textMuted, textAlign: "center" }}>no results</div>}
        </div>
        <div style={{ padding: "6px 16px", borderTop: `1px solid ${P.borderFaint}`, display: "flex", gap: 16, fontFamily: F.mono, fontSize: 9, color: P.textFaint, letterSpacing: "0.04em" }}>
          <span><span style={{ color: P.textMuted }}>↑↓</span> navigate</span>
          <span><span style={{ color: P.textMuted }}>↵</span> launch</span>
          <span><span style={{ color: P.textMuted }}>esc</span> close</span>
        </div>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════
// FLOATING SCRATCHPAD (with dither backdrop)
// ═══════════════════════════════════════════════════

function Scratchpad({ open, name, onClose }) {
  if (!open) return null;

  const content = {
    garden: {
      title: "Garden",
      body: "7 channels · 44 blocks",
      detail: "Hiromix · interiors · doors · JDM · restaurant · tattoo.manga · tattoo.portrait",
    },
    terminal: {
      title: "scratchpad",
      body: "quick terminal",
      detail: "ada@nix ~ $",
    },
  };

  const c = content[name] || content.terminal;

  return (
    <div onClick={onClose} style={{
      position: "fixed", inset: 0, zIndex: 180,
      display: "flex", alignItems: "center", justifyContent: "center",
    }}>
      {/* Dithered backdrop */}
      <div style={{
        position: "absolute", inset: 0,
        backgroundImage: DITHER_DENSE, backgroundRepeat: "repeat",
        imageRendering: "pixelated", animation: "fadeInSoft 0.1s ease",
      }} />
      {/* Floating window */}
      <div onClick={e => e.stopPropagation()} style={{
        width: 600, height: 400,
        background: P.surface,
        border: `1px solid ${P.border}`,
        position: "relative", zIndex: 1,
        fontFamily: F.sans,
        animation: "scaleIn 0.15s ease",
        display: "flex", flexDirection: "column",
      }}>
        {/* Title bar */}
        <div style={{
          height: 30, padding: "0 14px",
          borderBottom: `1px solid ${P.borderSubtle}`,
          display: "flex", alignItems: "center", justifyContent: "space-between",
          fontSize: 10, fontFamily: F.mono, color: P.textMuted,
          letterSpacing: "0.06em",
        }}>
          <span>special:{name}</span>
          <span onClick={onClose} style={{ cursor: "pointer", color: P.textFaint, fontSize: 12 }}>×</span>
        </div>
        {/* Content area */}
        <div style={{ flex: 1, padding: 20, overflow: "auto" }}>
          <div style={{ fontSize: 16, fontWeight: 700, color: P.textPrimary, marginBottom: 6 }}>{c.title}</div>
          <div style={{ fontSize: 11, color: P.textMuted, marginBottom: 16, fontFamily: F.mono, letterSpacing: "0.03em" }}>{c.body}</div>
          <div style={{ fontSize: 12, color: P.textSecondary, lineHeight: 1.7 }}>{c.detail}</div>
          {name === "terminal" && (
            <div style={{ marginTop: 16, fontFamily: F.mono, fontSize: 12 }}>
              <span style={{ color: P.accent }}>ada</span>
              <span style={{ color: P.textMuted }}>@</span>
              <span style={{ color: P.textSecondary }}>nix</span>
              <span style={{ color: P.textMuted }}> ~ </span>
              <span style={{ color: P.textPrimary }}>$</span>
              <span style={{ display: "inline-block", width: 7, height: 13, background: P.textPrimary, marginLeft: 4, opacity: 0.7, animation: "blink 1s step-end infinite" }} />
            </div>
          )}
        </div>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════
// NOTIFICATIONS
// ═══════════════════════════════════════════════════

const NOTIFICATIONS = [
  { app: "slurm", body: "Job 48291 completed on frontier — 4 nodes, 12m wall time", time: "2m ago" },
  { app: "garden", body: "New block added to restaurant channel", time: "8m ago" },
];

function NotificationStack({ notifications, visible }) {
  if (!visible || !notifications.length) return null;
  return (
    <div style={{ position: "fixed", top: 50, right: 12, zIndex: 150, display: "flex", flexDirection: "column", gap: 6 }}>
      {notifications.map((n, i) => (
        <div key={i} style={{
          width: 264, background: P.surfaceRaised, border: `1px solid ${P.border}`,
          padding: "10px 14px", fontFamily: F.sans, animation: `slideIn 0.2s ease-out ${i * 0.06}s both`,
        }}>
          <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: 5 }}>
            <span style={{ fontSize: 11, fontWeight: 700, color: P.textPrimary, letterSpacing: "0.02em" }}>{n.app}</span>
            <span style={{ fontSize: 9, color: P.textFaint, fontFamily: F.mono }}>{n.time}</span>
          </div>
          <div style={{ fontSize: 12, color: P.textSecondary, lineHeight: 1.5 }}>{n.body}</div>
          <div style={{ marginTop: 8, height: 1, background: P.borderSubtle, position: "relative", overflow: "hidden" }}>
            <div style={{ position: "absolute", top: 0, left: 0, height: 1, background: P.textMuted, width: "100%", animation: `shrink 10s linear ${i * 0.06}s forwards` }} />
          </div>
        </div>
      ))}
    </div>
  );
}

// ═══════════════════════════════════════════════════
// DESKTOP CONTENT
// ═══════════════════════════════════════════════════

const CHANNEL_CONTENT = {
  "research": {
    "helix": (
      <div style={{ padding: 20, fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, color: "#8b9bb0", lineHeight: 1.8 }}>
        <div style={{ color: "#6b7a8d", marginBottom: 8, fontSize: 10, letterSpacing: "0.06em" }}>helix — src/agent/scheduler.rs</div>
        <div>
          <span style={{ color: "#6b7a8d" }}>use</span> <span style={{ color: "#8b9bb0" }}>crate::storage::StoragePort</span>;<br />
          <span style={{ color: "#6b7a8d" }}>use</span> <span style={{ color: "#8b9bb0" }}>crate::slurm::SlurmBridge</span>;<br /><br />
          <span style={{ color: "#505e70" }}>/// Schedules experiment runs on the cluster</span><br />
          <span style={{ color: "#6b7a8d" }}>pub struct</span> <span style={{ color: "#c9b88c" }}>Scheduler</span> {"{"}<br />
          &nbsp;&nbsp;<span style={{ color: "#8b9bb0" }}>storage</span>: Box{"<"}dyn StoragePort{">"}, <br />
          &nbsp;&nbsp;<span style={{ color: "#8b9bb0" }}>bridge</span>: SlurmBridge,<br />
          &nbsp;&nbsp;<span style={{ color: "#8b9bb0" }}>max_concurrent</span>: <span style={{ color: "#6b7a8d" }}>usize</span>,<br />
          {"}"}<br /><br />
          <span style={{ color: "#6b7a8d" }}>impl</span> <span style={{ color: "#c9b88c" }}>Scheduler</span> {"{"}<br />
          &nbsp;&nbsp;<span style={{ color: "#6b7a8d" }}>pub async fn</span> <span style={{ color: "#8b9bb0" }}>submit</span>({"&"}self, config: {"&"}ExperimentConfig) {"{"}<br />
          &nbsp;&nbsp;&nbsp;&nbsp;<span style={{ color: "#6b7a8d" }}>let</span> script = self.bridge.<span style={{ color: "#8b9bb0" }}>generate_slurm</span>(config)?;<br />
          &nbsp;&nbsp;&nbsp;&nbsp;<span style={{ color: "#6b7a8d" }}>let</span> job_id = self.bridge.<span style={{ color: "#8b9bb0" }}>sbatch</span>({"&"}script).<span style={{ color: "#6b7a8d" }}>await</span>?;<br />
          &nbsp;&nbsp;&nbsp;&nbsp;self.storage.<span style={{ color: "#8b9bb0" }}>record_submission</span>(job_id, config).<span style={{ color: "#6b7a8d" }}>await</span>?;<br />
        </div>
      </div>
    ),
    "frontier": (
      <div style={{ padding: 20, fontFamily: "'IBM Plex Mono', monospace", fontSize: 12, color: "#8b9bb0", lineHeight: 1.8 }}>
        <div style={{ color: "#6b7a8d", marginBottom: 8, fontSize: 10, letterSpacing: "0.06em" }}>ghostty — frontier-login01</div>
        <div>
          <span style={{ color: "#c4796b" }}>ada</span>
          <span style={{ color: "#6b7a8d" }}>@</span>
          <span style={{ color: "#c4796b" }}>frontier-login01</span>
          <span style={{ color: "#6b7a8d" }}> ~ </span>
          <span style={{ color: "#d4c5a9" }}>$</span>
        </div>
        <div style={{ color: "#6b7a8d" }}>squeue -u ada --format="%.8i %.12j %.8T %.10M %.4D"</div>
        <div style={{ marginTop: 4, opacity: 0.7, fontSize: 11 }}>
          JOBID &nbsp;&nbsp;&nbsp;&nbsp;NAME &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;STATE &nbsp;&nbsp;TIME &nbsp;&nbsp;NODES<br />
          48291 &nbsp;&nbsp;&nbsp;train_v3 &nbsp;&nbsp;RUNNING &nbsp;0:12:18 &nbsp;4<br />
          48292 &nbsp;&nbsp;&nbsp;eval_suite &nbsp;PENDING &nbsp;0:00:00 &nbsp;2<br />
        </div>
        <div style={{ marginTop: 12 }}>
          <span style={{ color: "#c4796b" }}>ada</span>
          <span style={{ color: "#6b7a8d" }}>@</span>
          <span style={{ color: "#c4796b" }}>frontier-login01</span>
          <span style={{ color: "#6b7a8d" }}> ~ </span>
          <span style={{ color: "#d4c5a9" }}>$</span>
          <span style={{ display: "inline-block", width: 7, height: 13, background: "#d4c5a9", marginLeft: 4, opacity: 0.7, animation: "blink 1s step-end infinite" }} />
        </div>
      </div>
    ),
    "docs": (
      <div style={{ padding: 20, fontFamily: "'M PLUS 1p', system-ui, sans-serif", fontSize: 13, color: "#8b9bb0", lineHeight: 1.7 }}>
        <div style={{ color: "#6b7a8d", marginBottom: 8, fontSize: 10, letterSpacing: "0.06em", fontFamily: "'IBM Plex Mono', monospace" }}>firefox — OLCF Documentation</div>
        <div style={{ color: "#d4c5a9", fontSize: 18, fontWeight: 700, marginBottom: 12 }}>Frontier User Guide</div>
        <div style={{ marginBottom: 12 }}>Frontier is an HPE Cray EX supercomputer located at the Oak Ridge Leadership Computing Facility.</div>
        <div style={{ fontSize: 14, fontWeight: 600, color: "#d4c5a9", marginBottom: 8 }}>Submitting Jobs</div>
        <div style={{ background: "#252d3b", border: "1px solid #3a4456", padding: 12, fontFamily: "'IBM Plex Mono', monospace", fontSize: 11, color: "#6b7a8d", lineHeight: 1.7 }}>
          <span style={{ color: "#c9b88c" }}>sbatch</span> --nodes=4 --time=00:30:00 \<br />
          &nbsp;&nbsp;--account=YOUR_PROJECT \<br />
          &nbsp;&nbsp;train_experiment.sh
        </div>
      </div>
    ),
  },
};

function DesktopContent({ activeChannel, activePage, channels }) {
  const channel = channels.find(c => c.name === activeChannel);
  if (!channel) return null;
  const page = channel.pages[channel.activePage];

  const content = CHANNEL_CONTENT[activeChannel]?.[page?.name];

  return (
    <div style={{ flex: 1, background: P.surface, overflow: "hidden", position: "relative" }}>
      {content || (
        <div style={{
          height: "100%", display: "flex", flexDirection: "column",
          alignItems: "center", justifyContent: "center",
          fontFamily: F.sans, color: P.textFaint,
        }}>
          <div style={{ fontSize: 14, fontWeight: 600, color: P.textMuted, marginBottom: 6 }}>
            {activeChannel} : {page?.label}
          </div>
          <div style={{ fontSize: 11, fontFamily: F.mono, letterSpacing: "0.04em" }}>
            window content
          </div>
        </div>
      )}
    </div>
  );
}

// ═══════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════

export default function GardenShellChannels() {
  const time = useTime();
  const [channels, setChannels] = useState(CHANNELS);
  const [activeChannel, setActiveChannel] = useState("research");
  const [launcherOpen, setLauncherOpen] = useState(false);
  const [switcherOpen, setSwitcherOpen] = useState(false);
  const [scratchpad, setScratchpad] = useState(null); // null | "garden" | "terminal"
  const [showNotifs, setShowNotifs] = useState(true);

  const activeChannelData = channels.find(c => c.name === activeChannel);
  const barMode = activeChannelData?.barMode || "standard";

  const switchChannel = (name) => {
    setActiveChannel(name);
    setSwitcherOpen(false);
  };

  const switchPage = (channelName, pageIdx) => {
    setChannels(chs => chs.map(ch =>
      ch.name === channelName ? { ...ch, activePage: pageIdx } : ch
    ));
  };

  // Navigate pages with Super+H/L (simulated with [ and ])
  const cyclePage = (dir) => {
    setChannels(chs => chs.map(ch => {
      if (ch.name !== activeChannel) return ch;
      const next = (ch.activePage + dir + ch.pages.length) % ch.pages.length;
      return { ...ch, activePage: next };
    }));
  };

  useEffect(() => {
    const handler = (e) => {
      if (launcherOpen || switcherOpen) return;
      if (e.key === "/") { e.preventDefault(); setLauncherOpen(true); }
      else if (e.key === "Tab" && !e.shiftKey) { e.preventDefault(); setSwitcherOpen(true); }
      else if (e.key === "[") { e.preventDefault(); cyclePage(-1); }
      else if (e.key === "]") { e.preventDefault(); cyclePage(1); }
      else if (e.key === "g" && e.altKey) { e.preventDefault(); setScratchpad(s => s === "garden" ? null : "garden"); }
      else if (e.key === "t" && e.altKey) { e.preventDefault(); setScratchpad(s => s === "terminal" ? null : "terminal"); }
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [launcherOpen, switcherOpen, activeChannel]);

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
        @keyframes scaleIn { from { transform: scale(0.97); opacity: 0; } to { transform: scale(1); opacity: 1; } }
        @keyframes fadeInSoft { from { opacity: 0; } to { opacity: 1; } }
        @keyframes shrink { from { width: 100%; } to { width: 0%; } }
      `}</style>

      <Bar
        channels={channels}
        activeChannel={activeChannel}
        onChannelSelect={switchChannel}
        onPageSelect={switchPage}
        barMode={barMode}
        onLauncher={() => setLauncherOpen(true)}
        time={time}
      />

      <DesktopContent
        activeChannel={activeChannel}
        activePage={activeChannelData?.activePage}
        channels={channels}
      />

      <NotificationStack notifications={NOTIFICATIONS} visible={showNotifs} />

      <Scratchpad
        open={scratchpad !== null}
        name={scratchpad || "terminal"}
        onClose={() => setScratchpad(null)}
      />

      <Launcher open={launcherOpen} onClose={() => setLauncherOpen(false)} />
      <ChannelSwitcher
        open={switcherOpen}
        channels={channels}
        activeChannel={activeChannel}
        onSelect={switchChannel}
        onClose={() => setSwitcherOpen(false)}
      />

      {/* Demo control strip */}
      <div style={{
        position: "fixed", bottom: 0, left: 0, right: 0, height: 28,
        background: P.barBg, borderTop: `1px solid ${P.borderSubtle}`,
        display: "flex", alignItems: "center", justifyContent: "center", gap: 6,
        fontFamily: F.mono, fontSize: 9, color: P.textMuted, letterSpacing: "0.04em",
        zIndex: 100, userSelect: "none",
      }}>
        <span style={{ color: P.textFaint }}>keys:</span>
        <span><span style={{ color: P.textSecondary }}>/</span> launcher</span>
        <span style={{ color: P.borderSubtle }}>·</span>
        <span><span style={{ color: P.textSecondary }}>tab</span> channels</span>
        <span style={{ color: P.borderSubtle }}>·</span>
        <span><span style={{ color: P.textSecondary }}>[ ]</span> pages</span>
        <span style={{ color: P.borderSubtle }}>·</span>
        <span><span style={{ color: P.textSecondary }}>alt+g</span> garden</span>
        <span style={{ color: P.borderSubtle }}>·</span>
        <span><span style={{ color: P.textSecondary }}>alt+t</span> terminal</span>
        <span style={{ color: P.borderSubtle }}>·</span>
        <span onClick={() => setShowNotifs(true)} style={{ cursor: "pointer" }}>notifs</span>
      </div>
    </div>
  );
}

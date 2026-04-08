import { useState, useEffect, useCallback } from "react";

// ═══════════════════════════════════════════════════
// Garden Shell — Host Awareness Mockup
// Shows machine context across bar, borders, switcher
// ═══════════════════════════════════════════════════

const P = {
  surface: "#2c3444", surfaceDeep: "#232b38", surfaceRaised: "#343d4f",
  surfaceHl: "#3d4759", border: "#4a5568", borderSub: "#3a4456",
  borderFaint: "#323b4b",
  text1: "#d4c5a9", text2: "#8b9bb0", text3: "#6b7a8d", text4: "#505e70",
  accent: "#c9b88c", urgent: "#c4796b", ok: "#7c9a7c",
  barBg: "#252d3b",
  // Host border tints
  urgentBorder: "#5c4444",
  accentBorder: "#5c5444",
  okBorder: "#445544",
};

const F = {
  sans: "'M PLUS 1p', 'Noto Sans JP', system-ui, sans-serif",
  mono: "'IBM Plex Mono', monospace",
};

const DITHER = `url("data:image/svg+xml,%3Csvg width='2' height='2' xmlns='http://www.w3.org/2000/svg'%3E%3Crect x='0' y='0' width='1' height='1' fill='%23232b38' fill-opacity='0.88'/%3E%3Crect x='1' y='1' width='1' height='1' fill='%23232b38' fill-opacity='0.88'/%3E%3C/svg%3E")`;

// ─── Host definitions ───
const HOSTS = {
  local: { label: null, color: null, borderColor: P.border },
  frontier: { label: "frontier-login01", short: "frontier", color: P.urgent, borderColor: P.urgentBorder, tier: "hpc" },
  "dgx-alpha": { label: "dgx-α.internal", short: "dgx-α", color: P.accent, borderColor: P.accentBorder, tier: "gpu" },
  homelab: { label: "homelab.local", short: "homelab", color: P.ok, borderColor: P.okBorder, tier: "home" },
};

// ─── Channels with host assignments per page ───
const CHANNELS = [
  {
    name: "studio",
    pages: [
      { name: "clip-studio", label: "clip studio", host: "local" },
      { name: "aseprite", label: "aseprite", host: "local" },
    ],
    activePage: 0,
  },
  {
    name: "research",
    pages: [
      { name: "helix", label: "helix", host: "local" },
      { name: "frontier", label: "frontier", host: "frontier" },
      { name: "dgx-train", label: "dgx-train", host: "dgx-alpha" },
      { name: "docs", label: "docs", host: "local" },
    ],
    activePage: 1,
  },
  {
    name: "writing",
    pages: [
      { name: "obsidian", label: "obsidian", host: "local" },
      { name: "typst", label: "typst", host: "local" },
    ],
    activePage: 0,
  },
  {
    name: "ops",
    pages: [
      { name: "frontier-mon", label: "monitoring", host: "frontier" },
      { name: "dgx-a", label: "dgx-α shell", host: "dgx-alpha" },
      { name: "homelab", label: "homelab", host: "homelab" },
    ],
    activePage: 0,
  },
  {
    name: "system",
    pages: [
      { name: "config", label: "config", host: "local" },
      { name: "monitor", label: "monitor", host: "local" },
    ],
    activePage: 0,
  },
];

// ─── Time ───
function useTime() {
  const [t, setT] = useState(new Date());
  useEffect(() => { const id = setInterval(() => setT(new Date()), 1000); return () => clearInterval(id); }, []);
  return t;
}
const fmt = t => t.getHours().toString().padStart(2, "0") + ":" + t.getMinutes().toString().padStart(2, "0");
const fmtD = t => t.toLocaleDateString("en-US", { weekday: "short", month: "short", day: "numeric" }).toLowerCase();

// ═══════════════════════════════════════════════════
// HOST INDICATOR — the core new component
// ═══════════════════════════════════════════════════

function HostIndicator({ host }) {
  if (!host || !host.label) return null;

  return (
    <div style={{
      display: "flex", alignItems: "center", gap: 6,
      padding: "0 10px",
      height: 34,
      borderLeft: `1px solid ${P.borderSub}`,
      borderRight: `1px solid ${P.borderSub}`,
      animation: "fadeSlide 0.2s ease",
    }}>
      {/* Colored dot */}
      <div style={{
        width: 6, height: 6, borderRadius: "50%",
        background: host.color,
        boxShadow: `0 0 4px ${host.color}44`,
        flexShrink: 0,
      }} />
      {/* Host label */}
      <span style={{
        fontSize: 10,
        fontFamily: F.mono,
        color: host.color,
        letterSpacing: "0.04em",
        fontWeight: 500,
      }}>
        {host.label}
      </span>
    </div>
  );
}

// ═══════════════════════════════════════════════════
// BAR
// ═══════════════════════════════════════════════════

function Bar({ channels, activeChannel, onChannelSelect, onPageSelect, time, currentHost }) {
  const [hovered, setHovered] = useState(null);
  const active = channels.find(c => c.name === activeChannel);

  return (
    <div style={{
      height: 34, background: P.barBg, borderBottom: `1px solid ${P.borderSub}`,
      display: "flex", alignItems: "center", padding: "0 12px",
      fontFamily: F.sans, userSelect: "none", position: "relative", zIndex: 100, gap: 6,
    }}>
      {/* Channel dots + active channel */}
      <div style={{ display: "flex", alignItems: "center", gap: 6 }}>
        {channels.map(ch => {
          if (ch.name === activeChannel) {
            return (
              <div key={ch.name} style={{ display: "flex", alignItems: "center", height: 34 }}>
                <div style={{
                  fontSize: 12, fontWeight: 700, color: P.text1,
                  letterSpacing: "0.02em", paddingRight: 10,
                  borderRight: `1px solid ${P.borderSub}`,
                  height: 34, display: "flex", alignItems: "center",
                }}>
                  {ch.name}
                </div>
                <div style={{ display: "flex", alignItems: "center" }}>
                  {ch.pages.map((page, i) => {
                    const isActive = i === ch.activePage;
                    const pageHost = HOSTS[page.host];
                    const hasRemote = pageHost && pageHost.label;
                    return (
                      <div
                        key={page.name}
                        onClick={() => onPageSelect(ch.name, i)}
                        style={{
                          fontSize: 11, padding: "0 10px", height: 34,
                          display: "flex", alignItems: "center", gap: 4,
                          cursor: "pointer",
                          fontWeight: isActive ? 600 : 400,
                          color: isActive ? P.text1 : P.text3,
                          background: isActive ? P.surfaceHl : "transparent",
                          borderRight: `1px solid ${P.borderFaint}`,
                          transition: "all 0.12s ease",
                          position: "relative",
                        }}
                      >
                        {/* Small colored dot for remote pages */}
                        {hasRemote && (
                          <div style={{
                            width: 4, height: 4, borderRadius: "50%",
                            background: pageHost.color,
                            opacity: isActive ? 1 : 0.5,
                            flexShrink: 0,
                          }} />
                        )}
                        {page.label}
                        {isActive && (
                          <div style={{
                            position: "absolute", bottom: 0, left: 10, right: 10,
                            height: 1, background: P.text1, opacity: 0.4,
                          }} />
                        )}
                      </div>
                    );
                  })}
                </div>
              </div>
            );
          }
          // Inactive channel dot
          const isHov = hovered === ch.name;
          const hasWindows = ch.pages.length > 0;
          return (
            <div key={ch.name}
              onMouseEnter={() => setHovered(ch.name)}
              onMouseLeave={() => setHovered(null)}
              onClick={() => onChannelSelect(ch.name)}
              style={{
                display: "flex", alignItems: "center", cursor: "pointer",
                height: 34, padding: "0 2px",
              }}
            >
              <div style={{
                width: 5, height: 5, borderRadius: "50%",
                background: hasWindows ? P.text3 : P.borderSub,
                transition: "all 0.2s ease",
                opacity: isHov ? 0 : 1,
              }} />
              <div style={{
                overflow: "hidden",
                maxWidth: isHov ? 80 : 0, opacity: isHov ? 1 : 0,
                transition: "max-width 0.25s cubic-bezier(0.4,0,0.2,1), opacity 0.2s ease",
                whiteSpace: "nowrap",
              }}>
                <span style={{ fontSize: 11, color: P.text2, padding: "0 6px" }}>{ch.name}</span>
              </div>
            </div>
          );
        })}
      </div>

      {/* Host indicator — appears between pages and clock */}
      <HostIndicator host={currentHost} />

      {/* Center clock */}
      <div style={{
        position: "absolute", left: "50%", transform: "translateX(-50%)",
        display: "flex", alignItems: "baseline", gap: 8,
      }}>
        <span style={{ fontSize: 13, fontWeight: 500, color: P.text1, fontFamily: F.mono, letterSpacing: "0.05em" }}>
          {fmt(time)}
        </span>
        <span style={{ fontSize: 10, color: P.text3, letterSpacing: "0.06em" }}>{fmtD(time)}</span>
      </div>

      {/* Right metrics */}
      <div style={{
        marginLeft: "auto", display: "flex", alignItems: "center", gap: 14,
        fontFamily: F.mono, fontSize: 10, color: P.text3,
      }}>
        <span>cpu <span style={{ color: P.text2 }}>8%</span></span>
        <span>mem <span style={{ color: P.text2 }}>4.1g</span></span>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════
// WINDOW CONTENT — with host-tinted borders
// ═══════════════════════════════════════════════════

const CONTENT = {
  "research": {
    "helix": {
      host: "local",
      render: (p) => (
        <div style={{ fontFamily: F.mono, fontSize: 11, color: P.text3, lineHeight: 1.8, padding: 20 }}>
          <div style={{ color: P.text4, fontSize: 10, marginBottom: 8, letterSpacing: "0.06em" }}>helix — src/agent/scheduler.rs</div>
          <span style={{ color: P.text3 }}>pub struct</span> <span style={{ color: P.accent }}>Scheduler</span> {"{"}<br />
          &nbsp;&nbsp;<span style={{ color: P.text2 }}>storage</span>: Box{"<"}dyn StoragePort{">"}, <br />
          &nbsp;&nbsp;<span style={{ color: P.text2 }}>bridge</span>: SlurmBridge,<br />
          &nbsp;&nbsp;<span style={{ color: P.text2 }}>max_concurrent</span>: <span style={{ color: P.text3 }}>usize</span>,<br />
          {"}"}<br /><br />
          <span style={{ color: P.text3 }}>impl</span> <span style={{ color: P.accent }}>Scheduler</span> {"{"}<br />
          &nbsp;&nbsp;<span style={{ color: P.text3 }}>pub async fn</span> <span style={{ color: P.text1 }}>submit</span>({"&"}self) -{">"} <span style={{ color: P.ok }}>Result</span>{"<"}JobId{">"} {"{"}<br />
          &nbsp;&nbsp;&nbsp;&nbsp;<span style={{ color: P.text3 }}>let</span> script = self.bridge.<span style={{ color: P.text2 }}>generate_slurm</span>(config)?;<br />
          &nbsp;&nbsp;&nbsp;&nbsp;<span style={{ color: P.text3 }}>let</span> job_id = self.bridge.<span style={{ color: P.text2 }}>sbatch</span>({"&"}script).<span style={{ color: P.text3 }}>await</span>?;<br />
        </div>
      ),
    },
    "frontier": {
      host: "frontier",
      render: () => (
        <div style={{ fontFamily: F.mono, fontSize: 12, color: P.text2, lineHeight: 1.8, padding: 20 }}>
          <div style={{ color: P.text4, fontSize: 10, marginBottom: 8, letterSpacing: "0.06em" }}>ghostty — ssh frontier-login01</div>
          <div style={{ marginBottom: 4 }}>
            <span style={{ color: P.urgent }}>ada</span>
            <span style={{ color: P.text4 }}>@</span>
            <span style={{ color: P.urgent }}>frontier-login01</span>
            <span style={{ color: P.text3 }}> ~ </span>
            <span style={{ color: P.text1 }}>$</span>
            <span style={{ color: P.text3 }}> squeue -u ada</span>
          </div>
          <div style={{ color: P.text2, opacity: 0.8, fontSize: 11, marginBottom: 8 }}>
            JOBID &nbsp;&nbsp;NAME &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;STATE &nbsp;&nbsp;&nbsp;TIME &nbsp;&nbsp;&nbsp;NODES<br />
            48291 &nbsp;train_v3 &nbsp;&nbsp;&nbsp;<span style={{ color: P.ok }}>RUNNING</span> &nbsp;0:18:42 &nbsp;4<br />
            48292 &nbsp;eval_suite &nbsp;<span style={{ color: P.accent }}>PENDING</span> &nbsp;0:00:00 &nbsp;2<br />
            48293 &nbsp;sweep_lr &nbsp;&nbsp;&nbsp;<span style={{ color: P.ok }}>RUNNING</span> &nbsp;0:04:11 &nbsp;8<br />
          </div>
          <div>
            <span style={{ color: P.urgent }}>ada</span>
            <span style={{ color: P.text4 }}>@</span>
            <span style={{ color: P.urgent }}>frontier-login01</span>
            <span style={{ color: P.text3 }}> ~ </span>
            <span style={{ color: P.text1 }}>$</span>
            <span style={{ display: "inline-block", width: 7, height: 13, background: P.text1, marginLeft: 4, opacity: 0.7, animation: "blink 1s step-end infinite" }} />
          </div>
        </div>
      ),
    },
    "dgx-train": {
      host: "dgx-alpha",
      render: () => (
        <div style={{ fontFamily: F.mono, fontSize: 12, color: P.text2, lineHeight: 1.8, padding: 20 }}>
          <div style={{ color: P.text4, fontSize: 10, marginBottom: 8, letterSpacing: "0.06em" }}>ghostty — ssh dgx-α.internal</div>
          <div style={{ marginBottom: 4 }}>
            <span style={{ color: P.accent }}>ada</span>
            <span style={{ color: P.text4 }}>@</span>
            <span style={{ color: P.accent }}>dgx-α</span>
            <span style={{ color: P.text3 }}> ~/experiments </span>
            <span style={{ color: P.text1 }}>$</span>
            <span style={{ color: P.text3 }}> nvidia-smi --query-gpu=name,utilization.gpu,memory.used --format=csv</span>
          </div>
          <div style={{ color: P.text2, opacity: 0.8, fontSize: 11, marginBottom: 8 }}>
            name, utilization.gpu [%], memory.used [MiB]<br />
            A100-SXM4-80GB, <span style={{ color: P.ok }}>94 %</span>, 71842 MiB<br />
            A100-SXM4-80GB, <span style={{ color: P.ok }}>91 %</span>, 68204 MiB<br />
            A100-SXM4-80GB, <span style={{ color: P.accent }}>12 %</span>, 4210 MiB<br />
            A100-SXM4-80GB, <span style={{ color: P.text3 }}>0 %</span>, 512 MiB<br />
          </div>
          <div>
            <span style={{ color: P.accent }}>ada</span>
            <span style={{ color: P.text4 }}>@</span>
            <span style={{ color: P.accent }}>dgx-α</span>
            <span style={{ color: P.text3 }}> ~/experiments </span>
            <span style={{ color: P.text1 }}>$</span>
            <span style={{ display: "inline-block", width: 7, height: 13, background: P.text1, marginLeft: 4, opacity: 0.7, animation: "blink 1s step-end infinite" }} />
          </div>
        </div>
      ),
    },
    "docs": {
      host: "local",
      render: () => (
        <div style={{ fontFamily: F.sans, fontSize: 13, color: P.text2, lineHeight: 1.7, padding: 20 }}>
          <div style={{ color: P.text4, fontSize: 10, marginBottom: 8, letterSpacing: "0.06em", fontFamily: F.mono }}>firefox — OLCF User Guide</div>
          <div style={{ color: P.text1, fontSize: 18, fontWeight: 700, marginBottom: 12 }}>Frontier User Guide</div>
          <div style={{ marginBottom: 12 }}>Frontier is an HPE Cray EX supercomputer at the Oak Ridge Leadership Computing Facility.</div>
          <div style={{ background: P.barBg, border: `1px solid ${P.borderSub}`, padding: 12, fontFamily: F.mono, fontSize: 11, color: P.text3, lineHeight: 1.7 }}>
            <span style={{ color: P.accent }}>sbatch</span> --nodes=4 --time=00:30:00 \<br />
            &nbsp;&nbsp;--account=GEN000 \<br />
            &nbsp;&nbsp;train_experiment.sh
          </div>
        </div>
      ),
    },
  },
};

function WindowContent({ channel, page, host }) {
  const content = CONTENT[channel]?.[page];
  const hostDef = HOSTS[host] || HOSTS.local;
  const borderColor = hostDef.borderColor || P.border;

  return (
    <div style={{
      flex: 1, background: P.surface, overflow: "hidden",
      border: `1px solid ${borderColor}`,
      transition: "border-color 0.3s ease",
      position: "relative",
    }}>
      {/* Subtle top-edge host tint line */}
      {hostDef.color && (
        <div style={{
          position: "absolute", top: 0, left: 0, right: 0,
          height: 2, background: hostDef.color, opacity: 0.3,
        }} />
      )}
      {content ? content.render() : (
        <div style={{
          height: "100%", display: "flex", alignItems: "center",
          justifyContent: "center", color: P.text4,
          fontFamily: F.sans, fontSize: 12,
        }}>
          {channel} : {page}
        </div>
      )}
    </div>
  );
}

// ═══════════════════════════════════════════════════
// CHANNEL SWITCHER with host annotations
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
    else if (e.key === "ArrowDown" || e.key === "Tab") { e.preventDefault(); setSel(i => (i + 1) % channels.length); }
    else if (e.key === "ArrowUp") { e.preventDefault(); setSel(i => (i - 1 + channels.length) % channels.length); }
    else if (e.key === "Enter") { e.preventDefault(); onSelect(channels[sel].name); }
  }, [open, channels, sel, onClose, onSelect]);

  useEffect(() => {
    window.addEventListener("keydown", handleKey);
    return () => window.removeEventListener("keydown", handleKey);
  }, [handleKey]);

  if (!open) return null;

  return (
    <div onClick={onClose} style={{ position: "fixed", inset: 0, zIndex: 200, display: "flex", alignItems: "flex-start", justifyContent: "center", paddingTop: 80 }}>
      <div style={{ position: "absolute", inset: 0, backgroundImage: DITHER, backgroundRepeat: "repeat", imageRendering: "pixelated", animation: "fadeIn 0.1s ease" }} />
      <div onClick={e => e.stopPropagation()} style={{
        width: 420, background: P.surface, border: `1px solid ${P.border}`,
        position: "relative", zIndex: 1, fontFamily: F.sans, animation: "slideUp 0.12s ease",
      }}>
        <div style={{ padding: "10px 16px", borderBottom: `1px solid ${P.border}`, fontSize: 10, color: P.text3, fontFamily: F.mono, letterSpacing: "0.06em" }}>
          channels
        </div>
        {channels.map((ch, i) => {
          const isSel = i === sel;
          const isCur = ch.name === activeChannel;
          return (
            <div key={ch.name} onMouseEnter={() => setSel(i)} onClick={() => onSelect(ch.name)} style={{
              padding: "12px 16px",
              background: isSel ? P.surfaceHl : "transparent",
              borderBottom: i < channels.length - 1 ? `1px solid ${P.borderFaint}` : "none",
              cursor: "pointer",
            }}>
              <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: 6 }}>
                <span style={{ fontSize: 13, fontWeight: isCur ? 700 : isSel ? 600 : 400, color: isCur || isSel ? P.text1 : P.text2 }}>
                  {ch.name}
                </span>
                <span style={{ fontSize: 9, color: P.text4, fontFamily: F.mono }}>{ch.pages.length} pages</span>
              </div>
              {/* Pages with host annotations */}
              <div style={{ display: "flex", gap: 0, flexWrap: "wrap", alignItems: "center" }}>
                {ch.pages.map((page, pi) => {
                  const isActivePg = pi === ch.activePage;
                  const pageHost = HOSTS[page.host];
                  const hasRemote = pageHost && pageHost.label;
                  return (
                    <span key={page.name} style={{ display: "inline-flex", alignItems: "center", gap: 3 }}>
                      {/* Host dot */}
                      {hasRemote && (
                        <span style={{
                          display: "inline-block", width: 4, height: 4,
                          borderRadius: "50%", background: pageHost.color,
                          opacity: isActivePg ? 1 : 0.5,
                        }} />
                      )}
                      <span style={{
                        fontSize: 10, fontFamily: F.mono,
                        color: isActivePg ? P.text2 : P.text4,
                        fontWeight: isActivePg ? 500 : 400,
                      }}>
                        {page.label}
                      </span>
                      {/* Host arrow annotation */}
                      {hasRemote && (
                        <span style={{
                          fontSize: 9, fontFamily: F.mono,
                          color: pageHost.color,
                          opacity: 0.7,
                        }}>
                          → {pageHost.short}
                        </span>
                      )}
                      {pi < ch.pages.length - 1 && (
                        <span style={{ color: P.text4, margin: "0 5px", fontSize: 10 }}>·</span>
                      )}
                    </span>
                  );
                })}
              </div>
            </div>
          );
        })}
        <div style={{
          padding: "6px 16px", borderTop: `1px solid ${P.borderFaint}`,
          display: "flex", gap: 16, fontFamily: F.mono, fontSize: 9, color: P.text4,
        }}>
          <span><span style={{ color: P.text3 }}>↑↓</span> select</span>
          <span><span style={{ color: P.text3 }}>↵</span> switch</span>
          <span><span style={{ color: P.text3 }}>esc</span> close</span>
        </div>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════
// HOST NOTIFICATION
// ═══════════════════════════════════════════════════

function HostNotification({ visible }) {
  if (!visible) return null;
  return (
    <div style={{
      position: "fixed", top: 50, right: 16, zIndex: 150,
      width: 280, background: P.surfaceRaised, border: `1px solid ${P.border}`,
      padding: "10px 14px", fontFamily: F.sans, animation: "slideIn 0.2s ease-out",
    }}>
      <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: 5 }}>
        <span style={{ fontSize: 11, fontWeight: 700, color: P.text1 }}>
          slurm<span style={{ color: P.urgent, fontWeight: 400, fontSize: 10 }}>@frontier</span>
        </span>
        <span style={{ fontSize: 9, color: P.text4, fontFamily: F.mono }}>just now</span>
      </div>
      <div style={{ fontSize: 12, color: P.text2, lineHeight: 1.5 }}>
        Job 48291 <span style={{ color: P.ok }}>completed</span> — 4 nodes, 18m wall time
      </div>
      <div style={{ marginTop: 8, height: 1, background: P.borderSub, position: "relative", overflow: "hidden" }}>
        <div style={{ position: "absolute", top: 0, left: 0, height: 1, background: P.text3, width: "100%", animation: "shrink 10s linear forwards" }} />
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════
// HOST LEGEND
// ═══════════════════════════════════════════════════

function HostLegend() {
  const hosts = [
    { label: "local", color: null, desc: "no indicator" },
    { label: "frontier (hpc)", color: P.urgent, desc: "urgent — mistakes are expensive" },
    { label: "dgx-α (gpu)", color: P.accent, desc: "accent — powerful but recoverable" },
    { label: "homelab (home)", color: P.ok, desc: "ok — your own hardware" },
  ];
  return (
    <div style={{
      position: "fixed", bottom: 36, left: 16, zIndex: 90,
      background: P.surfaceRaised, border: `1px solid ${P.border}`,
      padding: "10px 14px", fontFamily: F.sans, width: 260,
    }}>
      <div style={{ fontSize: 10, fontWeight: 700, color: P.text1, marginBottom: 8, fontFamily: F.mono, letterSpacing: "0.06em" }}>
        host tiers
      </div>
      {hosts.map(h => (
        <div key={h.label} style={{ display: "flex", alignItems: "center", gap: 8, marginBottom: 4 }}>
          <div style={{
            width: 6, height: 6, borderRadius: "50%",
            background: h.color || P.borderSub,
            flexShrink: 0,
          }} />
          <span style={{ fontSize: 10, color: P.text2, fontFamily: F.mono, width: 100 }}>{h.label}</span>
          <span style={{ fontSize: 9, color: P.text4 }}>{h.desc}</span>
        </div>
      ))}
    </div>
  );
}

// ═══════════════════════════════════════════════════
// MAIN
// ═══════════════════════════════════════════════════

export default function HostAwareness() {
  const time = useTime();
  const [channels, setChannels] = useState(CHANNELS);
  const [activeChannel, setActiveChannel] = useState("research");
  const [switcherOpen, setSwitcherOpen] = useState(false);
  const [showNotif, setShowNotif] = useState(true);

  const active = channels.find(c => c.name === activeChannel);
  const activePage = active?.pages[active.activePage];
  const currentHost = activePage ? HOSTS[activePage.host] : null;

  const switchChannel = (name) => { setActiveChannel(name); setSwitcherOpen(false); };

  const switchPage = (chName, idx) => {
    setChannels(chs => chs.map(ch => ch.name === chName ? { ...ch, activePage: idx } : ch));
  };

  const cyclePage = (dir) => {
    setChannels(chs => chs.map(ch => {
      if (ch.name !== activeChannel) return ch;
      const next = (ch.activePage + dir + ch.pages.length) % ch.pages.length;
      return { ...ch, activePage: next };
    }));
  };

  useEffect(() => {
    const handler = (e) => {
      if (switcherOpen) return;
      if (e.key === "Tab") { e.preventDefault(); setSwitcherOpen(true); }
      else if (e.key === "[") { e.preventDefault(); cyclePage(-1); }
      else if (e.key === "]") { e.preventDefault(); cyclePage(1); }
    };
    window.addEventListener("keydown", handler);
    return () => window.removeEventListener("keydown", handler);
  }, [switcherOpen, activeChannel]);

  useEffect(() => {
    const id = setTimeout(() => setShowNotif(false), 12000);
    return () => clearTimeout(id);
  }, []);

  return (
    <div style={{ width: "100%", height: "100vh", display: "flex", flexDirection: "column", background: P.surface, overflow: "hidden", position: "relative" }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=M+PLUS+1p:wght@300;400;500;700&family=IBM+Plex+Mono:wght@300;400;500&display=swap');
        * { box-sizing: border-box; margin: 0; padding: 0; }
        ::-webkit-scrollbar { width: 3px; }
        ::-webkit-scrollbar-track { background: transparent; }
        ::-webkit-scrollbar-thumb { background: ${P.border}; }
        @keyframes blink { 50% { opacity: 0; } }
        @keyframes slideIn { from { transform: translateX(16px); opacity: 0; } to { transform: translateX(0); opacity: 1; } }
        @keyframes slideUp { from { transform: translateY(8px); opacity: 0; } to { transform: translateY(0); opacity: 1; } }
        @keyframes fadeIn { from { opacity: 0; } to { opacity: 1; } }
        @keyframes fadeSlide { from { opacity: 0; transform: translateX(-4px); } to { opacity: 1; transform: translateX(0); } }
        @keyframes shrink { from { width: 100%; } to { width: 0%; } }
      `}</style>

      <Bar
        channels={channels}
        activeChannel={activeChannel}
        onChannelSelect={switchChannel}
        onPageSelect={switchPage}
        time={time}
        currentHost={currentHost}
      />

      <WindowContent
        channel={activeChannel}
        page={activePage?.name}
        host={activePage?.host}
      />

      <HostNotification visible={showNotif} />

      <ChannelSwitcher
        open={switcherOpen}
        channels={channels}
        activeChannel={activeChannel}
        onSelect={switchChannel}
        onClose={() => setSwitcherOpen(false)}
      />

      <HostLegend />

      {/* Control strip */}
      <div style={{
        position: "fixed", bottom: 0, left: 0, right: 0, height: 28,
        background: P.barBg, borderTop: `1px solid ${P.borderSub}`,
        display: "flex", alignItems: "center", justifyContent: "center", gap: 6,
        fontFamily: F.mono, fontSize: 9, color: P.text3, letterSpacing: "0.04em",
        zIndex: 100, userSelect: "none",
      }}>
        <span><span style={{ color: P.text2 }}>[ ]</span> cycle pages — watch host indicator change</span>
        <span style={{ color: P.borderSub }}>·</span>
        <span><span style={{ color: P.text2 }}>tab</span> channel switcher — see host annotations</span>
        <span style={{ color: P.borderSub }}>·</span>
        <span onClick={() => setShowNotif(true)} style={{ cursor: "pointer", color: P.text2 }}>replay notification</span>
      </div>
    </div>
  );
}

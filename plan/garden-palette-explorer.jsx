import { useState } from "react";

// ═══════════════════════════════════════════════════
// Garden Palette Explorer
// See palettes in context, not as abstract swatches
// ═══════════════════════════════════════════════════

// PALETTE STRUCTURE — 14 semantic roles
// Every palette must fill these roles:
//
// Surfaces (4):
//   base        — primary background (desktop, window bg)
//   base-deep   — recessed elements (bar, code blocks)
//   base-raised — elevated elements (notifications, cards)
//   base-hl     — highlighted state (selected item, hover)
//
// Borders (2):
//   border      — primary dividers
//   border-sub  — subtle/secondary dividers
//
// Text (4):
//   text-1      — primary text (headings, active items)
//   text-2      — secondary text (body, descriptions)
//   text-3      — muted text (metadata, labels)
//   text-4      — faintest text (hints, disabled)
//
// Semantic (3):
//   accent      — interactive/accent (sparingly)
//   urgent      — alerts, remote indicators
//   ok          — success, safe states
//
// Special (1):
//   dot         — workspace dots, subtle indicators

const PALETTES = {
  // ─── MOKUME (woodgrain) ───
  // The palette from our mockups. Hague Blue family.
  // Warm-cool balance: cool base with warm text.
  // Risk: the blue can feel cold if text isn't warm enough.
  mokume: {
    name: "mokume",
    subtitle: "woodgrain — hague blue × warm cream",
    note: "Cool blue-slate base with warm cream text. The contrast comes from temperature difference, not just lightness. Inspired by Japanese indigo-dyed wood against raw hinoki.",
    base:       "#2c3444",
    baseDeep:   "#252d3b",
    baseRaised: "#343d4f",
    baseHl:     "#3d4759",
    border:     "#4a5568",
    borderSub:  "#3a4456",
    text1:      "#d4c5a9",
    text2:      "#8b9bb0",
    text3:      "#6b7a8d",
    text4:      "#505e70",
    accent:     "#c9b88c",
    urgent:     "#c4796b",
    ok:         "#7c9a7c",
    dot:        "#6b7a8d",
  },

  // ─── SUMI (charcoal ink) ───
  // True neutral with no hue in the base.
  // Warmth comes entirely from the text, which leans amber.
  // More austere. Closer to Are.na's actual palette.
  sumi: {
    name: "sumi",
    subtitle: "charcoal ink — neutral gray × amber",
    note: "Hueless gray base, warmth only in text and accents. This is closest to Are.na's actual design language — the chrome disappears completely, content is everything. Risk: can feel sterile without the warm text carrying enough weight.",
    base:       "#282828",
    baseDeep:   "#222222",
    baseRaised: "#313131",
    baseHl:     "#3a3a3a",
    border:     "#484848",
    borderSub:  "#383838",
    text1:      "#d4c4a0",
    text2:      "#9a9a8e",
    text3:      "#706f68",
    text4:      "#545450",
    accent:     "#c2a86a",
    urgent:     "#bf7565",
    ok:         "#7a9470",
    dot:        "#706f68",
  },

  // ─── BENGARA (red iron oxide) ───
  // Warm throughout. The base has a brown undertone,
  // like aged wood or dark earth. Text is pale straw.
  // Most "kissaten" of the options.
  bengara: {
    name: "bengara",
    subtitle: "red iron — dark earth × pale straw",
    note: "Warm all the way through — the base itself has a brown-red undertone, like aged zelkova or dark plaster. The warmest option. Risk: may feel too themed or too dark; some apps with their own warm tones could clash.",
    base:       "#2a2524",
    baseDeep:   "#231f1e",
    baseRaised: "#342e2c",
    baseHl:     "#3e3634",
    border:     "#524946",
    borderSub:  "#423a38",
    text1:      "#d6cab5",
    text2:      "#9e918a",
    text3:      "#766c67",
    text4:      "#5a524e",
    accent:     "#c4a670",
    urgent:     "#c07058",
    ok:         "#7a9472",
    dot:        "#766c67",
  },

  // ─── ASAGI (pale indigo) ───
  // A slightly more saturated blue, leaning toward
  // traditional Japanese indigo (藍). Cooler and more
  // modern-feeling. Text stays warm to counterbalance.
  asagi: {
    name: "asagi",
    subtitle: "pale indigo — deep aizome × warm linen",
    note: "More saturated blue than mokume, referencing traditional indigo dyeing. Feels more modern and slightly cooler. The indigo is deeper in the recessed surfaces, lighter in raised ones, creating a natural depth hierarchy. Pairs well with the gold accent.",
    base:       "#272f3e",
    baseDeep:   "#202838",
    baseRaised: "#303848",
    baseHl:     "#3a4358",
    border:     "#475270",
    borderSub:  "#374260",
    text1:      "#d8cbb0",
    text2:      "#8e9aae",
    text3:      "#687590",
    text4:      "#505c72",
    accent:     "#c5b080",
    urgent:     "#c47868",
    ok:         "#78967a",
    dot:        "#687590",
  },

  // ─── KITSUNE (fox) ───
  // Olive-tinted dark. The base has a very subtle
  // green-brown, like aged paper or forest floor at dusk.
  // An unusual direction — not quite brown, not quite green.
  kitsune: {
    name: "kitsune",
    subtitle: "fox — dusk olive × warm bone",
    note: "Unusual olive-brown undertone in the base, like aged paper or kombu kelp. Neither purely warm nor purely cool — it sits in a liminal space that feels very natural and organic. This is the most distinctive option and the hardest to pull off, but would be the most unique on r/unixporn.",
    base:       "#2a2c28",
    baseDeep:   "#232521",
    baseRaised: "#333530",
    baseHl:     "#3c3e39",
    border:     "#4d504a",
    borderSub:  "#3e413c",
    text1:      "#d2c9b0",
    text2:      "#959487",
    text3:      "#71706a",
    text4:      "#56554f",
    accent:     "#bfaa72",
    urgent:     "#c07a62",
    ok:         "#7c9670",
    dot:        "#71706a",
  },
};

const F = {
  sans: "'M PLUS 1p', 'Noto Sans JP', system-ui, sans-serif",
  mono: "'IBM Plex Mono', monospace",
};

// ─── Context Preview Components ───

function BarPreview({ p, time }) {
  return (
    <div style={{
      height: 34, background: p.baseDeep, borderBottom: `1px solid ${p.borderSub}`,
      display: "flex", alignItems: "center", padding: "0 14px",
      fontFamily: F.sans, fontSize: 12, userSelect: "none",
    }}>
      <span style={{ fontWeight: 700, color: p.text1, marginRight: 6 }}>research</span>
      <div style={{ width: 1, height: 14, background: p.borderSub, margin: "0 6px" }} />
      <span style={{ color: p.text1, fontWeight: 600, fontSize: 11, background: p.baseHl, padding: "2px 8px" }}>helix</span>
      <span style={{ color: p.text3, fontSize: 11, padding: "2px 8px" }}>frontier</span>
      <span style={{ color: p.text3, fontSize: 11, padding: "2px 8px" }}>docs</span>
      <div style={{ flex: 1 }} />
      <div style={{ display: "flex", gap: 6, alignItems: "center", marginRight: 12 }}>
        {[true, false, true, false].map((occ, i) => (
          <div key={i} style={{ width: 5, height: 5, borderRadius: "50%", background: occ ? p.dot : p.borderSub }} />
        ))}
      </div>
      <span style={{ fontFamily: F.mono, fontSize: 12, color: p.text1, letterSpacing: "0.05em" }}>{time}</span>
      <span style={{ fontFamily: F.mono, fontSize: 10, color: p.text3, marginLeft: 8 }}>cpu <span style={{ color: p.text2 }}>8%</span></span>
      <span style={{ fontFamily: F.mono, fontSize: 10, color: p.text3, marginLeft: 10 }}>mem <span style={{ color: p.text2 }}>4.1g</span></span>
    </div>
  );
}

function TerminalPreview({ p }) {
  return (
    <div style={{ background: p.base, padding: 14, fontFamily: F.mono, fontSize: 12, lineHeight: 1.8, borderBottom: `1px solid ${p.border}` }}>
      <div style={{ color: p.text4, fontSize: 10, marginBottom: 6, letterSpacing: "0.06em" }}>ghostty — research:frontier</div>
      <div>
        <span style={{ color: p.accent }}>ada</span>
        <span style={{ color: p.text4 }}>@</span>
        <span style={{ color: p.text2 }}>nix</span>
        <span style={{ color: p.text3 }}> ~/autoresearch </span>
        <span style={{ color: p.text1 }}>$</span>
        <span style={{ color: p.text3 }}> ssh login01.frontier.olcf.ornl.gov</span>
      </div>
      <div style={{ marginTop: 4 }}>
        <span style={{ color: p.urgent }}>ada</span>
        <span style={{ color: p.text4 }}>@</span>
        <span style={{ color: p.urgent }}>frontier-login01</span>
        <span style={{ color: p.text3 }}> ~ </span>
        <span style={{ color: p.text1 }}>$</span>
        <span style={{ color: p.text3 }}> squeue -u ada</span>
      </div>
      <div style={{ marginTop: 4, color: p.text2, opacity: 0.8, fontSize: 11 }}>
        48291 &nbsp;train_v3 &nbsp;&nbsp;<span style={{ color: p.ok }}>RUNNING</span> &nbsp;0:12:18 &nbsp;4 nodes<br />
        48292 &nbsp;eval_suite &nbsp;<span style={{ color: p.accent }}>PENDING</span> &nbsp;0:00:00 &nbsp;2 nodes
      </div>
      <div style={{ marginTop: 6 }}>
        <span style={{ color: p.urgent }}>ada</span>
        <span style={{ color: p.text4 }}>@</span>
        <span style={{ color: p.urgent }}>frontier-login01</span>
        <span style={{ color: p.text3 }}> ~ </span>
        <span style={{ color: p.text1 }}>$</span>
        <span style={{ display: "inline-block", width: 7, height: 13, background: p.text1, marginLeft: 4, opacity: 0.7 }} />
      </div>
    </div>
  );
}

function CodePreview({ p }) {
  return (
    <div style={{ background: p.base, padding: 14, fontFamily: F.mono, fontSize: 11, lineHeight: 1.8, borderBottom: `1px solid ${p.border}` }}>
      <div style={{ color: p.text4, fontSize: 10, marginBottom: 6, letterSpacing: "0.06em" }}>helix — src/agent/scheduler.rs</div>
      <div>
        <span style={{ color: p.text3 }}>use</span> <span style={{ color: p.text2 }}>crate::storage::StoragePort</span>;<br />
        <span style={{ color: p.text3 }}>use</span> <span style={{ color: p.text2 }}>crate::slurm::SlurmBridge</span>;<br /><br />
        <span style={{ color: p.text4 }}>/// Schedules experiment runs</span><br />
        <span style={{ color: p.text3 }}>pub struct</span> <span style={{ color: p.accent }}>Scheduler</span> {"{"}<br />
        &nbsp;&nbsp;<span style={{ color: p.text2 }}>storage</span>: <span style={{ color: p.text3 }}>Box</span>{"<"}dyn <span style={{ color: p.text2 }}>StoragePort</span>{">"},<br />
        &nbsp;&nbsp;<span style={{ color: p.text2 }}>bridge</span>: <span style={{ color: p.text2 }}>SlurmBridge</span>,<br />
        &nbsp;&nbsp;<span style={{ color: p.text2 }}>max_concurrent</span>: <span style={{ color: p.text3 }}>usize</span>,<br />
        {"}"}<br /><br />
        <span style={{ color: p.text3 }}>impl</span> <span style={{ color: p.accent }}>Scheduler</span> {"{"}<br />
        &nbsp;&nbsp;<span style={{ color: p.text3 }}>pub async fn</span> <span style={{ color: p.text1 }}>submit</span>(<br />
        &nbsp;&nbsp;&nbsp;&nbsp;{"&"}self,<br />
        &nbsp;&nbsp;&nbsp;&nbsp;config: {"&"}<span style={{ color: p.text2 }}>ExperimentConfig</span>,<br />
        &nbsp;&nbsp;) -{">"} <span style={{ color: p.text3 }}>Result</span>{"<"}<span style={{ color: p.ok }}>JobId</span>{">"} {"{"}<br />
        &nbsp;&nbsp;&nbsp;&nbsp;<span style={{ color: p.text3 }}>let</span> script = self.bridge<br />
        &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;.<span style={{ color: p.text2 }}>generate_slurm</span>(config)?;<br />
      </div>
    </div>
  );
}

function EditorPreview({ p }) {
  return (
    <div style={{ background: p.base, padding: 14, fontFamily: F.sans, fontSize: 13, lineHeight: 1.7, borderBottom: `1px solid ${p.border}` }}>
      <div style={{ color: p.text4, fontSize: 10, marginBottom: 6, letterSpacing: "0.06em", fontFamily: F.mono }}>obsidian — autoresearch-hpc.md</div>
      <div style={{ color: p.text1, fontSize: 16, fontWeight: 700, marginBottom: 8 }}>Autoresearch: Agent-Driven HPC</div>
      <div style={{ color: p.text2, marginBottom: 10, fontSize: 12 }}>
        The system coordinates autonomous ML experiments on Genesis-class supercomputers via a hexagonal architecture with trait-based storage ports.
      </div>
      <div style={{ color: p.text3, fontSize: 11, fontFamily: F.mono, marginBottom: 4 }}>## remaining gaps</div>
      <div style={{ color: p.text2, fontSize: 12, paddingLeft: 12, borderLeft: `2px solid ${p.borderSub}` }}>
        train.py template · SLURM script generation · metrics emission · security model
      </div>
    </div>
  );
}

function NotificationPreview({ p }) {
  return (
    <div style={{ display: "flex", flexDirection: "column", gap: 6, padding: 14 }}>
      <div style={{ background: p.baseRaised, border: `1px solid ${p.border}`, padding: "10px 14px", fontFamily: F.sans }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: 4 }}>
          <span style={{ fontSize: 11, fontWeight: 700, color: p.text1, letterSpacing: "0.02em" }}>slurm</span>
          <span style={{ fontSize: 9, color: p.text4, fontFamily: F.mono }}>2m ago</span>
        </div>
        <div style={{ fontSize: 12, color: p.text2, lineHeight: 1.5 }}>Job 48291 completed — 4 nodes, 12m wall</div>
        <div style={{ marginTop: 6, height: 1, background: p.borderSub, position: "relative", overflow: "hidden" }}>
          <div style={{ position: "absolute", top: 0, left: 0, height: 1, background: p.text3, width: "65%" }} />
        </div>
      </div>
      <div style={{ background: p.baseRaised, border: `1px solid ${p.border}`, padding: "10px 14px", fontFamily: F.sans }}>
        <div style={{ display: "flex", justifyContent: "space-between", alignItems: "baseline", marginBottom: 4 }}>
          <span style={{ fontSize: 11, fontWeight: 700, color: p.text1, letterSpacing: "0.02em" }}>garden</span>
          <span style={{ fontSize: 9, color: p.text4, fontFamily: F.mono }}>8m ago</span>
        </div>
        <div style={{ fontSize: 12, color: p.text2, lineHeight: 1.5 }}>New block added to restaurant</div>
      </div>
    </div>
  );
}

function SwatchRow({ p }) {
  const roles = [
    ["base-deep", p.baseDeep], ["base", p.base], ["base-raised", p.baseRaised], ["base-hl", p.baseHl],
    ["border-sub", p.borderSub], ["border", p.border],
    ["text-4", p.text4], ["text-3", p.text3], ["text-2", p.text2], ["text-1", p.text1],
    ["accent", p.accent], ["urgent", p.urgent], ["ok", p.ok],
  ];
  return (
    <div style={{ display: "flex", gap: 2, padding: "10px 14px", background: p.baseDeep, flexWrap: "wrap" }}>
      {roles.map(([name, color]) => (
        <div key={name} style={{ display: "flex", flexDirection: "column", alignItems: "center", gap: 3 }}>
          <div style={{
            width: 36, height: 24, background: color, border: `1px solid ${p.border}`,
          }} />
          <span style={{ fontSize: 8, color: p.text3, fontFamily: F.mono, letterSpacing: "0.02em" }}>{name}</span>
          <span style={{ fontSize: 7, color: p.text4, fontFamily: F.mono }}>{color}</span>
        </div>
      ))}
    </div>
  );
}

// ─── Main ───

export default function PaletteExplorer() {
  const [selected, setSelected] = useState("mokume");
  const [compare, setCompare] = useState(null);

  const time = "14:32";
  const names = Object.keys(PALETTES);
  const pal = PALETTES[selected];
  const cpal = compare ? PALETTES[compare] : null;

  const renderColumn = (p, showNote) => (
    <div style={{ flex: 1, minWidth: 0, display: "flex", flexDirection: "column" }}>
      {/* Palette info */}
      <div style={{ padding: "12px 14px", background: p.baseDeep, borderBottom: `1px solid ${p.borderSub}` }}>
        <div style={{ fontSize: 14, fontWeight: 700, color: p.text1, fontFamily: F.sans, marginBottom: 2 }}>{p.name}</div>
        <div style={{ fontSize: 11, color: p.text3, fontFamily: F.sans, letterSpacing: "0.02em" }}>{p.subtitle}</div>
        {showNote && <div style={{ fontSize: 11, color: p.text2, fontFamily: F.sans, marginTop: 8, lineHeight: 1.6 }}>{p.note}</div>}
      </div>

      {/* Swatches */}
      <SwatchRow p={p} />

      {/* Bar */}
      <BarPreview p={p} time={time} />

      {/* Terminal */}
      <TerminalPreview p={p} />

      {/* Code */}
      <CodePreview p={p} />

      {/* Editor */}
      <EditorPreview p={p} />

      {/* Notifications */}
      <NotificationPreview p={p} />
    </div>
  );

  return (
    <div style={{
      width: "100%", minHeight: "100vh", background: "#1a1a1a",
      fontFamily: F.sans, display: "flex", flexDirection: "column",
    }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=M+PLUS+1p:wght@300;400;500;700&family=IBM+Plex+Mono:wght@300;400;500&display=swap');
        * { box-sizing: border-box; margin: 0; padding: 0; }
        ::-webkit-scrollbar { width: 3px; }
        ::-webkit-scrollbar-track { background: transparent; }
        ::-webkit-scrollbar-thumb { background: #333; }
      `}</style>

      {/* Header / palette selector */}
      <div style={{
        padding: "16px 20px",
        background: "#1e1e1e",
        borderBottom: "1px solid #333",
        display: "flex",
        alignItems: "center",
        gap: 16,
        flexWrap: "wrap",
      }}>
        <div style={{ marginRight: 8 }}>
          <div style={{ fontSize: 14, fontWeight: 700, color: "#d4c5a9", marginBottom: 2 }}>garden palette explorer</div>
          <div style={{ fontSize: 10, color: "#6b7a8d", fontFamily: F.mono, letterSpacing: "0.04em" }}>14 semantic roles · 5 palette directions</div>
        </div>

        <div style={{ display: "flex", gap: 4, flexWrap: "wrap" }}>
          {names.map(name => {
            const p = PALETTES[name];
            const isSel = name === selected;
            return (
              <div
                key={name}
                onClick={() => { setSelected(name); setCompare(null); }}
                style={{
                  padding: "5px 12px",
                  fontSize: 11,
                  fontWeight: isSel ? 700 : 400,
                  color: isSel ? "#d4c5a9" : "#8b9bb0",
                  background: isSel ? p.base : "transparent",
                  border: `1px solid ${isSel ? p.border : "#333"}`,
                  cursor: "pointer",
                  fontFamily: F.sans,
                  transition: "all 0.12s ease",
                  display: "flex", alignItems: "center", gap: 6,
                }}
              >
                <div style={{ width: 8, height: 8, background: p.base, border: `1px solid ${p.border}` }} />
                {name}
              </div>
            );
          })}
        </div>

        <div style={{ display: "flex", gap: 4, marginLeft: "auto", alignItems: "center" }}>
          <span style={{ fontSize: 10, color: "#6b7a8d", fontFamily: F.mono, marginRight: 4 }}>compare:</span>
          {names.filter(n => n !== selected).map(name => {
            const isCmp = compare === name;
            return (
              <div
                key={name}
                onClick={() => setCompare(isCmp ? null : name)}
                style={{
                  padding: "3px 8px",
                  fontSize: 10,
                  color: isCmp ? "#d4c5a9" : "#505e70",
                  background: isCmp ? PALETTES[name].base : "transparent",
                  border: `1px solid ${isCmp ? PALETTES[name].border : "#2a2a2a"}`,
                  cursor: "pointer",
                  fontFamily: F.mono,
                  transition: "all 0.12s ease",
                }}
              >
                {name}
              </div>
            );
          })}
        </div>
      </div>

      {/* Content: single or side-by-side comparison */}
      <div style={{
        display: "flex",
        flex: 1,
        gap: compare ? 1 : 0,
        background: compare ? "#111" : "transparent",
      }}>
        {renderColumn(pal, !compare)}
        {cpal && renderColumn(cpal, false)}
      </div>

      {/* Footer: palette structure explanation */}
      <div style={{
        padding: "14px 20px",
        background: "#1e1e1e",
        borderTop: "1px solid #333",
        fontFamily: F.mono,
        fontSize: 10,
        color: "#6b7a8d",
        lineHeight: 1.8,
        letterSpacing: "0.03em",
      }}>
        <span style={{ color: "#8b9bb0", fontWeight: 500 }}>palette structure</span>
        <span style={{ color: "#333", margin: "0 8px" }}>│</span>
        surfaces: base-deep → base → base-raised → base-hl
        <span style={{ color: "#333", margin: "0 8px" }}>│</span>
        text: text-4 → text-3 → text-2 → text-1
        <span style={{ color: "#333", margin: "0 8px" }}>│</span>
        semantic: accent · urgent · ok
      </div>
    </div>
  );
}

import { useState, useEffect, useRef, useCallback } from "react";

// ═══════════════════════════════════════════════════
// Garden Palette Editor
// Quickshell FloatingWindow mockup — reference for QML
// ✧ prompt, Kakoune syntax, Niri channel model
// Switch between modes, edit any color, live preview
// ═══════════════════════════════════════════════════

const F = {
  sans: "'M PLUS 1p', 'Noto Sans JP', system-ui, sans-serif",
  mono: "'IBM Plex Mono', monospace",
};

const DITHER_DENSE = `url("data:image/svg+xml,%3Csvg width='2' height='2' xmlns='http://www.w3.org/2000/svg'%3E%3Crect x='0' y='0' width='1' height='1' fill='%23000' fill-opacity='0.45'/%3E%3Crect x='1' y='1' width='1' height='1' fill='%23000' fill-opacity='0.45'/%3E%3C/svg%3E")`;

// ─── Palette role definitions ───
const ROLE_GROUPS = [
  {
    group: "surfaces",
    roles: [
      { key: "baseDeep", label: "base-deep", desc: "bar, code blocks, recessed" },
      { key: "base", label: "base", desc: "primary background" },
      { key: "baseRaised", label: "base-raised", desc: "cards, notifications" },
      { key: "baseHl", label: "base-hl", desc: "hover, selected items" },
    ],
  },
  {
    group: "borders",
    roles: [
      { key: "borderSub", label: "border-sub", desc: "subtle dividers" },
      { key: "border", label: "border", desc: "primary dividers" },
    ],
  },
  {
    group: "text",
    roles: [
      { key: "text4", label: "text-4", desc: "hints, disabled" },
      { key: "text3", label: "text-3", desc: "metadata, labels" },
      { key: "text2", label: "text-2", desc: "body, secondary" },
      { key: "text1", label: "text-1", desc: "headings, primary" },
    ],
  },
  {
    group: "semantic",
    roles: [
      { key: "accent", label: "accent", desc: "interactive, sparse" },
      { key: "urgent", label: "urgent", desc: "alerts, remote SSH" },
      { key: "ok", label: "ok", desc: "success, running" },
    ],
  },
];

// ─── Four built-in modes ───
const BUILT_IN = {
  mokume: {
    name: "mokume",
    subtitle: "dark — hague blue × warm cream",
    icon: "◐",
    base: "#2c3444", baseDeep: "#252d3b", baseRaised: "#343d4f", baseHl: "#3d4759",
    border: "#4a5568", borderSub: "#3a4456",
    text1: "#d4c5a9", text2: "#8b9bb0", text3: "#6b7a8d", text4: "#505e70",
    accent: "#c9b88c", urgent: "#c4796b", ok: "#7c9a7c",
  },
  sumi: {
    name: "sumi",
    subtitle: "neutral — charcoal ink × amber",
    icon: "●",
    base: "#282828", baseDeep: "#222222", baseRaised: "#313131", baseHl: "#3a3a3a",
    border: "#484848", borderSub: "#383838",
    text1: "#d4c4a0", text2: "#9a9a8e", text3: "#706f68", text4: "#545450",
    accent: "#c2a86a", urgent: "#bf7565", ok: "#7a9470",
  },
  kinu: {
    name: "kinu",
    subtitle: "light — raw silk × dark walnut",
    icon: "○",
    base: "#e8e0d4", baseDeep: "#ddd5c8", baseRaised: "#f0e9de", baseHl: "#d8d0c2",
    border: "#c4b9a8", borderSub: "#d0c6b6",
    text1: "#2c2620", text2: "#5c554c", text3: "#8a8278", text4: "#a8a094",
    accent: "#8a7440", urgent: "#a85a48", ok: "#5a7a52",
  },
  yoru: {
    name: "yoru",
    subtitle: "night — no blue light × deep amber",
    icon: "◑",
    base: "#281e18", baseDeep: "#221a14", baseRaised: "#302520", baseHl: "#3a2e28",
    border: "#4a3e36", borderSub: "#3c322c",
    text1: "#d4b888", text2: "#a08a6e", text3: "#7a6a58", text4: "#5c5044",
    accent: "#c4a050", urgent: "#c07848", ok: "#7a9060",
  },
};

function deepClone(obj) {
  return JSON.parse(JSON.stringify(obj));
}

// ─── Hex Input Component ───
function HexInput({ value, onChange, roleLabel, roleDesc, palette }) {
  const [editing, setEditing] = useState(false);
  const [draft, setDraft] = useState(value);
  const inputRef = useRef(null);

  useEffect(() => { setDraft(value); }, [value]);

  const commit = () => {
    setEditing(false);
    if (/^#[0-9a-fA-F]{6}$/.test(draft)) {
      onChange(draft.toLowerCase());
    } else {
      setDraft(value);
    }
  };

  return (
    <div style={{
      display: "flex", alignItems: "center", gap: 8, padding: "4px 0",
    }}>
      {/* Color swatch — click to focus input */}
      <div
        onClick={() => { setEditing(true); setTimeout(() => inputRef.current?.select(), 20); }}
        style={{
          width: 20, height: 20, flexShrink: 0,
          background: value, border: `1px solid ${palette.border}`,
          cursor: "pointer",
        }}
      />
      {/* Role name */}
      <div style={{ width: 72, flexShrink: 0 }}>
        <div style={{ fontSize: 10, fontWeight: 600, color: palette.text1, fontFamily: F.mono, letterSpacing: "0.02em" }}>{roleLabel}</div>
      </div>
      {/* Hex input */}
      <div style={{
        width: 72, flexShrink: 0,
        border: `1px solid ${editing ? palette.border : palette.borderSub}`,
        background: editing ? palette.baseHl : palette.baseDeep,
        transition: "all 0.1s ease",
      }}>
        <input
          ref={inputRef}
          value={draft}
          onChange={e => setDraft(e.target.value)}
          onFocus={() => setEditing(true)}
          onBlur={commit}
          onKeyDown={e => { if (e.key === "Enter") commit(); if (e.key === "Escape") { setDraft(value); setEditing(false); } }}
          style={{
            width: "100%", padding: "3px 6px",
            background: "transparent", border: "none", outline: "none",
            color: palette.text2, fontSize: 10, fontFamily: F.mono,
            letterSpacing: "0.04em",
          }}
        />
      </div>
      {/* Description */}
      <div style={{ fontSize: 9, color: palette.text4, fontFamily: F.sans, flexShrink: 1, minWidth: 0 }}>
        {roleDesc}
      </div>
    </div>
  );
}

// ─── Mini Bar Preview ───
function MiniBar({ p }) {
  return (
    <div style={{
      height: 28, background: p.baseDeep, borderBottom: `1px solid ${p.borderSub}`,
      display: "flex", alignItems: "center", padding: "0 10px", fontFamily: F.sans, fontSize: 10,
    }}>
      <span style={{ fontWeight: 700, color: p.text1, marginRight: 4 }}>research</span>
      <div style={{ width: 1, height: 10, background: p.borderSub, margin: "0 4px" }} />
      <span style={{ color: p.text1, fontWeight: 600, fontSize: 9, background: p.baseHl, padding: "1px 6px" }}>kak</span>
      <span style={{ color: p.text3, fontSize: 9, padding: "1px 6px" }}>frontier</span>
      <span style={{ color: p.text3, fontSize: 9, padding: "1px 6px" }}>docs</span>
      <div style={{ flex: 1 }} />
      {/* Connection health dots */}
      <div style={{ display: "flex", gap: 3, alignItems: "center", marginRight: 8 }}>
        <span style={{ fontSize: 7, color: p.urgent }}>▪</span>
        <span style={{ fontSize: 7, color: p.accent }}>▪</span>
      </div>
      {/* Inactive channel dots */}
      <div style={{ display: "flex", gap: 4, alignItems: "center", marginRight: 8 }}>
        {[true, false, true, true].map((o, i) => (
          <div key={i} style={{ width: 4, height: 4, borderRadius: "50%", background: o ? p.text3 : p.borderSub }} />
        ))}
      </div>
      <span style={{ fontFamily: F.mono, fontSize: 10, color: p.text1, letterSpacing: "0.05em" }}>14:32</span>
    </div>
  );
}

// ─── Mini Terminal Preview ───
function MiniTerminal({ p }) {
  return (
    <div style={{ background: p.base, padding: "10px 10px 10px 26px", fontFamily: F.mono, fontSize: 10, lineHeight: 1.7 }}>
      {/* Local prompt — two-line with ✧ */}
      <div style={{ display: "flex", justifyContent: "space-between" }}>
        <span>
          <span style={{ color: p.text3 }}>~/garden-infra</span>
          <span style={{ color: p.text4 }}> main·3</span>
        </span>
        <span style={{ color: p.text4, fontSize: 9 }}>research:kak</span>
      </div>
      <span style={{ color: p.text1 }}>✧ </span>
      <span style={{ color: p.text3 }}>ssh frontier</span>
      <br /><br />
      {/* Remote prompt — hostname in tier color */}
      <div style={{ display: "flex", justifyContent: "space-between" }}>
        <span>
          <span style={{ color: p.text3 }}>~/experiments</span>
        </span>
        <span style={{ color: p.urgent, fontSize: 9 }}>frontier-login01</span>
      </div>
      <span style={{ color: p.urgent }}>✧ </span>
      <span style={{ color: p.text3 }}>squeue -u ada</span>
      <br />
      <span style={{ color: p.text2, fontSize: 9 }}>48291 train_v3 </span>
      <span style={{ color: p.ok, fontSize: 9 }}>RUNNING</span>
      <span style={{ color: p.text3, fontSize: 9 }}> 4 nodes</span>
    </div>
  );
}

// ─── Mini Code Preview (Kakoune-style syntax) ───
function MiniCode({ p }) {
  return (
    <div style={{ background: p.base, padding: 10, fontFamily: F.mono, fontSize: 10, lineHeight: 1.7, borderTop: `1px solid ${p.border}` }}>
      <span style={{ color: p.text4, fontStyle: "italic" }}>// garden-core/src/events.rs</span><br />
      <span style={{ color: p.text3 }}>pub enum</span> <span style={{ color: p.accent }}>GardenEvent</span> {"{"}<br />
      &nbsp;&nbsp;<span style={{ color: p.text1 }}>ConnectionEstablished</span> {"{"} <span style={{ color: p.text2 }}>host</span>: <span style={{ color: p.text2 }}>String</span> {"}"},<br />
      &nbsp;&nbsp;<span style={{ color: p.text1 }}>JobCompleted</span> {"{"} <span style={{ color: p.text2 }}>id</span>: <span style={{ color: p.accent }}>JobId</span>, <span style={{ color: p.text2 }}>result</span>: <span style={{ color: p.ok }}>Result</span> {"}"},<br />
      {"}"}<br />
    </div>
  );
}

// ─── Mini Notification Preview ───
function MiniNotif({ p }) {
  return (
    <div style={{ background: p.baseRaised, border: `1px solid ${p.border}`, padding: "8px 10px", fontFamily: F.sans }}>
      <div style={{ display: "flex", justifyContent: "space-between", marginBottom: 3 }}>
        <span style={{ fontSize: 10, fontWeight: 700, color: p.text1 }}>garden</span>
        <span style={{ fontSize: 8, color: p.text4, fontFamily: F.mono }}>2m</span>
      </div>
      <div style={{ fontSize: 10, color: p.text2, lineHeight: 1.4 }}>
        Job 48291 completed on <span style={{ color: p.urgent }}>frontier</span> — 4 nodes, 0:28:15
      </div>
      <div style={{ marginTop: 5, height: 1, background: p.borderSub }}>
        <div style={{ height: 1, background: p.text3, width: "60%" }} />
      </div>
    </div>
  );
}

// ─── Mini Editor/Prose Preview ───
function MiniEditor({ p }) {
  return (
    <div style={{ background: p.base, padding: 10, fontFamily: F.sans, borderTop: `1px solid ${p.border}` }}>
      <div style={{ fontSize: 13, fontWeight: 700, color: p.text1, marginBottom: 4 }}>Garden: Infrastructure as Pedagogy</div>
      <div style={{ fontSize: 10, color: p.text2, lineHeight: 1.6, marginBottom: 6 }}>
        Building is a form of inquiry. The technical choices in Garden are not neutral — they encode
        values about openness, self-determination, and access.
      </div>
      <div style={{ fontSize: 10, color: p.text2, paddingLeft: 8, borderLeft: `2px solid ${p.borderSub}`, lineHeight: 1.5 }}>
        critical making · feminist HCI · structural warmth
      </div>
    </div>
  );
}

// ─── Launcher Mini ───
function MiniLauncher({ p }) {
  const items = [
    { name: "obsidian", source: "writing:obsidian", type: "page" },
    { name: "Obsidian", source: "", type: "app" },
    { name: "Kitty", source: "", type: "app" },
  ];
  return (
    <div style={{ background: p.base, border: `1px solid ${p.border}` }}>
      <div style={{ padding: "6px 10px", borderBottom: `1px solid ${p.border}`, display: "flex", alignItems: "center" }}>
        <span style={{ color: p.text4, fontFamily: F.mono, fontSize: 10, marginRight: 6 }}>/</span>
        <span style={{ color: p.text2, fontFamily: F.sans, fontSize: 11 }}>obsidian</span>
      </div>
      {items.map((item, i) => (
        <div key={i} style={{
          padding: "6px 10px",
          background: i === 0 ? p.baseHl : "transparent",
          borderBottom: i < items.length - 1 ? `1px solid ${p.borderSub}` : "none",
          display: "flex", justifyContent: "space-between",
        }}>
          <span style={{ fontSize: 10, fontWeight: i === 0 ? 600 : 400, color: i === 0 ? p.text1 : p.text2 }}>
            {item.name}
            {item.source && <span style={{ color: p.text4, fontWeight: 400, marginLeft: 6, fontSize: 9 }}>{item.source}</span>}
          </span>
          <span style={{ fontSize: 8, color: p.text4, fontFamily: F.mono }}>{item.type}</span>
        </div>
      ))}
    </div>
  );
}

// ═══════════════════════════════════════════════════
// MAIN EDITOR
// ═══════════════════════════════════════════════════

export default function PaletteEditor() {
  const [palettes, setPalettes] = useState(deepClone(BUILT_IN));
  const [activeMode, setActiveMode] = useState("mokume");
  const [editorOpen, setEditorOpen] = useState(true);

  const p = palettes[activeMode];

  const updateColor = useCallback((key, value) => {
    setPalettes(prev => ({
      ...prev,
      [activeMode]: { ...prev[activeMode], [key]: value },
    }));
  }, [activeMode]);

  const resetMode = () => {
    setPalettes(prev => ({
      ...prev,
      [activeMode]: deepClone(BUILT_IN[activeMode]),
    }));
  };

  const exportPalette = () => {
    const out = {};
    ROLE_GROUPS.forEach(g => g.roles.forEach(r => { out[r.label] = p[r.key]; }));
    alert(JSON.stringify(out, null, 2));
  };

  // Background behind the editor
  const bgP = palettes[activeMode];

  return (
    <div style={{
      width: "100%", height: "100vh", background: bgP.base,
      display: "flex", flexDirection: "column", overflow: "hidden",
      position: "relative", fontFamily: F.sans,
    }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=M+PLUS+1p:wght@300;400;500;700&family=IBM+Plex+Mono:wght@300;400;500&display=swap');
        * { box-sizing: border-box; margin: 0; padding: 0; }
        ::placeholder { color: ${bgP.text4}; }
        ::-webkit-scrollbar { width: 3px; }
        ::-webkit-scrollbar-track { background: transparent; }
        ::-webkit-scrollbar-thumb { background: ${bgP.border}; }
        input[type="text"] { font-family: ${F.mono}; }
      `}</style>

      {/* ─── Live bar ─── */}
      <MiniBar p={p} />

      {/* ─── Desktop area with live preview ─── */}
      <div style={{ flex: 1, display: "grid", gridTemplateColumns: "1fr 1fr", gap: 0, overflow: "hidden" }}>
        {/* Left: terminal + code */}
        <div style={{ borderRight: `1px solid ${p.border}`, overflow: "auto" }}>
          <MiniTerminal p={p} />
          <MiniCode p={p} />
          <MiniEditor p={p} />
        </div>

        {/* Right: notifications + launcher */}
        <div style={{ display: "flex", flexDirection: "column", gap: 0, overflow: "auto" }}>
          <div style={{ padding: 12, display: "flex", flexDirection: "column", gap: 6 }}>
            <MiniNotif p={p} />
            <MiniLauncher p={p} />
          </div>
        </div>
      </div>

      {/* ─── Dithered backdrop when editor is open ─── */}
      {editorOpen && (
        <div
          onClick={() => setEditorOpen(false)}
          style={{
            position: "fixed", inset: 0, zIndex: 100,
            backgroundImage: DITHER_DENSE, backgroundRepeat: "repeat",
            imageRendering: "pixelated",
          }}
        />
      )}

      {/* ═══ FLOATING EDITOR WINDOW ═══ */}
      {editorOpen && (
        <div
          onClick={e => e.stopPropagation()}
          style={{
            position: "fixed",
            top: "50%", left: "50%",
            transform: "translate(-50%, -50%)",
            width: 720, maxHeight: "88vh",
            background: p.base,
            border: `1px solid ${p.border}`,
            zIndex: 200,
            display: "flex", flexDirection: "column",
            overflow: "hidden",
          }}
        >
          {/* ─── Window title bar ─── */}
          <div style={{
            height: 32, padding: "0 14px",
            background: p.baseDeep,
            borderBottom: `1px solid ${p.borderSub}`,
            display: "flex", alignItems: "center", justifyContent: "space-between",
            fontFamily: F.mono, fontSize: 10, color: p.text3,
            letterSpacing: "0.06em", userSelect: "none",
          }}>
            <span>garden — palette editor — {p.name}</span>
            <span onClick={() => setEditorOpen(false)} style={{ cursor: "pointer", color: p.text4, fontSize: 13 }}>×</span>
          </div>

          {/* ─── Mode selector tabs ─── */}
          <div style={{
            display: "flex", borderBottom: `1px solid ${p.border}`,
            background: p.baseDeep,
          }}>
            {Object.entries(palettes).map(([key, pal]) => {
              const isActive = key === activeMode;
              return (
                <div
                  key={key}
                  onClick={() => setActiveMode(key)}
                  style={{
                    flex: 1,
                    padding: "10px 14px",
                    cursor: "pointer",
                    background: isActive ? p.base : "transparent",
                    borderRight: `1px solid ${p.borderSub}`,
                    borderBottom: isActive ? `2px solid ${pal.text1}` : "2px solid transparent",
                    transition: "all 0.12s ease",
                    display: "flex", flexDirection: "column", alignItems: "center", gap: 3,
                  }}
                >
                  <span style={{ fontSize: 16, color: isActive ? pal.text1 : p.text4 }}>{pal.icon}</span>
                  <span style={{
                    fontSize: 11, fontWeight: isActive ? 700 : 400,
                    color: isActive ? pal.text1 : p.text3,
                    fontFamily: F.sans,
                  }}>
                    {pal.name}
                  </span>
                  <span style={{ fontSize: 9, color: p.text4, fontFamily: F.sans, textAlign: "center" }}>
                    {pal.subtitle}
                  </span>
                </div>
              );
            })}
          </div>

          {/* ─── Two-column layout: inputs left, preview right ─── */}
          <div style={{ flex: 1, display: "flex", overflow: "hidden" }}>

            {/* LEFT: color inputs */}
            <div style={{
              width: 380, borderRight: `1px solid ${p.border}`,
              overflow: "auto", padding: "8px 0",
            }}>
              {ROLE_GROUPS.map(group => (
                <div key={group.group}>
                  {/* Group header */}
                  <div style={{
                    padding: "8px 14px 4px",
                    fontSize: 9, fontWeight: 600, color: p.text3,
                    fontFamily: F.mono, letterSpacing: "0.08em",
                    textTransform: "uppercase",
                    borderTop: `1px solid ${p.borderSub}`,
                    marginTop: 2,
                  }}>
                    {group.group}
                  </div>
                  {/* Inputs */}
                  <div style={{ padding: "0 14px" }}>
                    {group.roles.map(role => (
                      <HexInput
                        key={role.key}
                        value={p[role.key]}
                        onChange={v => updateColor(role.key, v)}
                        roleLabel={role.label}
                        roleDesc={role.desc}
                        palette={p}
                      />
                    ))}
                  </div>
                </div>
              ))}
            </div>

            {/* RIGHT: live mini preview */}
            <div style={{ flex: 1, overflow: "auto", display: "flex", flexDirection: "column" }}>
              <div style={{
                padding: "8px 12px 4px",
                fontSize: 9, fontWeight: 600, color: p.text3,
                fontFamily: F.mono, letterSpacing: "0.08em",
                textTransform: "uppercase",
              }}>
                live preview
              </div>
              <MiniBar p={p} />
              <MiniTerminal p={p} />
              <MiniCode p={p} />
              <MiniEditor p={p} />
              <div style={{ padding: 8 }}>
                <MiniNotif p={p} />
              </div>
              <div style={{ padding: "0 8px 8px" }}>
                <MiniLauncher p={p} />
              </div>
            </div>
          </div>

          {/* ─── Footer: actions ─── */}
          <div style={{
            padding: "8px 14px",
            borderTop: `1px solid ${p.border}`,
            background: p.baseDeep,
            display: "flex", alignItems: "center", gap: 8,
            fontFamily: F.mono, fontSize: 10,
          }}>
            <span
              onClick={resetMode}
              style={{
                padding: "4px 10px",
                border: `1px solid ${p.borderSub}`,
                color: p.text3,
                cursor: "pointer",
                transition: "all 0.1s ease",
              }}
            >
              reset to default
            </span>
            <span
              onClick={exportPalette}
              style={{
                padding: "4px 10px",
                border: `1px solid ${p.borderSub}`,
                color: p.text3,
                cursor: "pointer",
              }}
            >
              export json
            </span>
            <span
              style={{
                padding: "4px 10px",
                border: `1px solid ${p.accent}`,
                color: p.accent,
                cursor: "pointer",
              }}
            >
              regenerate 17 themes
            </span>
            <div style={{ flex: 1 }} />
            <span style={{ color: p.text4, fontSize: 9, letterSpacing: "0.04em" }}>
              changes apply live · palettes.json
            </span>
          </div>
        </div>
      )}

      {/* ─── Bottom hint bar ─── */}
      <div style={{
        height: 24, background: p.baseDeep,
        borderTop: `1px solid ${p.borderSub}`,
        display: "flex", alignItems: "center", justifyContent: "center", gap: 16,
        fontFamily: F.mono, fontSize: 9, color: p.text4, letterSpacing: "0.04em",
      }}>
        {!editorOpen && (
          <span onClick={() => setEditorOpen(true)} style={{ cursor: "pointer", color: p.text3 }}>
            click to open palette editor
          </span>
        )}
        {editorOpen && (
          <>
            <span>click hex to edit</span>
            <span style={{ color: p.borderSub }}>·</span>
            <span>enter to apply</span>
            <span style={{ color: p.borderSub }}>·</span>
            <span>esc to cancel</span>
            <span style={{ color: p.borderSub }}>·</span>
            <span>click backdrop to close</span>
          </>
        )}
      </div>
    </div>
  );
}

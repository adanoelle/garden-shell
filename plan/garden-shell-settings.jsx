import { useState, useEffect, useRef, useCallback } from "react";

// ═══════════════════════════════════════════════════
// Garden Shell — Settings Panel
// Palette editor + keybind remapper in unified surface
// ═══════════════════════════════════════════════════

const F = {
  sans: "'M PLUS 1p', 'Noto Sans JP', system-ui, sans-serif",
  mono: "'IBM Plex Mono', monospace",
};

const BUILT_IN_PALETTES = {
  mokume: {
    name: "mokume", subtitle: "dark — hague blue × warm cream", icon: "◐",
    baseDeep: "#252d3b", base: "#2c3444", baseRaised: "#343d4f", baseHl: "#3d4759",
    border: "#4a5568", borderSub: "#3a4456",
    text1: "#d4c5a9", text2: "#8b9bb0", text3: "#6b7a8d", text4: "#505e70",
    accent: "#c9b88c", urgent: "#c4796b", ok: "#7c9a7c",
  },
  sumi: {
    name: "sumi", subtitle: "neutral — charcoal ink × amber", icon: "●",
    baseDeep: "#222222", base: "#282828", baseRaised: "#313131", baseHl: "#3a3a3a",
    border: "#484848", borderSub: "#383838",
    text1: "#d4c4a0", text2: "#9a9a8e", text3: "#706f68", text4: "#545450",
    accent: "#c2a86a", urgent: "#bf7565", ok: "#7a9470",
  },
  kinu: {
    name: "kinu", subtitle: "light — raw silk × dark walnut", icon: "○",
    baseDeep: "#ddd5c8", base: "#e8e0d4", baseRaised: "#f0e9de", baseHl: "#d8d0c2",
    border: "#c4b9a8", borderSub: "#d0c6b6",
    text1: "#2c2620", text2: "#5c554c", text3: "#8a8278", text4: "#a8a094",
    accent: "#8a7440", urgent: "#a85a48", ok: "#5a7a52",
  },
  yoru: {
    name: "yoru", subtitle: "night — no blue light × deep amber", icon: "◑",
    baseDeep: "#221a14", base: "#281e18", baseRaised: "#302520", baseHl: "#3a2e28",
    border: "#4a3e36", borderSub: "#3c322c",
    text1: "#d4b888", text2: "#a08a6e", text3: "#7a6a58", text4: "#5c5044",
    accent: "#c4a050", urgent: "#c07848", ok: "#7a9060",
  },
};

const ROLE_GROUPS = [
  { group: "surfaces", roles: [
    { key: "baseDeep", label: "base-deep", desc: "bar, code blocks" },
    { key: "base", label: "base", desc: "primary background" },
    { key: "baseRaised", label: "base-raised", desc: "cards, panels" },
    { key: "baseHl", label: "base-hl", desc: "hover, selected" },
  ]},
  { group: "borders", roles: [
    { key: "borderSub", label: "border-sub", desc: "subtle dividers" },
    { key: "border", label: "border", desc: "primary dividers" },
  ]},
  { group: "text", roles: [
    { key: "text4", label: "text-4", desc: "hints, disabled" },
    { key: "text3", label: "text-3", desc: "metadata, labels" },
    { key: "text2", label: "text-2", desc: "body, secondary" },
    { key: "text1", label: "text-1", desc: "headings, primary" },
  ]},
  { group: "semantic", roles: [
    { key: "accent", label: "accent", desc: "interactive" },
    { key: "urgent", label: "urgent", desc: "alerts, remote" },
    { key: "ok", label: "ok", desc: "success, running" },
  ]},
];

const DEFAULT_KEYBINDS = [
  { id: "channel-1", action: "Switch to channel 1", keys: "Super + 1", category: "channels", layer: "hyprland" },
  { id: "channel-2", action: "Switch to channel 2", keys: "Super + 2", category: "channels", layer: "hyprland" },
  { id: "channel-3", action: "Switch to channel 3", keys: "Super + 3", category: "channels", layer: "hyprland" },
  { id: "channel-4", action: "Switch to channel 4", keys: "Super + 4", category: "channels", layer: "hyprland" },
  { id: "channel-5", action: "Switch to channel 5", keys: "Super + 5", category: "channels", layer: "hyprland" },
  { id: "page-prev", action: "Previous page", keys: "Super + H", category: "pages", layer: "hyprland" },
  { id: "page-next", action: "Next page", keys: "Super + L", category: "pages", layer: "hyprland" },
  { id: "page-new", action: "New page in channel", keys: "Super + N", category: "pages", layer: "hyprland" },
  { id: "page-close", action: "Close current page", keys: "Super + Shift + Q", category: "pages", layer: "hyprland" },
  { id: "launcher", action: "Open launcher", keys: "Super + /", category: "shell", layer: "quickshell" },
  { id: "switcher", action: "Channel switcher", keys: "Super + Tab", category: "shell", layer: "quickshell" },
  { id: "settings", action: "Open settings", keys: "Super + ,", category: "shell", layer: "quickshell" },
  { id: "palette-cycle", action: "Cycle palette", keys: "Super + Shift + P", category: "shell", layer: "quickshell" },
  { id: "scratch-garden", action: "Toggle Garden", keys: "Alt + G", category: "scratchpads", layer: "hyprland" },
  { id: "scratch-terminal", action: "Toggle terminal", keys: "Alt + T", category: "scratchpads", layer: "hyprland" },
  { id: "scratch-music", action: "Toggle music", keys: "Alt + M", category: "scratchpads", layer: "hyprland" },
  { id: "win-close", action: "Close window", keys: "Super + Q", category: "windows", layer: "hyprland" },
  { id: "win-float", action: "Toggle float", keys: "Super + V", category: "windows", layer: "hyprland" },
  { id: "win-fullscreen", action: "Toggle fullscreen", keys: "Super + F", category: "windows", layer: "hyprland" },
  { id: "win-left", action: "Focus left", keys: "Super + ←", category: "windows", layer: "hyprland" },
  { id: "win-right", action: "Focus right", keys: "Super + →", category: "windows", layer: "hyprland" },
  { id: "win-up", action: "Focus up", keys: "Super + ↑", category: "windows", layer: "hyprland" },
  { id: "win-down", action: "Focus down", keys: "Super + ↓", category: "windows", layer: "hyprland" },
];

const DITHER = `url("data:image/svg+xml,%3Csvg width='2' height='2' xmlns='http://www.w3.org/2000/svg'%3E%3Crect x='0' y='0' width='1' height='1' fill='%23000' fill-opacity='0.45'/%3E%3Crect x='1' y='1' width='1' height='1' fill='%23000' fill-opacity='0.45'/%3E%3C/svg%3E")`;

function deepClone(o) { return JSON.parse(JSON.stringify(o)); }

// ─── Hex Input ───
function HexInput({ value, onChange, p }) {
  const [draft, setDraft] = useState(value);
  const [focused, setFocused] = useState(false);
  const ref = useRef(null);
  useEffect(() => { setDraft(value); }, [value]);
  const commit = () => {
    setFocused(false);
    if (/^#[0-9a-fA-F]{6}$/.test(draft)) onChange(draft.toLowerCase());
    else setDraft(value);
  };
  return (
    <div style={{
      display: "flex", alignItems: "center",
      border: `1px solid ${focused ? p.border : p.borderSub}`,
      background: focused ? p.baseHl : p.baseDeep,
      transition: "all 0.1s ease", width: 76,
    }}>
      <div style={{ width: 16, height: 16, background: value, flexShrink: 0, margin: "2px 0 2px 3px" }} />
      <input ref={ref} value={draft}
        onChange={e => setDraft(e.target.value)}
        onFocus={() => setFocused(true)} onBlur={commit}
        onKeyDown={e => { if (e.key === "Enter") { commit(); ref.current?.blur(); } if (e.key === "Escape") { setDraft(value); setFocused(false); ref.current?.blur(); } }}
        style={{
          width: "100%", padding: "3px 4px", background: "transparent",
          border: "none", outline: "none", color: p.text2,
          fontSize: 9, fontFamily: F.mono, letterSpacing: "0.03em",
        }}
      />
    </div>
  );
}

// ─── Keybind Capture ───
function KeybindInput({ value, onChange, p, onCapturing }) {
  const [capturing, setCapturing] = useState(false);
  const [display, setDisplay] = useState(value);
  const ref = useRef(null);

  useEffect(() => { setDisplay(value); }, [value]);

  const startCapture = () => {
    setCapturing(true);
    setDisplay("press keys...");
    onCapturing?.(true);
  };

  const handleKey = useCallback((e) => {
    if (!capturing) return;
    e.preventDefault();
    e.stopPropagation();

    if (e.key === "Escape") {
      setCapturing(false);
      setDisplay(value);
      onCapturing?.(false);
      return;
    }

    const parts = [];
    if (e.metaKey || e.key === "Meta") parts.push("Super");
    if (e.ctrlKey && e.key !== "Control") parts.push("Ctrl");
    if (e.altKey && e.key !== "Alt") parts.push("Alt");
    if (e.shiftKey && e.key !== "Shift") parts.push("Shift");

    const keyMap = {
      ArrowLeft: "←", ArrowRight: "→", ArrowUp: "↑", ArrowDown: "↓",
      " ": "Space", "/": "/", ",": ",", ".": ".", "[": "[", "]": "]",
      Tab: "Tab", Enter: "Enter", Backspace: "Backspace", Delete: "Delete",
    };

    const key = e.key;
    if (!["Meta", "Control", "Alt", "Shift"].includes(key)) {
      const mapped = keyMap[key] || (key.length === 1 ? key.toUpperCase() : key);
      parts.push(mapped);

      const result = parts.join(" + ");
      setDisplay(result);
      onChange(result);
      setCapturing(false);
      onCapturing?.(false);
    }
  }, [capturing, value, onChange, onCapturing]);

  useEffect(() => {
    if (capturing) {
      window.addEventListener("keydown", handleKey, true);
      return () => window.removeEventListener("keydown", handleKey, true);
    }
  }, [capturing, handleKey]);

  return (
    <div
      onClick={startCapture}
      style={{
        padding: "4px 8px",
        border: `1px solid ${capturing ? p.accent : p.borderSub}`,
        background: capturing ? p.baseHl : p.baseDeep,
        fontFamily: F.mono, fontSize: 10, color: capturing ? p.accent : p.text2,
        cursor: "pointer", letterSpacing: "0.03em",
        minWidth: 100, textAlign: "center",
        transition: "all 0.12s ease",
        animation: capturing ? "pulse 1.5s ease infinite" : "none",
      }}
    >
      {display}
    </div>
  );
}

// ─── Mini Preview ───
function MiniPreview({ p }) {
  return (
    <div style={{ border: `1px solid ${p.border}`, overflow: "hidden" }}>
      {/* Bar */}
      <div style={{
        height: 24, background: p.baseDeep, borderBottom: `1px solid ${p.borderSub}`,
        display: "flex", alignItems: "center", padding: "0 8px", gap: 4,
        fontFamily: F.sans, fontSize: 9,
      }}>
        <span style={{ fontWeight: 700, color: p.text1 }}>research</span>
        <span style={{ color: p.borderSub }}>:</span>
        <span style={{ color: p.text1, background: p.baseHl, padding: "1px 4px", fontSize: 8 }}>helix</span>
        <span style={{ color: p.text3, fontSize: 8 }}>frontier</span>
        <div style={{ flex: 1 }} />
        <span style={{ fontFamily: F.mono, fontSize: 9, color: p.text1 }}>14:32</span>
      </div>
      {/* Content */}
      <div style={{ background: p.base, padding: 8, fontFamily: F.mono, fontSize: 9, lineHeight: 1.6 }}>
        <span style={{ color: p.accent }}>ada</span><span style={{ color: p.text4 }}>@</span><span style={{ color: p.text2 }}>nix</span><span style={{ color: p.text3 }}> $ </span><span style={{ color: p.text3 }}>cargo build</span><br />
        <span style={{ color: p.ok }}>Finished</span><span style={{ color: p.text3 }}> release [optimized]</span><br />
        <span style={{ color: p.urgent }}>ada</span><span style={{ color: p.text4 }}>@</span><span style={{ color: p.urgent }}>frontier</span><span style={{ color: p.text3 }}> $ </span>
      </div>
      {/* Notification */}
      <div style={{ background: p.baseRaised, borderTop: `1px solid ${p.border}`, padding: "6px 8px" }}>
        <div style={{ display: "flex", justifyContent: "space-between" }}>
          <span style={{ fontSize: 9, fontWeight: 700, color: p.text1 }}>slurm</span>
          <span style={{ fontSize: 7, color: p.text4, fontFamily: F.mono }}>2m</span>
        </div>
        <div style={{ fontSize: 9, color: p.text2, marginTop: 2 }}>Job completed — 4 nodes</div>
      </div>
    </div>
  );
}

// ═══════════════════════════════════════════════════
// SETTINGS PANEL
// ═══════════════════════════════════════════════════

export default function SettingsPanel() {
  const [palettes, setPalettes] = useState(deepClone(BUILT_IN_PALETTES));
  const [activePalette, setActivePalette] = useState("mokume");
  const [keybinds, setKeybinds] = useState(deepClone(DEFAULT_KEYBINDS));
  const [activeSection, setActiveSection] = useState("palette");
  const [open, setOpen] = useState(true);
  const [keybindFilter, setKeybindFilter] = useState("");
  const [isCapturing, setIsCapturing] = useState(false);
  const [hasChanges, setHasChanges] = useState(false);

  const p = palettes[activePalette];

  const updateColor = (key, value) => {
    setPalettes(prev => ({
      ...prev,
      [activePalette]: { ...prev[activePalette], [key]: value },
    }));
    setHasChanges(true);
  };

  const updateKeybind = (id, newKeys) => {
    setKeybinds(prev => prev.map(kb => kb.id === id ? { ...kb, keys: newKeys } : kb));
    setHasChanges(true);
  };

  const resetPalette = () => {
    setPalettes(prev => ({ ...prev, [activePalette]: deepClone(BUILT_IN_PALETTES[activePalette]) }));
    setHasChanges(true);
  };

  const resetKeybinds = () => {
    setKeybinds(deepClone(DEFAULT_KEYBINDS));
    setHasChanges(true);
  };

  const categories = [...new Set(keybinds.map(kb => kb.category))];
  const filteredBinds = keybinds.filter(kb =>
    kb.action.toLowerCase().includes(keybindFilter.toLowerCase()) ||
    kb.keys.toLowerCase().includes(keybindFilter.toLowerCase())
  );

  const sections = [
    { id: "palette", label: "palette" },
    { id: "keybinds", label: "keybinds" },
  ];

  if (!open) {
    return (
      <div style={{
        width: "100%", height: "100vh", background: p.base,
        display: "flex", alignItems: "center", justifyContent: "center",
        fontFamily: F.sans,
      }}>
        <style>{`
          @import url('https://fonts.googleapis.com/css2?family=M+PLUS+1p:wght@300;400;500;700&family=IBM+Plex+Mono:wght@300;400;500&display=swap');
          * { box-sizing: border-box; margin: 0; padding: 0; }
        `}</style>
        <div onClick={() => setOpen(true)} style={{
          padding: "10px 20px", border: `1px solid ${p.border}`,
          color: p.text2, fontSize: 12, cursor: "pointer",
          fontFamily: F.mono,
        }}>
          super + , to open settings
        </div>
      </div>
    );
  }

  return (
    <div style={{
      width: "100%", height: "100vh", background: p.base,
      display: "flex", flexDirection: "column", overflow: "hidden",
      position: "relative", fontFamily: F.sans,
    }}>
      <style>{`
        @import url('https://fonts.googleapis.com/css2?family=M+PLUS+1p:wght@300;400;500;700&family=IBM+Plex+Mono:wght@300;400;500&display=swap');
        * { box-sizing: border-box; margin: 0; padding: 0; }
        ::placeholder { color: ${p.text4}; }
        ::-webkit-scrollbar { width: 3px; }
        ::-webkit-scrollbar-track { background: transparent; }
        ::-webkit-scrollbar-thumb { background: ${p.border}; }
        @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.6; } }
      `}</style>

      {/* Dithered backdrop */}
      <div onClick={() => setOpen(false)} style={{
        position: "absolute", inset: 0, zIndex: 0,
        backgroundImage: DITHER, backgroundRepeat: "repeat",
        imageRendering: "pixelated",
      }} />

      {/* Settings window */}
      <div style={{
        position: "relative", zIndex: 1,
        width: 680, maxHeight: "90vh",
        margin: "32px auto 0",
        background: p.base,
        border: `1px solid ${p.border}`,
        display: "flex", flexDirection: "column",
        overflow: "hidden",
      }}>
        {/* ─── Title bar ─── */}
        <div style={{
          height: 32, padding: "0 14px",
          background: p.baseDeep,
          borderBottom: `1px solid ${p.borderSub}`,
          display: "flex", alignItems: "center", justifyContent: "space-between",
          fontFamily: F.mono, fontSize: 10, color: p.text3,
          letterSpacing: "0.06em", userSelect: "none", flexShrink: 0,
        }}>
          <span>garden — settings</span>
          <div style={{ display: "flex", alignItems: "center", gap: 10 }}>
            {hasChanges && (
              <span style={{ fontSize: 8, color: p.accent, letterSpacing: "0.04em" }}>unsaved changes</span>
            )}
            <span onClick={() => setOpen(false)} style={{ cursor: "pointer", color: p.text4, fontSize: 13 }}>×</span>
          </div>
        </div>

        {/* ─── Section tabs ─── */}
        <div style={{
          display: "flex", borderBottom: `1px solid ${p.border}`,
          background: p.baseDeep, flexShrink: 0,
        }}>
          {sections.map(sec => (
            <div key={sec.id} onClick={() => setActiveSection(sec.id)} style={{
              padding: "10px 20px", cursor: "pointer",
              fontSize: 11, fontWeight: activeSection === sec.id ? 700 : 400,
              color: activeSection === sec.id ? p.text1 : p.text3,
              background: activeSection === sec.id ? p.base : "transparent",
              borderBottom: activeSection === sec.id ? `2px solid ${p.text1}` : "2px solid transparent",
              borderRight: `1px solid ${p.borderSub}`,
              fontFamily: F.sans, letterSpacing: "0.03em",
              transition: "all 0.12s ease",
            }}>
              {sec.label}
            </div>
          ))}
          <div style={{ flex: 1 }} />
        </div>

        {/* ─── Content area ─── */}
        <div style={{ flex: 1, overflow: "auto" }}>

          {/* ════════ PALETTE SECTION ════════ */}
          {activeSection === "palette" && (
            <div style={{ display: "flex", flexDirection: "column" }}>
              {/* Palette mode selector */}
              <div style={{
                display: "flex", borderBottom: `1px solid ${p.borderSub}`,
                padding: "0 14px", gap: 0,
              }}>
                {Object.entries(palettes).map(([key, pal]) => {
                  const isActive = key === activePalette;
                  return (
                    <div key={key} onClick={() => setActivePalette(key)} style={{
                      padding: "10px 14px", cursor: "pointer",
                      display: "flex", alignItems: "center", gap: 6,
                      borderBottom: isActive ? `2px solid ${pal.accent || pal.text1}` : "2px solid transparent",
                      transition: "all 0.12s ease",
                    }}>
                      <span style={{ fontSize: 14, color: isActive ? pal.text1 : p.text4 }}>{pal.icon}</span>
                      <div>
                        <div style={{ fontSize: 11, fontWeight: isActive ? 700 : 400, color: isActive ? p.text1 : p.text3 }}>{pal.name}</div>
                        <div style={{ fontSize: 8, color: p.text4 }}>{pal.subtitle}</div>
                      </div>
                    </div>
                  );
                })}
              </div>

              {/* Two-column: inputs + preview */}
              <div style={{ display: "flex" }}>
                {/* Color inputs */}
                <div style={{ flex: 1, borderRight: `1px solid ${p.border}`, padding: "4px 0" }}>
                  {ROLE_GROUPS.map(group => (
                    <div key={group.group}>
                      <div style={{
                        padding: "8px 14px 4px", fontSize: 9, fontWeight: 600,
                        color: p.text3, fontFamily: F.mono, letterSpacing: "0.08em",
                        textTransform: "uppercase",
                        borderTop: `1px solid ${p.borderSub}`, marginTop: 2,
                      }}>
                        {group.group}
                      </div>
                      <div style={{ padding: "0 14px" }}>
                        {group.roles.map(role => (
                          <div key={role.key} style={{
                            display: "flex", alignItems: "center", gap: 8,
                            padding: "3px 0",
                          }}>
                            <div style={{ width: 68, flexShrink: 0 }}>
                              <span style={{ fontSize: 10, fontWeight: 600, color: p.text1, fontFamily: F.mono }}>{role.label}</span>
                            </div>
                            <HexInput value={p[role.key]} onChange={v => updateColor(role.key, v)} p={p} />
                            <span style={{ fontSize: 8, color: p.text4 }}>{role.desc}</span>
                          </div>
                        ))}
                      </div>
                    </div>
                  ))}
                  {/* Reset button */}
                  <div style={{ padding: "10px 14px", borderTop: `1px solid ${p.borderSub}`, marginTop: 4 }}>
                    <span onClick={resetPalette} style={{
                      padding: "4px 10px", border: `1px solid ${p.borderSub}`,
                      fontSize: 10, color: p.text3, fontFamily: F.mono, cursor: "pointer",
                    }}>
                      reset {activePalette} to defaults
                    </span>
                  </div>
                </div>

                {/* Live preview */}
                <div style={{ width: 240, padding: 12, display: "flex", flexDirection: "column", gap: 8 }}>
                  <div style={{ fontSize: 9, fontWeight: 600, color: p.text3, fontFamily: F.mono, letterSpacing: "0.08em", textTransform: "uppercase" }}>
                    live preview
                  </div>
                  <MiniPreview p={p} />
                  {/* Swatch strip */}
                  <div style={{ display: "flex", gap: 2, flexWrap: "wrap" }}>
                    {["baseDeep", "base", "baseRaised", "baseHl", "borderSub", "border", "text4", "text3", "text2", "text1", "accent", "urgent", "ok"].map(k => (
                      <div key={k} style={{ width: 14, height: 14, background: p[k], border: `1px solid ${p.border}` }} />
                    ))}
                  </div>
                </div>
              </div>
            </div>
          )}

          {/* ════════ KEYBINDS SECTION ════════ */}
          {activeSection === "keybinds" && (
            <div>
              {/* Search */}
              <div style={{
                padding: "8px 14px", borderBottom: `1px solid ${p.border}`,
                display: "flex", alignItems: "center", gap: 8,
              }}>
                <span style={{ color: p.text4, fontFamily: F.mono, fontSize: 11 }}>/</span>
                <input
                  value={keybindFilter}
                  onChange={e => setKeybindFilter(e.target.value)}
                  placeholder="filter keybinds..."
                  style={{
                    flex: 1, background: "transparent", border: "none", outline: "none",
                    color: p.text1, fontSize: 12, fontFamily: F.sans,
                  }}
                />
                {keybindFilter && (
                  <span onClick={() => setKeybindFilter("")} style={{
                    cursor: "pointer", color: p.text4, fontSize: 10, fontFamily: F.mono,
                  }}>clear</span>
                )}
              </div>

              {/* Keybind list by category */}
              {categories.map(cat => {
                const binds = filteredBinds.filter(kb => kb.category === cat);
                if (binds.length === 0) return null;
                return (
                  <div key={cat}>
                    <div style={{
                      padding: "8px 14px 4px", fontSize: 9, fontWeight: 600,
                      color: p.text3, fontFamily: F.mono, letterSpacing: "0.08em",
                      textTransform: "uppercase",
                      borderTop: `1px solid ${p.borderSub}`, marginTop: 2,
                    }}>
                      {cat}
                    </div>
                    {binds.map(kb => (
                      <div key={kb.id} style={{
                        display: "flex", alignItems: "center", gap: 8,
                        padding: "6px 14px",
                        borderBottom: `1px solid ${p.borderSub}`,
                      }}>
                        {/* Action name */}
                        <div style={{ flex: 1, minWidth: 0 }}>
                          <div style={{ fontSize: 11, color: p.text1, fontWeight: 500 }}>{kb.action}</div>
                        </div>
                        {/* Layer badge */}
                        <span style={{
                          fontSize: 8, fontFamily: F.mono, color: p.text4,
                          padding: "1px 5px", border: `1px solid ${p.borderSub}`,
                          letterSpacing: "0.04em", flexShrink: 0,
                        }}>
                          {kb.layer}
                        </span>
                        {/* Keybind input */}
                        <KeybindInput
                          value={kb.keys}
                          onChange={v => updateKeybind(kb.id, v)}
                          p={p}
                          onCapturing={setIsCapturing}
                        />
                      </div>
                    ))}
                  </div>
                );
              })}

              {/* Reset + info */}
              <div style={{
                padding: "10px 14px", borderTop: `1px solid ${p.borderSub}`, marginTop: 4,
                display: "flex", alignItems: "center", gap: 12,
              }}>
                <span onClick={resetKeybinds} style={{
                  padding: "4px 10px", border: `1px solid ${p.borderSub}`,
                  fontSize: 10, color: p.text3, fontFamily: F.mono, cursor: "pointer",
                }}>
                  reset all keybinds
                </span>
                <span style={{ fontSize: 9, color: p.text4, fontFamily: F.mono }}>
                  click a keybind to remap · esc to cancel
                </span>
              </div>

              {/* Conflict detection info */}
              <div style={{
                padding: "8px 14px", borderTop: `1px solid ${p.borderSub}`,
                fontSize: 9, color: p.text4, fontFamily: F.mono, lineHeight: 1.6,
                letterSpacing: "0.03em",
              }}>
                <span style={{ color: p.text3 }}>note:</span> keybinds marked <span style={{
                  padding: "0 3px", border: `1px solid ${p.borderSub}`, fontSize: 8,
                }}>hyprland</span> require compositor reload to take effect.
                keybinds marked <span style={{
                  padding: "0 3px", border: `1px solid ${p.borderSub}`, fontSize: 8,
                }}>quickshell</span> apply immediately.
              </div>
            </div>
          )}
        </div>

        {/* ─── Footer ─── */}
        <div style={{
          padding: "8px 14px", borderTop: `1px solid ${p.border}`,
          background: p.baseDeep, display: "flex", alignItems: "center", gap: 8,
          fontFamily: F.mono, fontSize: 10, flexShrink: 0,
        }}>
          <span onClick={() => {
            setHasChanges(false);
            // In real impl: write palettes.json + keybinds.json + hyprctl reload
          }} style={{
            padding: "4px 12px",
            border: `1px solid ${hasChanges ? p.accent : p.borderSub}`,
            color: hasChanges ? p.accent : p.text4,
            cursor: hasChanges ? "pointer" : "default",
            transition: "all 0.12s ease",
          }}>
            save
          </span>
          <span onClick={() => {
            setPalettes(deepClone(BUILT_IN_PALETTES));
            setKeybinds(deepClone(DEFAULT_KEYBINDS));
            setHasChanges(false);
          }} style={{
            padding: "4px 10px", border: `1px solid ${p.borderSub}`,
            color: p.text3, cursor: "pointer",
          }}>
            discard changes
          </span>
          <div style={{ flex: 1 }} />
          <span style={{ color: p.text4, fontSize: 9 }}>
            ~/.config/garden/settings.json
          </span>
        </div>
      </div>
    </div>
  );
}

# Garden — Day One Jam Session

> From fresh NixOS install to living in the Garden environment.
> Practical steps with checkpoints — each stage gives you something usable.

**Machine:** Minisforum MS-A2 (Ryzen 9 9955HX, AMD iGPU)
**Starting state:** Fresh NixOS install with some desktop, no fern repo

---

## How This Relates to the Other Planning Docs

This jam session is a compressed, hands-on version of the build plan's
Phase 0 + Phase 1.1. It deliberately skips the dendritic migration
(Pre-Phase / Session A1) to get you productive today.

```
JAM SESSION              BUILD PLAN (09)           SESSION PLAN (10)
───────────              ──────────────            ─────────────────
(skipped)                Pre-Phase: Dendritic      Session A1
Stage 1: Clone + host    Phase 0.1: NixOS base     Session A2
Stage 2: Niri            Phase 0.2: Niri config    Session A3
Stage 3: Kitty/Fish/Kak  Phase 0.3: Terminal stack  Session A4
Stage 4: Toolkit         Phase 0.4: Toolkit        Session A5
Stage 5: palettes.json   Phase 1.1: Palette file   Session B3 (partial)
Stage 6: QS skeleton     Phase 2.1: Shell skeleton  Session B2-B4 (start)
```

### What This Creates (Technical Debt)

This session creates two kinds of intentional shortcuts:

1. **No dendritic migration.** The garden host is wired into fern's
   existing numbered flake-parts files (40-hosts.nix, etc.) rather
   than as standalone dendritic modules. This is cheap to fix later —
   the migration is a pure structural refactor.

2. **Hand-placed config files.** Kitty, Fish, Kakoune, and tool
   configs are placed directly in `~/.config/` rather than managed
   by Home Manager modules. These work immediately but aren't
   reproducible until migrated to proper NixOS/home-manager modules.

### Cleanup Steps (After the Jam Session)

These should happen in the days following, either manually or via
Claude Code sessions from `10-session-plan.md`:

1. **Session A1: Dendritic migration** — Convert fern to import-tree
   pattern. The garden host modules move from `flake.parts/40-hosts.nix`
   to standalone modules under `modules/`.

2. **Migrate hand-placed configs to home-manager modules:**
   - `~/.config/kitty/kitty.conf` → `modules/kitty.nix`
   - `~/.config/fish/functions/fish_prompt.fish` → `modules/fish.nix`
   - `~/.config/fish/conf.d/*.fish` → `modules/fish.nix`
   - `~/.config/kak/colors/garden.kak` → `modules/kakoune.nix`
   - `~/.config/kak/kakrc` → `modules/kakoune.nix`
   - `~/.config/niri/config.kdl` → `modules/niri.nix`
   - `~/.config/garden/palettes.json` → managed by palette module
   - `~/.config/git/config` → `modules/git.nix` (may already exist)

3. **Session B1: Dendritic migration of fern-shell** — Convert the
   Quickshell repo to the same pattern.

4. **Session B2: Replace skeleton bar** — The minimal `shell.qml`
   from Stage 6 gets replaced by the real NiriAdapter + compositor
   abstraction layer.

Once cleanup is done, `nixos-rebuild switch` reproduces the entire
environment from scratch — every config file, every tool, every color.
The hand-placed files from this jam session are the bootstrap;
the modules are the permanent home.

---

## Stage 1: Clone + Generate Hardware Config (30 min)

### Get the basics

```bash
# You're on the fresh NixOS install with whatever desktop it has.
# Open a terminal.

# Install git if not already there
nix-shell -p git

# Clone fern
mkdir -p ~/src/nix
cd ~/src/nix
git clone git@github.com:adanoelle/fern.git
cd fern

# Generate hardware config for the MS-A2
# This captures your disk layout, CPU, GPU, etc.
sudo nixos-generate-config --show-hardware-config > /tmp/garden-hardware.nix

# Look at it — this is your machine's identity
cat /tmp/garden-hardware.nix
```

### Create the garden host

For now, work within the existing flake-parts structure (dendritic
migration can happen later). Create the garden host:

```bash
mkdir -p hosts/garden
cp /tmp/garden-hardware.nix hosts/garden/hardware.nix
```

Create `hosts/garden/configuration.nix` — start minimal, just enough
to boot into a usable system:

```nix
# hosts/garden/configuration.nix
{ config, pkgs, lib, ... }:
{
  imports = [
    ./hardware.nix
  ];

  networking.hostName = "garden";
  
  # AMD GPU — open source driver, just works
  hardware.graphics.enable = true;
  
  # Basic system
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;
  
  # Your user
  users.users.ada = {
    isNormalUser = true;
    extraGroups = [ "wheel" "video" "audio" "networkmanager" ];
    shell = pkgs.fish;
  };

  # Enable flakes
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  
  # Networking
  networking.networkmanager.enable = true;
  
  # Audio
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
  };
  
  # Minimal packages to bootstrap with
  environment.systemPackages = with pkgs; [
    git
    curl
    wget
    vim   # fallback editor until kakoune is configured
  ];

  system.stateVersion = "25.05"; # or whatever your installer used
}
```

### Register the host in flake-parts

Edit `flake.parts/40-hosts.nix` to add the garden host alongside fern.
The exact change depends on how this file is structured, but it will
be something like adding a new nixosConfigurations entry.

### First build

```bash
# Check it evaluates
nix flake check

# Test build (doesn't switch yet)
sudo nixos-rebuild test --flake .#garden

# If it works, switch
sudo nixos-rebuild switch --flake .#garden
```

**✓ Checkpoint:** You can reboot into NixOS as the `garden` host.
You have a working system with your user account.

---

## Stage 2: Niri Compositor (1-2 hours)

### Add niri flake input

Edit `flake.nix` to add the niri input:

```nix
niri = {
  url = "github:sodiboo/niri-flake";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

### Create niri module

You can either add this to your existing module structure or directly
in the garden host config. For speed, add it to configuration.nix
first — extract to a module later.

Add to `hosts/garden/configuration.nix`:

```nix
{ config, pkgs, lib, inputs, ... }:
{
  imports = [
    ./hardware.nix
    inputs.niri.nixosModules.niri  # add niri module
  ];

  # Enable Niri
  programs.niri.enable = true;
  
  # Make Niri available as a session
  services.xserver.enable = true;  # needed for display manager
  services.displayManager.sddm.enable = true;  # or gdm
  services.displayManager.sddm.wayland.enable = true;

  # XWayland for X11 apps (Clip Studio Paint etc)
  programs.xwayland.enable = true;

  # ... rest of config
}
```

### Create niri config

Create `~/.config/niri/config.kdl` with the Garden Shell spec:

```kdl
// Garden Shell — Niri configuration
// Five named workspaces (channels)

input {
    keyboard {
        xkb {
            layout "us"
        }
    }
    
    touchpad {
        tap
        natural-scroll
    }
}

// Named workspaces — our channels
workspace "studio"
workspace "research"
workspace "writing"
workspace "music"
workspace "system"

// Layout
layout {
    gaps 2
    
    border {
        width 1
        active-color "#4a5568"
        inactive-color "#3a4456"
    }
    
    center-focused-column "best-effort"
    
    // Default column width
    default-column-width { proportion 0.5; }
}

// Animations — calm, no bounce
animations {
    workspace-switch {
        spring damping-ratio=1.0 stiffness=800 epsilon=0.0001
    }
    horizontal-view-movement {
        spring damping-ratio=1.0 stiffness=1000 epsilon=0.0001
    }
    window-open {
        duration-ms 150
        curve "ease-out-expo"
    }
    window-close {
        duration-ms 100
        curve "ease-in-cubic"
    }
}

// Keybinds
binds {
    // Channel switching (Super+1-5)
    Mod+1 { focus-workspace "studio"; }
    Mod+2 { focus-workspace "research"; }
    Mod+3 { focus-workspace "writing"; }
    Mod+4 { focus-workspace "music"; }
    Mod+5 { focus-workspace "system"; }
    
    // Column navigation (scroll)
    Mod+H { focus-column-left; }
    Mod+L { focus-column-right; }
    
    // Move columns
    Mod+Shift+H { move-column-left; }
    Mod+Shift+L { move-column-right; }
    
    // Move window to workspace
    Mod+Shift+1 { move-window-to-workspace "studio"; }
    Mod+Shift+2 { move-window-to-workspace "research"; }
    Mod+Shift+3 { move-window-to-workspace "writing"; }
    Mod+Shift+4 { move-window-to-workspace "music"; }
    Mod+Shift+5 { move-window-to-workspace "system"; }
    
    // Window management
    Mod+Return { spawn "kitty"; }
    Mod+Shift+Q { close-window; }
    Mod+F { maximize-column; }
    Mod+Shift+F { fullscreen-window; }
    
    // Column width
    Mod+Minus { set-column-width "-10%"; }
    Mod+Equal { set-column-width "+10%"; }
    
    // Overview
    Mod+A { toggle-overview; }
    
    // Focus up/down within stacked column
    Mod+J { focus-window-down; }
    Mod+K { focus-window-up; }
    
    // Screenshot
    Mod+S { screenshot; }
    Mod+Shift+S { screenshot-screen; }
    
    // Exit
    Mod+Shift+E { quit; }
}

// Window rules — column width presets
window-rule {
    match app-id="kitty"
    default-column-width { proportion 0.4; }
}

window-rule {
    match app-id="obsidian"
    default-column-width { proportion 0.6; }
}

window-rule {
    match app-id="org.pwmt.zathura"
    default-column-width { proportion 0.5; }
}

// Startup
spawn-at-startup "kitty"
```

### Rebuild and test

```bash
sudo nixos-rebuild switch --flake .#garden
# Log out of current desktop, select Niri session, log in
```

**✓ Checkpoint:** You're in Niri with five workspaces. Super+Return
opens a terminal. Super+1-5 switches channels. Super+H/L scrolls columns.
You're living in a scrollable-tiling compositor.

---

## Stage 3: Kitty + Fish + ✧ Prompt (1-2 hours)

### Add Kitty, Fish, Fonts to NixOS config

Add to `hosts/garden/configuration.nix` (or create home-manager modules):

```nix
  # Fonts
  fonts.packages = with pkgs; [
    m-plus-1p
    ibm-plex
  ];

  # Fish as default shell
  programs.fish.enable = true;
  
  environment.systemPackages = with pkgs; [
    kitty
    fish
    kakoune
    kak-lsp
    helix        # backup editor
    
    # Essentials for bootstrapping
    git
    curl
    wget
    jq
  ];
```

### Kitty config

Create `~/.config/kitty/kitty.conf`:

```conf
# Garden palette — mokume
background #2c3444
foreground #d4c5a9
cursor     #d4c5a9
cursor_shape beam
selection_background #3d4759
selection_foreground #d4c5a9

# ANSI 16
color0  #252d3b
color1  #c4796b
color2  #7c9a7c
color3  #c9b88c
color4  #6b7a8d
color5  #8b7a8d
color6  #6b8a8d
color7  #8b9bb0
color8  #505e70
color9  #c4796b
color10 #7c9a7c
color11 #c9b88c
color12 #8b9bb0
color13 #9b8a9d
color14 #7b9a9d
color15 #d4c5a9

# Typography
font_family      IBM Plex Mono
font_size        13.0
modify_font cell_height 120%

# Window
hide_window_decorations yes
window_padding_width 12 16 12 16

# Behavior
confirm_os_window_close 0
copy_on_select clipboard
mouse_hide_wait 3.0
```

### Fish config with ✧ prompt

Create `~/.config/fish/functions/fish_prompt.fish`:

```fish
function fish_prompt
    set -l last_status $status
    set -l cwd (prompt_pwd --full-length-dirs=2)
    
    # Git info
    set -l git_info ""
    if command git rev-parse --is-inside-work-tree 2>/dev/null >/dev/null
        set -l branch (command git branch --show-current 2>/dev/null)
        set -l dirty (command git status --porcelain 2>/dev/null | count)
        if test -n "$branch"
            set git_info " $branch"
            if test $dirty -gt 0
                set git_info "$git_info·$dirty"
            end
        end
    end
    
    # Host (only when remote)
    set -l host_info ""
    if set -q SSH_CONNECTION
        set host_info (prompt_hostname)
    end
    
    # Garden channel (from Niri)
    set -l garden_ctx ""
    if command -q niri
        set -l ws (niri msg -j focused-output 2>/dev/null | jq -r '.workspaces[]? | select(.is_focused) | .name // empty' 2>/dev/null)
        if test -n "$ws"
            set garden_ctx $ws
        end
    end
    
    # ─── Line 1: information ───
    set_color 6b7a8d  # text-3
    echo -n $cwd
    if test -n "$git_info"
        set_color 505e70  # text-4
        echo -n $git_info
    end
    
    # Right side
    set -l right_parts
    if test -n "$host_info"
        set -a right_parts $host_info
    end
    if test -n "$garden_ctx"
        set -a right_parts $garden_ctx
    end
    
    if test (count $right_parts) -gt 0
        set -l right_str (string join " " $right_parts)
        set -l left_len (string length -- "$cwd$git_info")
        set -l right_len (string length -- $right_str)
        set -l cols (tput cols)
        set -l padding (math $cols - $left_len - $right_len - 1)
        if test $padding -gt 0
            printf '%*s' $padding ''
        end
        if test -n "$host_info"
            set_color c4796b  # urgent
            echo -n $host_info
            echo -n " "
        end
        set_color 505e70  # text-4
        echo -n $garden_ctx
    end
    
    echo  # newline
    
    # ─── Line 2: ✧ ───
    if test $last_status -ne 0
        set_color c4796b  # urgent
    else
        set_color d4c5a9  # text-1
    end
    echo -n '✧ '
    set_color normal
end
```

Create `~/.config/fish/conf.d/garden-theme.fish`:

```fish
# Garden palette — mokume
set -U fish_color_command    8b9bb0   # text-2
set -U fish_color_param      6b7a8d   # text-3
set -U fish_color_quote      c9b88c   # accent
set -U fish_color_string     7c9a7c   # ok
set -U fish_color_comment    505e70   # text-4
set -U fish_color_operator   6b7a8d   # text-3
set -U fish_color_redirection 6b7a8d  # text-3
set -U fish_color_end        6b7a8d   # text-3
set -U fish_color_escape     c9b88c   # accent
set -U fish_color_error      c4796b   # urgent

set -U fish_color_autosuggestion  505e70   # text-4
set -U fish_color_selection       3d4759   # base-hl
set -U fish_color_search_match    3d4759   # base-hl
set -U fish_color_cancel          c4796b   # urgent

set -U fish_pager_color_prefix      d4c5a9  # text-1
set -U fish_pager_color_completion  8b9bb0  # text-2
set -U fish_pager_color_description 6b7a8d  # text-3
set -U fish_pager_color_selected_background 3d4759  # base-hl
```

### Kakoune colorscheme

Create `~/.config/kak/colors/garden.kak`:

```kak
# Garden palette — mokume

face global Default            rgb:8b9bb0,rgb:2c3444
face global StatusLine         rgb:6b7a8d,rgb:252d3b
face global StatusLineMode     rgb:d4c5a9,rgb:252d3b
face global StatusLineInfo     rgb:505e70,rgb:252d3b
face global StatusLineValue    rgb:c9b88c,rgb:252d3b
face global StatusCursor       rgb:252d3b,rgb:d4c5a9
face global Prompt             rgb:c9b88c,rgb:252d3b
face global MenuForeground     rgb:d4c5a9,rgb:3d4759
face global MenuBackground     rgb:8b9bb0,rgb:343d4f
face global Information        rgb:8b9bb0,rgb:343d4f
face global Error              rgb:c4796b,rgb:2c3444

face global PrimarySelection   default,rgb:3d4759+g
face global SecondarySelection default,rgb:343d4f+g
face global PrimaryCursor      rgb:252d3b,rgb:d4c5a9
face global SecondaryCursor    rgb:252d3b,rgb:8b9bb0

face global LineNumbers        rgb:505e70
face global LineNumberCursor   rgb:6b7a8d
face global LineNumbersWrapped rgb:3a4456

face global MatchingChar       rgb:c9b88c+b
face global Whitespace         rgb:3a4456
face global BufferPadding      rgb:3a4456

face global value              rgb:c9b88c
face global type               rgb:8b9bb0
face global variable           rgb:d4c5a9
face global module             rgb:8b9bb0
face global function           rgb:d4c5a9
face global string             rgb:7c9a7c
face global keyword            rgb:6b7a8d
face global operator           rgb:6b7a8d
face global attribute          rgb:c9b88c
face global comment            rgb:505e70+i
face global documentation      rgb:6b7a8d
face global meta               rgb:c9b88c
face global builtin            rgb:8b9bb0+b
```

Create `~/.config/kak/kakrc`:

```kak
# Garden Kakoune config

# Theme
colorscheme garden

# Line numbers
add-highlighter global/ number-lines -relative -hlcursor

# Soft wrap for prose
add-highlighter global/ wrap -word -indent

# Tab = 4 spaces
set-option global tabstop 4
set-option global indentwidth 4

# Show matching brackets
add-highlighter global/ show-matching

# Clipboard integration (wayland)
hook global NormalKey y|d|c %{ nop %sh{
    printf '%s' "$kak_main_reg_dquote" | wl-copy
}}
```

### Rebuild and switch

```bash
sudo nixos-rebuild switch --flake .#garden
# Open a new Kitty terminal — you should see the mokume palette
# and the ✧ prompt
```

**✓ Checkpoint:** You're in Niri, opening Kitty terminals with
warm cream ✧ on dark blue-slate. Fish autosuggests in ghost text.
Kakoune shows code in Garden colors. The right-aligned channel
name appears faintly when Niri workspace detection works.

---

## Stage 4: Terminal Toolkit (1 hour)

### Add tools to NixOS config

```nix
  environment.systemPackages = with pkgs; [
    # ... existing packages ...
    
    # Essential toolkit
    ripgrep
    fd
    bat
    delta
    zoxide
    jq
    yazi
    
    # Recommended
    lazygit
    btop
    fzf
    glow
    xh
    jless
    chafa
    
    # Clipboard for Wayland
    wl-clipboard
  ];
```

### Fish tool integration

Create `~/.config/fish/conf.d/garden-tools.fish`:

```fish
# Yazi: cd to directory on exit
function y
    set -l tmp (mktemp)
    yazi --cwd-file=$tmp $argv
    set -l cwd (cat $tmp)
    if test -n "$cwd" -a "$cwd" != "$PWD"
        cd $cwd
    end
    rm -f $tmp
end

# Bat as default pager for man pages
set -gx MANPAGER "sh -c 'col -bx | bat -l man -p'"
set -gx BAT_THEME "ansi"  # uses terminal colors until we have garden theme

# fzf with Garden colors (mokume)
set -gx FZF_DEFAULT_OPTS "\
    --color=bg+:#3d4759,bg:#2c3444,spinner:#c9b88c,hl:#c4796b \
    --color=fg:#8b9bb0,header:#6b7a8d,info:#6b7a8d,pointer:#d4c5a9 \
    --color=marker:#c9b88c,fg+:#d4c5a9,prompt:#c9b88c,hl+:#c4796b \
    --color=border:#4a5568"

# Delta as git pager
set -gx GIT_PAGER "delta"

# Zoxide
zoxide init fish | source

# Default editor
set -gx EDITOR "kak"
set -gx VISUAL "kak"
```

### Git config with delta

Create or update `~/.config/git/config`:

```gitconfig
[core]
    pager = delta

[interactive]
    diffFilter = delta --color-only

[delta]
    line-numbers = true
    side-by-side = false
    syntax-theme = ansi  # uses terminal ANSI colors

[user]
    name = Ada Noelle
    email = your@email.com
```

### Rebuild

```bash
sudo nixos-rebuild switch --flake .#garden
```

**✓ Checkpoint:** Full terminal toolkit working. `bat` syntax
highlights files in Garden colors. `git diff` shows delta output.
`z` jumps between directories. `y` opens yazi with image previews.
fzf searches in Garden palette. You're fully productive in the terminal.

---

## Stage 5: palettes.json + Niri Polish (1 hour)

### Create the palette source of truth

```bash
mkdir -p ~/.config/garden
```

Create `~/.config/garden/palettes.json`:

```json
{
  "active": "mokume",
  "palettes": {
    "mokume": {
      "name": "mokume",
      "subtitle": "dark — hague blue × warm cream",
      "icon": "◐",
      "builtin": true,
      "colors": {
        "base-deep": "#252d3b",
        "base": "#2c3444",
        "base-raised": "#343d4f",
        "base-hl": "#3d4759",
        "border-sub": "#3a4456",
        "border": "#4a5568",
        "text-4": "#505e70",
        "text-3": "#6b7a8d",
        "text-2": "#8b9bb0",
        "text-1": "#d4c5a9",
        "accent": "#c9b88c",
        "urgent": "#c4796b",
        "ok": "#7c9a7c"
      }
    },
    "sumi": {
      "name": "sumi",
      "subtitle": "neutral — charcoal ink × amber",
      "icon": "●",
      "builtin": true,
      "colors": {
        "base-deep": "#222222",
        "base": "#282828",
        "base-raised": "#313131",
        "base-hl": "#3a3a3a",
        "border-sub": "#383838",
        "border": "#484848",
        "text-4": "#545450",
        "text-3": "#706f68",
        "text-2": "#9a9a8e",
        "text-1": "#d4c4a0",
        "accent": "#c2a86a",
        "urgent": "#bf7565",
        "ok": "#7a9470"
      }
    },
    "kinu": {
      "name": "kinu",
      "subtitle": "light — raw silk × dark walnut",
      "icon": "○",
      "builtin": true,
      "colors": {
        "base-deep": "#ddd5c8",
        "base": "#e8e0d4",
        "base-raised": "#f0e9de",
        "base-hl": "#d8d0c2",
        "border-sub": "#d0c6b6",
        "border": "#c4b9a8",
        "text-4": "#a8a094",
        "text-3": "#8a8278",
        "text-2": "#5c554c",
        "text-1": "#2c2620",
        "accent": "#8a7440",
        "urgent": "#a85a48",
        "ok": "#5a7a52"
      }
    },
    "yoru": {
      "name": "yoru",
      "subtitle": "night — no blue light × deep amber",
      "icon": "◑",
      "builtin": true,
      "colors": {
        "base-deep": "#221a14",
        "base": "#281e18",
        "base-raised": "#302520",
        "base-hl": "#3a2e28",
        "border-sub": "#3c322c",
        "border": "#4a3e36",
        "text-4": "#5c5044",
        "text-3": "#7a6a58",
        "text-2": "#a08a6e",
        "text-1": "#d4b888",
        "accent": "#c4a050",
        "urgent": "#c07848",
        "ok": "#7a9060"
      }
    }
  }
}
```

### Polish Niri window rules

Update `~/.config/niri/config.kdl` with host-tier border colors:

```kdl
// Host tier borders
window-rule {
    match title=r#"frontier|andes|summit"#
    border { active-color "#c4796b"; }
}
window-rule {
    match title=r#"dgx-"#
    border { active-color "#c9b88c"; }
}
window-rule {
    match title=r#"homelab"#
    border { active-color "#7c9a7c"; }
}
```

**✓ Checkpoint:** palettes.json exists as the single source of truth.
Niri borders respond to SSH connections. The foundation is complete.

---

## Stage 6: Quickshell Skeleton (2-3 hours)

### Add Quickshell to NixOS config

Add the quickshell flake input and install it:

```nix
# In flake.nix inputs:
quickshell = {
  url = "github:outfoxxed/quickshell";
  inputs.nixpkgs.follows = "nixpkgs";
};
```

```nix
# In configuration.nix:
environment.systemPackages = with pkgs; [
  # ... existing ...
  inputs.quickshell.packages.${pkgs.system}.default
];
```

### Clone fern-shell and start building

```bash
cd ~/src
git clone git@github.com:adanoelle/fern-shell.git
cd fern-shell
```

At this point, you'd start a Claude Code session with the fern-shell
repo. Give the agent:
- The design docs (especially 02-shell-design.md, 07-niri-migration.md)
- The palettes.json you just created
- Session B2 from 10-session-plan.md (compositor abstraction)

The agent builds the NiriAdapter, then you manually test with:

```bash
# Live reload — see changes immediately
quickshell -p fern/shell.qml
```

### Minimum viable bar

Even without a Claude Code session, you can create a basic bar
to prove the pipeline works:

Create `~/.config/quickshell/garden/shell.qml`:

```qml
import Quickshell
import Quickshell.Wayland
import QtQuick

ShellRoot {
    Variants {
        model: Quickshell.screens
        
        PanelWindow {
            property var modelData
            screen: modelData
            
            anchors.top: true
            anchors.left: true
            anchors.right: true
            
            implicitHeight: 30
            color: "#252d3b"  // base-deep
            
            Text {
                anchors.centerIn: parent
                text: "garden · " + Qt.formatDateTime(new Date(), "HH:mm")
                color: "#d4c5a9"  // text-1
                font.family: "IBM Plex Mono"
                font.pixelSize: 12
            }
            
            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: parent.children[0].text = 
                    "garden · " + Qt.formatDateTime(new Date(), "HH:mm")
            }
        }
    }
}
```

Test it:

```bash
quickshell -p ~/.config/quickshell/garden/shell.qml
```

Add to Niri startup once it works:

```kdl
// In config.kdl
spawn-at-startup "quickshell" "-p" "/home/ada/.config/quickshell/garden/shell.qml"
```

**✓ Checkpoint:** A thin Garden bar at the top of your screen showing
"garden · 14:32" in mokume colors. It's minimal but it's real.
The Quickshell pipeline works. You can iterate from here.

---

## End-of-Day State

If all stages complete, you have:

```
✓ NixOS running on MS-A2 as host "garden"
✓ Niri compositor with 5 named workspaces (channels)
✓ Kitty terminal in mokume palette
✓ Fish shell with ✧ prompt and channel detection
✓ Kakoune with garden.kak colorscheme
✓ Full terminal toolkit (bat, delta, fzf, yazi in Garden colors)
✓ palettes.json as single source of truth
✓ Quickshell skeleton bar (minimal but functional)
✓ Super+1-5 switches channels, Super+H/L scrolls columns
✓ The system feels like Garden even without the full shell
```

Tomorrow and following days:
- Claude Code sessions per 10-session-plan.md
- Build out the full bar, launcher, channel switcher
- Dendritic migration of fern repo (can happen while using the system)
- Theme generator to produce all 17 outputs from palettes.json

---

## If Things Go Wrong

### Niri won't start
- Check `journalctl -b -u display-manager`
- Fall back to the previous desktop session to debug
- Verify niri-flake is properly added and built

### Kitty looks wrong
- Check font installation: `fc-list | grep -i plex`
- If fonts missing: `sudo nixos-rebuild switch` again after adding fonts

### Fish prompt broken
- Test with: `fish -c 'fish_prompt'`
- Make sure niri msg works: `niri msg -j focused-output`
- The channel detection fails gracefully if niri isn't available

### Can't build at all
- `nix flake check --show-trace` for detailed errors
- Check that flake inputs are added correctly
- `sudo nixos-rebuild test --flake .#garden --show-trace`

---

## What's Next — Connecting to the Session Plan

After this jam session, you have a working system. The next step is
to start Claude Code sessions from `10-session-plan.md`, which picks
up exactly where this leaves off.

**Recommended next sessions (in order):**

| Session | What it does | Why now |
|---------|-------------|---------|
| A1 | Dendritic migration of fern | Clean up the structural debt from this jam |
| B1 | Dendritic migration of fern-shell | Same pattern for the shell repo |
| B2 | NiriAdapter + CompositorService | Replace skeleton bar with real compositor bridge |
| B3 | Theme.qml palette singleton | Read palettes.json reactively in QML |
| C1 | Theme generator | Produce all 17 theme files from palettes.json |
| B4 | Real bar | Channel indicators, density modes, column awareness |

**The critical path from here:**
```
Jam Session (today)
  → A1 (dendritic migration — cleanup)
  → B2 + B3 (NiriAdapter + Theme — shell foundation)
  → B4 (real bar — first visible Garden Shell component)
  → B5 (launcher + channel switcher)
  → everything else builds on this
```

**Reference documents for agents:**
- `09-build-plan.md` — master task checklist
- `10-session-plan.md` — scoped session descriptions with context blocks
- `02-shell-design.md` — what to build (components + architecture)
- `07-niri-migration.md` — how Niri integration works
- `garden-palette-editor.jsx` — visual reference for aesthetics


# Garden Shell

Garden is a shell environment built around a single idea: one palette definition
drives every tool you touch — terminal, shell, editor. You change colors in one
place and everything follows.

This book documents the palette system, which is the foundation that makes that
possible. Other parts of Garden (the daemon, the TUI, the control CLI) are still
taking shape; the palette pipeline is mature and stable.

## What's here

The **Palette** section covers everything about Garden's color system:

- [**The color system**](palette/overview.md) — the 13 semantic roles every
  palette defines
- [**Built-in palettes**](palette/builtin.md) — the four palettes that ship
  with Garden
- [**Theme generators**](palette/generators.md) — how palettes become kitty,
  fish, and kakoune configs
- [**Custom palettes**](palette/custom.md) — creating your own

The **Developing** section covers the QML shell and the dev-to-dogfood workflow:

- [**Shell architecture**](developing/architecture.md) — singletons, overlays,
  IPC, and theme reactivity
- [**Development workflow**](developing/workflow.md) — the three-tier dev loop,
  debugging, fern integration, and justfile recipes

## How to read it

Each page uses progressive disclosure. The top of the page gives you what you
need to *use* the system — a table, a command, a quick explanation. Further down,
you'll find design rationale (why things work this way) and implementation
details (how they work under the hood). Read as far as your interest takes you.

## Quick start

```bash
# Switch to the yoru palette and apply it everywhere
just themes try yoru
```

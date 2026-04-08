# Garden — Research Workflow & Scholarly Infrastructure

> How materials enter the system, get processed, connected, written
> about, and published. The "Research OS" that connects Zotero,
> Obsidian, Kakoune, Typst, Pandoc, and the Garden curation app.

**Last updated:** 2026-03-27
**Related docs:** `02-shell-design.md`, `05-nyxt-and-curation.md`

---

## 1. Four Activities, Four Tools

```
COLLECTING     → Zotero          (the library)
READING        → Zotero + Obsidian (annotate, then synthesize)
THINKING       → Obsidian        (the workshop)
WRITING        → Kakoune + Typst (the press)

CURATING       → Garden app      (the gallery — visual/conceptual)
```

Each tool has a clear role. The transitions between them should be
frictionless. No tool replaces another.

---

## 2. Zotero — The Library

### What It Holds
Every paper, book, chapter, report, and web source gets a structured
record: author, title, date, publisher, DOI, ISBN, citation key.
This metadata is what makes citation possible.

### Key Plugins
- **Better BibTeX** — auto-generates consistent citation keys
  (`ratto_2011`, `mattern_2017`), auto-exports to `references.bib`
  via WebDAV for Pandoc/Typst consumption
- **Zotero PDF Reader** — built-in annotation (highlights, notes),
  dark mode, color-coded highlighting

### Physical Books
Create Zotero entries manually or via ISBN scan. The entry exists
without a PDF attached. Annotate the physical book with marginalia,
then capture key takeaways in an Obsidian literature note with page
references.

### Digital PDFs
Stored and organized in Zotero. Read and annotate inline. Annotations
flow to Obsidian via the Zotero Desktop Connector plugin.

### Self-Authored Work
Create a Zotero collection "My Writing" for your own papers, drafts,
and book chapters. Add completed work as entries with full metadata
(your name as author, title, date, venue). Better BibTeX generates
citekeys for self-citation in future work. This builds a living
bibliography of everything you've produced — useful for graduate
program applications.

### Lifecycle of Self-Authored Work
```
Obsidian (outline, notes, rough draft)
  → git repo (Typst source, iterated drafts, version history)
    → typst compile (PDF output)
      → Zotero "My Writing" collection (cataloged, citable)
        → published / submitted / shared
```

### Running Zotero in Garden Shell
Zotero runs as a background app, not assigned to a specific channel.
It's a service you summon when needed — via Alt+Tab or a launcher
command. It doesn't need a permanent page in any channel.

---

## 3. Obsidian — The Workshop

### Purpose
Processing, synthesizing, arguing, drafting. Private, messy, evolving.
Notes in various states of completion. The Zettelkasten structure is
for *thinking*, not *presenting*.

### Note Types (Zettelkasten)
- **Literature Notes** — one per source, imported from Zotero.
  Contains metadata, Zotero link, extracted annotations/highlights.
  Created via Zotero Desktop Connector plugin.
- **Permanent Notes** — your own ideas, synthesized across sources.
  Linked bidirectionally. "Matt Ratto's critical making connects to
  bell hooks' theory/practice critique connects to Garden's
  infrastructure-as-pedagogy argument."
- **Project Notes** — per-paper or per-chapter outlines, drafts,
  arguments in progress. Reference both literature and permanent notes.
- **Index Notes** — hub pages that collect notes by theme, project,
  or question. Maps of your thinking.

### Key Plugins
- **Zotero Desktop Connector** — imports literature notes with
  annotations from Zotero PDFs
- **Citations** — insert `@citekeys` inline while writing, with
  fuzzy search of your Zotero library
- **Dataview** — query your vault for structured information
  (e.g. all literature notes tagged "critical-making")
- **Templater** — consistent note templates for literature notes,
  permanent notes, project outlines
- **Canvas** — visual arrangement of notes for argument mapping
  (complementary to the curation app's channel view)

### Obsidian in Garden Shell
Lives as a page in the `writing` channel: `writing:obsidian`.
Column width: 60% (prose needs width but not the full screen).

---

## 4. The Garden Curation App — The Gallery

### Purpose
Collecting and arranging visual and conceptual materials. Not a
bibliography manager (Zotero does that) or a note-taking app
(Obsidian does that). The *visual and curatorial* dimension of
research that neither handles well.

### What Goes Here
- Web clips, images, video stills, screenshots
- Photos of physical book pages, diagrams, artworks
- Design references, artist studies, aesthetic research
- Visual mood boards for papers or projects
- Curated collections organized by theme/channel

### How It Relates to Are.na
Are.na's power was never as a bibliography or note system — it was
a space for *collecting and arranging things visually*, finding
unexpected connections through juxtaposition. That's what the
Garden curation app should do.

### In Garden Shell
Scratchpad (Alt+G) — pull it up to save a visual reference, browse
collections, find connections. Cross-channel tool, not tied to one
workspace.

### What Doesn't Go Here
- Citation metadata (→ Zotero)
- Extended prose notes (→ Obsidian)
- Source PDFs (→ Zotero)
- Drafts and manuscripts (→ git repos)

---

## 5. Writing & Publishing — Kakoune + Typst

### Why Typst
- Written in Rust (your ecosystem)
- Compiles instantly (live preview via `typst watch`)
- Dramatically simpler syntax than LaTeX
- Handles footnotes, bibliographies (BibTeX/CSL), cross-references
- Humanities scholars are already using Pandoc + Typst for articles
  and books
- When a journal needs .docx, Pandoc converts markdown/Typst to Word

### Why Not LaTeX
- Over-engineered for prose-heavy work without equations
- Steep learning curve for marginal benefit in humanities writing
- Worth knowing for specific journal templates that require it
- Use LaTeX only when a venue demands it, not as daily driver

### What Humanities Scholars Actually Use
Most use Word. Your target programs (UCLA Info Studies, OCAD Digital
Futures, King's College DH) expect technical fluency — submitting
work produced with your own toolchain is a feature, not a bug.

### The Writing Stack
```
Kakoune (edit .typ files)
  + typst watch (live recompile on save)
  + Zathura (PDF preview, auto-refreshes)
  + references.bib (auto-exported from Zotero via Better BibTeX)
```

### Niri Writing Layout

Two adjacent columns at 50% width — Kakoune on left, Zathura on
right. Both visible simultaneously on the strip. No special split
mode needed; Niri's scrollable strip naturally shows adjacent columns.

```kdl
// Niri window rules for writing layout
window-rule {
    match app-id="kitty" title=r#"\.typ$|\.md$"#
    open-on-workspace "writing"
    default-column-width { proportion 0.5; }
}
window-rule {
    match app-id="org.pwmt.zathura"
    open-on-workspace "writing"
    default-column-width { proportion 0.5; }
}
```

The layout is fluid. Scroll left to focus on just the writing.
Scroll right to bring the preview back. Add Obsidian as a third
column further along the strip — notes on the far left, editor
center, preview right. The writing channel is a horizontal desk.

### Fish Writing Environment Setup

One command to spawn the full writing environment:

```fish
function writing-setup --description "Set up Typst writing environment"
    # Focus the writing workspace
    niri msg action focus-workspace "writing"

    # Open the source file in Kakoune
    kitty -e kak $argv[1] &

    # Start typst watch in background (silent recompile on save)
    typst watch $argv[1] &

    # Wait for first compile, then open PDF preview
    set -l pdf (string replace -r '\.(typ|md)$' '.pdf' $argv[1])
    sleep 0.5
    zathura $pdf &
end

# Usage:
# writing-setup paper.typ
# writing-setup thesis/chapter-1.typ
```

### Garden Launcher Integration

Type in the launcher:
```
write paper.typ         → runs writing-setup, spawns all three
write thesis/ch1.typ    → same, for book chapters
```

Implemented as a launcher source that recognizes the `write` prefix
and calls the Fish function (or directly spawns the processes):

```qml
// sources/WriteSource.qml
// Matches "write <filename>" in launcher
// Spawns Kakoune + typst watch + Zathura in writing channel
```

### Citation Workflow

```
1. Reading a paper in Zotero → highlight + annotate
2. Import annotations to Obsidian literature note
3. Synthesize into permanent notes
4. Start writing in Kakoune (.typ or .md file)
5. Insert citation: type @, fuzzy-search Zotero library
   (via fzf + references.bib, or Pandoc citekeys)
6. typst watch recompiles → Zathura shows updated PDF
7. When done: pandoc converts to .docx if advisor needs Word
```

For citations in Kakoune, a custom command pipes `@` + partial key
through fzf against `references.bib`:

```fish
function cite --description "Fuzzy-search citations from references.bib"
    grep '@' ~/references.bib \
        | sed 's/.*{\(.*\),/\1/' \
        | fzf --preview 'grep -A5 {} ~/references.bib' \
        | read -l key
    and echo -n "@$key"
end
```

### Output Formats

```fish
# PDF via Typst (primary output)
typst compile paper.typ paper.pdf

# PDF via Pandoc + Typst (from markdown source)
pandoc paper.md \
    --citeproc \
    --bibliography=references.bib \
    --csl=chicago-fullnote-bibliography.csl \
    -o paper.pdf \
    --pdf-engine=typst

# Word for advisor feedback / journal submission
pandoc paper.md \
    --citeproc \
    --bibliography=references.bib \
    --csl=chicago-fullnote-bibliography.csl \
    -o paper.docx

# LaTeX (only when a venue demands it)
pandoc paper.md \
    --citeproc \
    --bibliography=references.bib \
    -o paper.tex
```

### Version Control for Writing

Each major project gets a git repository:

```
paper-infrastructure-pedagogy/
  paper.typ              # main source
  references.bib         # auto-exported from Zotero
  figures/               # diagrams, images
  chicago.csl            # citation style
  template.typ           # custom Typst template (Garden-styled)
  .gitignore             # ignore .pdf output

thesis/
  main.typ               # imports chapters
  chapters/
    01-introduction.typ
    02-critical-making.typ
    03-garden-as-inquiry.typ
    ...
  references.bib
  figures/
  template.typ
```

Git history IS your draft history. Every save is recoverable. Branch
for different submission versions (`v1-submitted`, `v2-revised`).

---

## 6. The Complete Flow

```
WORLD
  │
  ├── web source → Nyxt Alt+S → Garden curation app (visual)
  │                  └──────→ Zotero (citation metadata)
  │
  ├── PDF paper → Zotero (store, annotate, highlight)
  │                  └──→ Obsidian literature note (synthesize)
  │
  ├── physical book → Zotero entry (ISBN, metadata)
  │                     └──→ Obsidian literature note (key passages)
  │                     └──→ Garden app (photo of diagram/page)
  │
  └── your own idea → Obsidian permanent note (develop)
                        └──→ connect to other notes
                        └──→ project outline
                        └──→ draft in Kakoune (.typ)
                        └──→ typst compile → PDF
                        └──→ Zotero "My Writing" (catalog)

GARDEN SHELL CHANNELS:
  research:  Kakoune (code) · Frontier terminal · Nyxt (docs)
  writing:   Obsidian (notes) · Kakoune+Zathura (write+preview)
  system:    ... planner, config, monitor
```

---

## 7. Tool Configuration Summary

### Better BibTeX (Zotero)
- Citation key format: `authors(n=1,etal=EtAl)+year` → `ratto_2011`
- Auto-export: `references.bib` to a shared location (WebDAV or
  local path) that all writing repos symlink to
- Export format: Better BibTeX JSON or BibLaTeX

### Obsidian Plugins
- Zotero Desktop Connector (literature note import)
- Citations (inline @citekey insertion)
- Dataview (structured queries across vault)
- Templater (consistent note templates)
- Canvas (visual argument mapping)

### Kakoune Writing Support
- Typst syntax highlighting (tree-sitter grammar)
- fzf citation insertion (grep references.bib)
- `typst watch` integration (background process)
- Word wrap / soft wrap for prose editing

### Zathura (PDF Viewer)
- Garden palette theme (generated from palettes.json)
- Auto-reloads on file change (native feature)
- Vim keybindings for navigation
- Column width: 50% in writing channel

### Pandoc
- Installed system-wide via NixOS
- CSL styles: Chicago (humanities default), APA, MLA as needed
- Lua filters for custom processing (wikilink stripping, etc.)
- Used for markdown → PDF, markdown → docx, Typst → docx conversion

---

## 8. Naming Consideration

The curation app is currently called "Garden" — the same name as
the shell, the infrastructure workspace, and the overall project.
This creates ambiguity. Options:

1. **Keep "Garden" for the curation app** — it was the original,
   the shell is "Garden Shell," the infra is "garden-infra"
2. **Rename the curation app** — find a name that captures the
   Are.na-like curation purpose distinctly
3. **Rename the shell** — the shell could have its own name while
   "Garden" stays with the app

The app was first. The shell grew from it. The name conflict is
worth resolving before the ecosystem gets larger.

---

## 9. Open Questions

- [ ] Should `references.bib` be a single shared file or per-project?
      (Single: simpler. Per-project: self-contained repos.)
- [ ] Obsidian vault location: in a git repo, or synced via other means?
- [ ] Should Zotero PDFs be stored in Zotero's own storage or a
      custom location (for Calibre integration, backup)?
- [ ] Typst template design: should the Garden palette influence the
      PDF output typography? (M PLUS 1p body, IBM Plex Mono code?)
- [ ] Book project: single Typst file or multi-file with imports?
      (Multi-file with chapter imports for anything book-length.)
- [ ] Should the `write` launcher command also open Obsidian notes
      related to the current project?

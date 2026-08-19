# render-pdf

Markdown → Typst → PDF, with ```` ```mermaid ```` blocks rendered to vector SVG. Portable
version of the tool originally built for `themelio/restructure-brainstorm/`.

```sh
render-pdf some/doc.md          # -> some/doc.pdf
render-pdf *.md                 # batch
render-pdf --academic paper.md  # paper layout (see Styles below)
```

Symlinked to `~/.local/bin/render-pdf` by `home/darwin.nix`. `diagrams/` is created next to
each input file (its own per-project cache), not next to this script.

## Styles

Options go **before** the first file, and apply to every file in a batch.

| Flag | Effect |
| --- | --- |
| *(none)* | The default look: Georgia 10.5pt, A4, ragged-right. Good for planning and brainstorm docs. |
| `--academic` | Paper layout: title block (from frontmatter, or a promoted leading `#`), New Computer Modern 11pt, justified with first-line indents, 2.5cm margins, 1.5 leading, and citeproc. |
| `--auto-numbering` | Numbers headings from level 1: `#` → 1, `##` → 1.1, `###` → 1.1.1. Works with either style. |
| `--toc` | Table of contents, depth 3, with the body starting on a fresh page after it. Works with either style. |

`--academic` turns on **citeproc**, so `[@citekey]` resolves and a References section is
appended. The sources come from the document's own YAML frontmatter, not from this bundle:

```yaml
---
title: Some Paper
author: A. Person
date: 2026-08-19
bibliography: refs.bib
csl: ieee.csl        # optional; pandoc's default is Chicago author-date
---
```

With no `bibliography:` key, citeproc is a no-op and citations pass through as literal text.

`--auto-numbering` is deliberately **not** implied by `--academic`, because headings are often
already numbered by hand in the markdown. It numbers from `#`, so `#` needs to be a section
rather than the document title.

Under `--academic` the title is best given as frontmatter `title:`. A document that instead
opens with a single `#` heading still works, because `academic-title.lua` lifts that heading
into the title block and shifts the remaining headings up one level. The promotion is
conservative and fires only when there is no frontmatter title, the document has exactly one
level-1 heading, and that heading is the very first block. A document using `#` for each
section keeps all of them as sections. Without the promotion, pandoc emits the table of
contents right after an empty title block, which puts it above the `#` title and lists the
title as its own first ToC entry. The level shift matters for `--auto-numbering`, which would
otherwise number the now-orphaned `##` sections as 0.1, 0.2, 0.2.1.

The default style does not get this filter. `pdf-defaults.yaml` is built around `#` for the
title and `###` for sections, so promoting the heading there would change how every existing
document renders.

Each style is one self-contained pandoc defaults file (`pdf-defaults.yaml`,
`pdf-defaults-academic.yaml`); they duplicate the engine plumbing rather than sharing a base,
so each is readable on its own. `--auto-numbering` and `--toc` are plain pandoc options
(`-V section-numbering=1.1.1`, `--toc --toc-depth=3`) layered on whichever defaults file is in
play, so they compose with both styles. `--toc` additionally injects `toc-pagebreak.typ`, a
`#show outline:` rule that appends the page break, since the outline comes from pandoc's
template and there is no seam in the markdown to break at. Note that numbering has to go through
`section-numbering` rather than a `#set heading(numbering: ...)` snippet in `header-includes`:
pandoc's typst template applies its own heading-numbering rule inside the `conf()` show rule
that wraps the document body, which lands after the header-includes and overrides them.

## Prerequisites (not managed by Nix — install manually)

- `pandoc` and `typst` on PATH: `brew install pandoc typst`
- `mmdc` (mermaid CLI) on PATH: `npm install -g @mermaid-js/mermaid-cli`

## `puppeteer-config.json`: why `executablePath` is set

`mmdc` bundles its own pinned Puppeteer/Chrome-revision. A **global** `mmdc` install commonly
wants a Chrome revision that isn't the one cached at `~/.cache/puppeteer` (that cache tends to
hold whatever revision other local puppeteer-using tools last installed), and then fails with
`Could not find Chrome (ver. X.Y.Z...)`. Rather than chase the exact matching revision, this
config pins `executablePath` straight at the system's installed Google Chrome, which sidesteps
revision pinning entirely. Only requirement: Chrome installed at the path in the file. If you
don't have Chrome, swap `executablePath` for another Chromium-family browser, or remove the key
and instead run `npx puppeteer browsers install chrome-headless-shell` to populate the cache
with a matching revision (fragile — breaks again on the next `mmdc` update).

## Provenance

Copied and adapted from `themelio/restructure-brainstorm/render-pdf.sh` (see that repo's
`RENDERING.md` for the full original design rationale: page-setup choices, diagram
aspect-ratio/pagebreak logic, why Typst over LaTeX, etc.). Changes made here for portability:

- `MMDC` resolved via `command -v mmdc` on PATH, not a hardcoded sibling `docs/node_modules`
  path — this tool no longer assumes it lives inside the themelio repo.
- `puppeteer-config.json` bundled locally (see above) instead of reaching into themelio's
  `docs/plugins/mermaid-png/`.
- `DIAGRAM_DIR` computed per input file (next to the `.md` being rendered) instead of once,
  next to the script.
- `pdf-defaults.yaml` no longer lists `mermaid.lua` under `filters:` (that path resolves
  against pandoc's CWD, which broke once this runs against files outside its own directory);
  `render-pdf.sh` passes it instead via `--lua-filter` with an absolute path.

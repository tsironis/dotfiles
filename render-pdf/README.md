# render-pdf

Markdown → Typst → PDF, with ```` ```mermaid ```` blocks rendered to vector SVG. Portable
version of the tool originally built for `themelio/restructure-brainstorm/`.

```sh
render-pdf some/doc.md          # -> some/doc.pdf
render-pdf *.md                 # batch
```

Symlinked to `~/.local/bin/render-pdf` by `home/darwin.nix`. `diagrams/` is created next to
each input file (its own per-project cache), not next to this script.

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

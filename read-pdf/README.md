# read-pdf

Plain-text (and annotation) extraction from a PDF via PyMuPDF. The mirror image of
`render-pdf`: instead of turning markdown into a PDF, this turns a PDF back into text
Claude (or anything else) can read cheaply, instead of paying for page-by-page image
parsing.

```sh
read-pdf paper.pdf                # whole document -> stdout
read-pdf paper.pdf report.pdf     # batch, each prefixed with an "==> file" header
read-pdf --pages 1-5 paper.pdf    # only pages 1 through 5
read-pdf --pages 3 paper.pdf      # only page 3
read-pdf --annots reviewed.pdf    # also print sticky-note/highlight comment text
```

Symlinked to `~/.local/bin/read-pdf` by `home/darwin.nix`. Always writes to stdout, no
output file — pipe it or redirect it as needed.

Only extracts embedded text and annotation content: a scanned or image-only PDF will
come back empty (or near-empty) and still needs a visual reader (e.g. Claude's built-in
PDF page-image parsing) or OCR.

## Why PyMuPDF instead of poppler/pdftotext

`pdftotext` only reads the page content stream, so it can't see annotation objects
(sticky notes, highlight comments, form fields). PyMuPDF's `page.annots()` exposes those
directly, which `--annots` reports as `[annotation pN, type, author]: content`.

## Prerequisites

- `uv` and `python3` on PATH (already declared in `environment.systemPackages` in
  `hosts/darwin/modules/apps.nix`). No separate PyMuPDF install: the script's
  `#!/usr/bin/env -S uv run --script` shebang and inline PEP 723 metadata block tell
  `uv` to install `pymupdf` into an ephemeral, cached venv on first run.

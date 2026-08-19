#!/usr/bin/env bash
# Render markdown to PDF with mermaid diagrams rendered as vector SVG.
#
#   render-pdf pharos-planning-v2.md
#   render-pdf *.md
#   render-pdf --academic paper.md
#   render-pdf --academic --toc --auto-numbering paper.md
#
# Route: pandoc -> typst. Needs pandoc, typst, and mmdc (mermaid CLI) on PATH.
set -euo pipefail

# Resolve the full symlink chain (invoked as ~/.local/bin/render-pdf -> a Nix store path
# -> the real file in this repo via mkOutOfStoreSymlink): plain `dirname "${BASH_SOURCE[0]}"`
# would land on ~/.local/bin instead of this bundle's directory, and pdf-defaults.yaml etc.
# would not be found there.
SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SOURCE" ]]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
HERE="$(cd -P "$(dirname "$SOURCE")" && pwd)"

export MMDC
if ! MMDC="$(command -v mmdc)"; then
  echo "error: mmdc (mermaid CLI) not found on PATH" >&2
  echo "       install it with: npm install -g @mermaid-js/mermaid-cli" >&2
  exit 1
fi

for tool in pandoc typst; do
  command -v "$tool" >/dev/null || { echo "error: $tool not found on PATH" >&2; exit 1; }
done

export PUPPETEER_CFG="$HERE/puppeteer-config.json"
export MERMAID_CFG="$HERE/mermaid-config.json"

usage() {
  cat <<EOF
usage: $(basename "$0") [options] <file.md> [file.md ...]

options:
  --academic         paper layout: title block from frontmatter, New Computer Modern,
                     justified text, wider margins, and citeproc for [@citekey] refs
                     (reads bibliography:/csl: from the document's own frontmatter)
  --auto-numbering   number headings from level 1 (# -> 1, ## -> 1.1, ### -> 1.1.1);
                     leave it off when the markdown already numbers its headings by hand
  --toc              emit a table of contents (depth 3)
  -h, --help         this message

Options must come before the first file. Both styles accept --auto-numbering and --toc.
EOF
}

DEFAULTS="$HERE/pdf-defaults.yaml"
EXTRA=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --academic)
      DEFAULTS="$HERE/pdf-defaults-academic.yaml"
      # Lifts a leading `# Title` into the title block, so the ToC does not end up above it.
      # See academic-title.lua for why this is not applied to the default style.
      EXTRA+=(--lua-filter="$HERE/academic-title.lua")
      # The tall-diagram heuristic in mermaid.lua is calibrated against the default style's
      # text block; this style's wider margins make it 16cm x 24.7cm.
      export TEXT_BLOCK_ASPECT=0.63
      shift
      ;;
    # -V, not an --include-in-header snippet: pandoc's typst template applies its own
    # `set heading(numbering: sectionnumbering)` inside the conf() show rule that wraps the
    # body, which lands after any header-includes and silently overrides them.
    --auto-numbering) EXTRA+=(-V section-numbering=1.1.1); shift ;;
    --toc)            EXTRA+=(--toc --toc-depth=3 --include-in-header="$HERE/toc-pagebreak.typ"); shift ;;
    -h|--help)        usage; exit 0 ;;
    --)               shift; break ;;
    # Anything else starting with - is a typo, not a filename. Bare `*` breaks the loop so
    # that everything from the first file onward stays a file, even if it starts with a dash.
    -*)               echo "error: unknown option: $1" >&2; usage >&2; exit 2 ;;
    *)                break ;;
  esac
done

if [[ $# -eq 0 ]]; then
  usage >&2
  exit 2
fi

for input in "$@"; do
  if [[ ! -f "$input" ]]; then
    echo "error: no such file: $input" >&2
    exit 1
  fi
  # Diagram cache lives next to the input file, not next to the script, so each
  # project keeps its own cache when this tool is run against many repos.
  export DIAGRAM_DIR="$(cd "$(dirname "$input")" && pwd)/diagrams"
  mkdir -p "$DIAGRAM_DIR"
  output="${input%.md}.pdf"
  echo "==> $input -> $output"
  # ${EXTRA[@]+...} guards the empty-array expansion, which is an unbound-variable error
  # under `set -u` on the bash 3.2 that ships with macOS.
  pandoc "$input" --defaults="$DEFAULTS" --lua-filter="$HERE/mermaid.lua" \
    ${EXTRA[@]+"${EXTRA[@]}"} -s -o "$output"
done

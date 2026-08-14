#!/usr/bin/env bash
# Render markdown to PDF with mermaid diagrams rendered as vector SVG.
#
#   render-pdf pharos-planning-v2.md
#   render-pdf *.md
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

if [[ $# -eq 0 ]]; then
  echo "usage: $(basename "$0") <file.md> [file.md ...]" >&2
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
  pandoc "$input" --defaults="$HERE/pdf-defaults.yaml" --lua-filter="$HERE/mermaid.lua" -s -o "$output"
done

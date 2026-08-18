#!/usr/bin/env bash
# Manually curated index of available CLI tools — hand-edit tools-registry.yaml
# to add/update entries, this script only lists/filters.
#
#   tools-registry list
#   tools-registry list --source homebrew
#   tools-registry list --search git
#
# Needs yq (https://github.com/mikefarah/yq) on PATH.
set -euo pipefail

SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SOURCE" ]]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
HERE="$(cd -P "$(dirname "$SOURCE")" && pwd)"
DATA="$HERE/tools-registry.yaml"

command -v yq >/dev/null || { echo "error: yq not found on PATH" >&2; exit 1; }

usage() {
  cat >&2 <<EOF
usage: $(basename "$0") list [--source nix-managed|homebrew|go-install|npm-global] [--search TEXT]
EOF
  exit 2
}

cmd=${1:-}
[[ "$cmd" != "list" ]] && usage
shift

source_filter=""; search=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --source) source_filter="$2"; shift 2 ;;
    --search) search="$2"; shift 2 ;;
    *) echo "error: unknown option $1" >&2; exit 2 ;;
  esac
done

filter='.tools[]'
[[ -n "$source_filter" ]] && filter="$filter | select(.source == \"$source_filter\")"
if [[ -n "$search" ]]; then
  needle=$(printf '%s' "$search" | tr '[:upper:]' '[:lower:]')
  filter="$filter | select((.name + \" \" + .description) | downcase | test(\"$needle\"))"
fi
filter="$filter | (.name + \"\t\" + .source + \"\t\" + .description)"
yq eval "$filter" "$DATA"

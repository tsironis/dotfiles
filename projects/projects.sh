#!/usr/bin/env bash
# Thin CLI over projects.yaml — a personal/work project tracker.
#
#   projects list [--category poc|quality-of-life|product|other] [--owner personal|work] [--status active|paused|done|abandoned]
#   projects show <name>
#   projects add [--name NAME] [--path PATH] [--category CAT] [--owner OWNER] [--status STATUS] [--description TEXT] [--repo URL] [--last-touched YYYY-MM-DD]
#     --path defaults to $PWD, --name defaults to its basename, --category may be left blank.
#     --owner defaults by path prefix ($HOME/code -> personal, $HOME/geant -> work), otherwise required.
#   projects touch <name>
#   projects find-path <path>
#   projects categories
#   projects statuses
#
# Needs yq (https://github.com/mikefarah/yq) on PATH.
set -euo pipefail

# Resolve the full symlink chain (invoked as ~/.local/bin/projects -> a Nix store path
# -> the real file in this repo via mkOutOfStoreSymlink), same technique as render-pdf.sh.
SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SOURCE" ]]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
HERE="$(cd -P "$(dirname "$SOURCE")" && pwd)"
DATA="$HERE/projects.yaml"

command -v yq >/dev/null || { echo "error: yq not found on PATH" >&2; exit 1; }

CATEGORIES=(poc quality-of-life product other)
OWNERS=(personal work)
STATUSES=(active paused done abandoned)

usage() {
  cat >&2 <<EOF
usage: $(basename "$0") <command> [args]

commands:
  list [--category CAT] [--owner OWNER] [--status STATUS]
  show <name>
  add [--name NAME] [--path PATH] [--category CAT] [--owner OWNER]
      [--status STATUS] [--description TEXT] [--repo URL] [--last-touched YYYY-MM-DD]
      (--path defaults to \$PWD, --name to its basename, --owner inferred from
       \$HOME/code vs \$HOME/geant when omitted, --category may be left blank)
  touch <name>
  find-path <path>
  categories
  statuses
EOF
  exit 2
}

in_list() {
  local needle=$1; shift
  local x
  for x in "$@"; do [[ "$x" == "$needle" ]] && return 0; done
  return 1
}

validate() {
  local field=$1 value=$2; shift 2
  if ! in_list "$value" "$@"; then
    echo "error: invalid $field '$value' (expected one of: $*)" >&2
    exit 1
  fi
}

cmd=${1:-}
[[ -z "$cmd" ]] && usage
shift

case "$cmd" in
  list)
    category=""; owner=""; status=""
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --category) category="$2"; shift 2 ;;
        --owner) owner="$2"; shift 2 ;;
        --status) status="$2"; shift 2 ;;
        *) echo "error: unknown option $1" >&2; exit 2 ;;
      esac
    done
    [[ -n "$category" ]] && validate category "$category" "${CATEGORIES[@]}"
    [[ -n "$owner" ]] && validate owner "$owner" "${OWNERS[@]}"
    [[ -n "$status" ]] && validate status "$status" "${STATUSES[@]}"

    filter='.projects[]'
    [[ -n "$category" ]] && filter="$filter | select(.category == \"$category\")"
    [[ -n "$owner" ]] && filter="$filter | select(.owner == \"$owner\")"
    [[ -n "$status" ]] && filter="$filter | select(.status == \"$status\")"
    filter="$filter | (.name + \"\t\" + .category + \"\t\" + .owner + \"\t\" + .status + \"\t\" + .path)"
    yq eval "$filter" "$DATA"
    ;;

  show)
    name=${1:-}
    [[ -z "$name" ]] && { echo "usage: $(basename "$0") show <name>" >&2; exit 2; }
    yq eval ".projects[] | select(.name == \"$name\")" "$DATA"
    ;;

  add)
    name=""; path=""; category=""; owner=""; status="active"
    description=""; repo=""; last_touched="$(date +%F)"
    while [[ $# -gt 0 ]]; do
      case "$1" in
        --name) name="$2"; shift 2 ;;
        --path) path="$2"; shift 2 ;;
        --category) category="$2"; shift 2 ;;
        --owner) owner="$2"; shift 2 ;;
        --status) status="$2"; shift 2 ;;
        --description) description="$2"; shift 2 ;;
        --repo) repo="$2"; shift 2 ;;
        --last-touched) last_touched="$2"; shift 2 ;;
        *) echo "error: unknown option $1" >&2; exit 2 ;;
      esac
    done
    [[ -z "$path" ]] && path="$PWD"
    [[ -z "$name" ]] && name="$(basename "$path")"

    if [[ -z "$owner" ]]; then
      case "$path" in
        "$HOME"/code | "$HOME"/code/*) owner="personal" ;;
        "$HOME"/geant | "$HOME"/geant/*) owner="work" ;;
        *)
          echo "error: --owner is required (path is not under \$HOME/code or \$HOME/geant, can't infer it)" >&2
          exit 2
          ;;
      esac
    fi

    [[ -n "$category" ]] && validate category "$category" "${CATEGORIES[@]}"
    validate owner "$owner" "${OWNERS[@]}"
    validate status "$status" "${STATUSES[@]}"
    yq eval -i ".projects += [{\"name\": \"$name\", \"path\": \"$path\", \"category\": \"$category\", \"owner\": \"$owner\", \"status\": \"$status\", \"description\": \"$description\", \"repo\": \"$repo\", \"last_touched\": \"$last_touched\"}]" "$DATA"
    ;;

  touch)
    name=${1:-}
    [[ -z "$name" ]] && { echo "usage: $(basename "$0") touch <name>" >&2; exit 2; }
    yq eval -i "(.projects[] | select(.name == \"$name\") | .last_touched) = \"$(date +%F)\"" "$DATA"
    ;;

  find-path)
    path=${1:-}
    [[ -z "$path" ]] && { echo "usage: $(basename "$0") find-path <path>" >&2; exit 2; }
    yq eval ".projects[] | select(.path == \"$path\")" "$DATA"
    ;;

  categories) printf '%s\n' "${CATEGORIES[@]}" ;;
  statuses) printf '%s\n' "${STATUSES[@]}" ;;

  *) usage ;;
esac

#!/usr/bin/env bash
# Shown once when zellij-sessionizer creates a brand-new session for a project
# directory (see greeting-layout.kdl). Prints tracked-project info if this
# directory is in projects.yaml, plus a pointer to the tool registry, then
# hands off to a normal interactive shell.
set -uo pipefail

HERE="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES_ROOT="$(cd -P "$HERE/.." && pwd)"
PROJECTS_CLI="$DOTFILES_ROOT/projects/projects.sh"

dir="$(pwd)"

echo
if [[ -x "$PROJECTS_CLI" ]] && info="$("$PROJECTS_CLI" find-path "$dir" 2>/dev/null)" && [[ -n "$info" ]]; then
  name=$(printf '%s\n' "$info" | yq eval '.name' -)
  category=$(printf '%s\n' "$info" | yq eval '.category' -)
  owner=$(printf '%s\n' "$info" | yq eval '.owner' -)
  status=$(printf '%s\n' "$info" | yq eval '.status' -)
  description=$(printf '%s\n' "$info" | yq eval '.description' -)
  last_touched=$(printf '%s\n' "$info" | yq eval '.last_touched' -)
  echo "Project: $name  [$category · $owner · $status]"
  [[ -n "$description" && "$description" != "null" ]] && echo "$description"
  echo "last touched: $last_touched"
else
  echo "No tracked project for this directory. Run 'projects add' to track it."
fi
echo "Tip: run 'tools-registry list' to see managed CLI tools."
echo

exec "${SHELL:-/bin/zsh}" -l

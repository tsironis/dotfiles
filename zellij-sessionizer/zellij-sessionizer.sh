#!/usr/bin/env bash
# Resolve the full symlink chain (invoked as ~/.local/bin/zellij-sessionizer -> a Nix
# store path -> the real file in this repo via mkOutOfStoreSymlink), same technique
# as render-pdf.sh — needed to find the sibling greeting-layout.kdl.
SOURCE="${BASH_SOURCE[0]}"
while [[ -L "$SOURCE" ]]; do
  DIR="$(cd -P "$(dirname "$SOURCE")" && pwd)"
  SOURCE="$(readlink "$SOURCE")"
  [[ "$SOURCE" != /* ]] && SOURCE="$DIR/$SOURCE"
done
HERE="$(cd -P "$(dirname "$SOURCE")" && pwd)"

echo -ne
paths=$@

if [[ -z $paths ]]; then
	echo "No paths were specified, usage: ./zellij-sessionizer path1 path2 etc.."
	exit 0
fi

# Check whether the machine has fd available
if [ -x "$(command -v fd)" ]; then
	selected_path=$(fd . $paths --min-depth 1 --max-depth 2 --type d | fzf)
else
	# defer to find if not
	selected_path=$(find $paths -mindepth 1 -maxdepth 2 -type d | fzf)
fi

# If nothing was picked, silently exit
if [[ -z $selected_path ]]; then
	exit 0
fi

# If no directory was selected, exit the script
if [[ -z $selected_path ]]; then
	exit 0
fi

# Get the name of the selected directory, replacing "." with "_"
session_name=$(basename "$selected_path" | tr . _)

# We're outside of zellij, so lets create a new session or attach to an existing one.
if [[ -z $ZELLIJ ]]; then
	cd "$selected_path"

	existing="$(zellij list-sessions -s --no-formatting 2>/dev/null || true)"

	if printf '%s\n' "$existing" | grep -qxF "$session_name"; then
		# Session already exists: plain attach, no greeting.
		zellij attach "$session_name"
	else
		# Brand-new session: launch directly with the greeting layout. Plain `--layout`
		# does NOT reliably create a new session when combined with `--session` (verified
		# empirically: it instead tried to attach and errored "session not found") —
		# `--new-session-with-layout` is the flag that actually guarantees a new session.
		zellij --session "$session_name" --new-session-with-layout "$HERE/greeting-layout.kdl"
	fi
	exit 0
fi

# We're inside zellij so we'll open a new pane and move into the selected directory
zellij action new-tab
zellij action rename-tab $session_name

# Hopefully they'll someday support specifying a directory and this won't be as laggy
# thanks to @msirringhaus for getting this from the community some time ago!
# `clear` first: write-chars lands before the new tab's shell has drawn its own
# prompt, so without it you see a stray raw echo of the typed command above the
# shell's real redraw. Runs the same greet.sh as the brand-new-session path above
# (tracked-project info / tools-registry pointer) — this is the branch the `f`
# keybind actually reaches day to day, since pressing it always implies being
# inside zellij already.
zellij action write-chars "clear && cd $selected_path && $HERE/greet.sh" && zellij action write 10

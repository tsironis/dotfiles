#!/usr/bin/env bash
# Runs an agent CLI (Claude Code, to start) inside the current zellij tab while
# reflecting its state -- working / blocked / idle -- in the tab name, similar
# to what Herdr does for agent sessions. See README.md for the patterns used
# and how to re-tune them if Claude Code's UI text changes.
set -uo pipefail

# Byte-range reads (tail -c) can slice a multi-byte UTF-8 character (e.g. one
# of Claude Code's spinner glyphs) in half. In a UTF-8 locale that makes sed's
# regex engine throw "illegal byte sequence" on the truncated bytes. LC_ALL=C
# treats everything as raw bytes so that can't happen -- we're only doing
# byte/ASCII pattern matching here anyway.
export LC_ALL=C

if [[ -z "${ZELLIJ:-}" ]]; then
	echo "agent-status-wrap must be run inside a zellij session/tab." >&2
	exit 1
fi

if [[ $# -eq 0 ]]; then
	echo "Usage: agent-status-wrap <command> [args...]" >&2
	exit 1
fi

# current-tab-info prints "name: X" / "id: N" / "position: N" (lowercase, one
# per line) for the *focused* tab. We're running interactively in that tab
# right now, so this is us -- capture it once so later renames can target
# this tab by --tab-id regardless of where focus moves afterwards.
tab_info="$(zellij action current-tab-info 2>/dev/null || true)"
tab_id="$(printf '%s\n' "$tab_info" | grep '^id:' | sed 's/^id: *//')"
tab_name="$(printf '%s\n' "$tab_info" | grep '^name:' | sed 's/^name: *//')"

if [[ -z "$tab_id" || -z "$tab_name" ]]; then
	echo "Couldn't read the current tab's id/name from zellij; running unwrapped." >&2
	exec "$@"
fi

logfile="$(mktemp -t agent-status.XXXXXX)"

restore_tab() {
	zellij action rename-tab --tab-id "$tab_id" "$tab_name" 2>/dev/null || true
	rm -f "$logfile"
}

monitor() {
	# Claude Code's TUI redraws via cursor-positioning escapes rather than
	# literal spaces, so multi-word phrases (e.g. "do you want to proceed")
	# can get fused into one run with no space between words -- verified by
	# capturing a real session with `script`. Two signals survive that:
	#
	# 1. It emits the standard OSC 9;4 progress-state escape on every
	#    working/idle transition: `9;4;3;` = indeterminate progress
	#    (working), `9;4;0;` = no progress (idle/done). This is a stable,
	#    non-fragmented control code -- the reliable signal for working vs
	#    idle. It only appears on transitions, so once seen it's remembered
	#    until the next one.
	# 2. The permission-prompt footer ("Esc to cancel · Tab to amend") and
	#    the word "proceed?" render as intact substrings even though the
	#    surrounding words get fused -- short keywords survive where full
	#    phrases don't.
	local last_state="idle" working=0 state pos=0 raw_chunk stripped_chunk osc

	while true; do
		sleep 1
		[[ -f "$logfile" ]] || break

		raw_chunk="$(tail -c +"$((pos + 1))" "$logfile")"
		pos=$(wc -c <"$logfile")

		if [[ -z "$raw_chunk" ]]; then
			continue
		fi

		# Last OSC 9;4 state in this chunk wins, in case it flipped twice
		# within one poll window.
		osc="$(grep -aoE $'\x1b\\]9;4;[0-9];' <<<"$raw_chunk" | tail -1)"
		case "$osc" in
		*"9;4;3;") working=1 ;;
		*"9;4;0;") working=0 ;;
		esac

		# Strip CSI (cursor/color/private-mode) and OSC sequences before
		# substring-matching the permission-prompt markers.
		stripped_chunk="$(sed -E 's/\x1b\[[0-9;?<>=]*[a-zA-Z]//g; s/\x1b\][^\x1b\x07]*(\x07|\x1b\\)?//g' <<<"$raw_chunk")"

		if grep -qiE 'proceed\?|esc to cancel|tab to amend|\(y/n\)' <<<"$stripped_chunk"; then
			state="blocked"
		elif [[ "$working" -eq 1 ]]; then
			state="working"
		else
			state="idle"
		fi

		if [[ "$state" != "$last_state" ]]; then
			case "$state" in
			working) icon="⏳" ;;
			blocked) icon="❗" ;;
			*) icon="" ;;
			esac
			if [[ -n "$icon" ]]; then
				zellij action rename-tab --tab-id "$tab_id" "$icon $tab_name" 2>/dev/null || true
			else
				zellij action rename-tab --tab-id "$tab_id" "$tab_name" 2>/dev/null || true
			fi
			last_state="$state"
		fi
	done
}

trap restore_tab EXIT

# stderr redirected to /dev/null: the monitor shares this terminal with the
# wrapped command's pty below, so any unexpected error (as opposed to the
# already-silenced `zellij action`/`grep` failures above) would otherwise
# corrupt the live TUI instead of failing quietly.
monitor 2>/dev/null &
monitor_pid=$!

# BSD script (macOS): `script -q logfile cmd args...` keeps the wrapped command
# attached to a real pty (colors, spinners, resize all work) while teeing its
# output to logfile for the monitor loop above to scan.
script -q "$logfile" "$@"
status=$?

kill "$monitor_pid" 2>/dev/null || true
wait "$monitor_pid" 2>/dev/null || true

exit "$status"

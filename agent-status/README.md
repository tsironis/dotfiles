# agent-status-wrap

Reflects an agent CLI's state (working / blocked / idle) in the current
zellij tab name, so you can tell which tabs need attention without switching
into each one -- the one piece of [Herdr](https://herdr.dev/)'s pitch worth
having without giving up zellij.

Manual, opt-in wrapper -- it does not hook into `zellij-sessionizer` or
`greet.sh`. Run it in place of the agent command:

```sh
agent-status-wrap claude
```

## How it works

1. On startup, captures the current (focused) tab's id and name via `zellij
   action current-tab-info`. This only works if the tab you're running the
   wrapper in is focused at that moment, which it always is if you type the
   command yourself.
2. Runs the wrapped command through BSD `script -q <logfile> <cmd> ...`, so
   it stays attached to a real pty (colors, spinners, resizing all behave
   normally) while its output is also captured to a temp log file.
3. A background loop polls new bytes appended to that log every second,
   strips ANSI codes, and matches against two patterns:
   - **blocked**: `do you want to (proceed|allow)`, `permission to`, `(y/n)`
   - **working**: `esc to interrupt`, `thinking...`
   - anything else: **idle**
4. On a state change, renames the tab via `zellij action rename-tab
   --tab-id <id> "<icon> <name>"` — `⏳` working, `❗` blocked, no icon when
   idle.
5. On exit, restores the plain tab name and deletes the log file.

## Why OSC codes instead of screen text

An earlier version tried to grep the screen text directly (e.g. "esc to
interrupt") and never matched anything, for two reasons found by capturing a
real session with `script -q /tmp/probe.log claude`:

- Claude Code's actual working indicator is an animated spinner + a rotating
  verb ("Ruminating…", "Germinating…", "Creating…") -- there's no fixed
  string to match.
- The TUI redraws using absolute cursor-positioning escapes instead of
  literal spaces, so multi-word phrases like "do you want to proceed" can
  get fused into one run with no space between words ("wanttoproceed?").

So the wrapper instead reads the standard OSC 9;4 progress-state escape that
Claude Code already emits on every transition (`9;4;3;` = working, `9;4;0;`
= idle/done) for the working/idle signal, and only falls back to short
surviving substrings ("proceed?", "Esc to cancel", "Tab to amend") for the
blocked state, since short tokens survive the word-fusion where full phrases
don't. Verified against v2.1.237.

If detection drifts in a future version, recapture and check both signals:

```sh
script -q /tmp/probe.log claude
# ...use it normally, trigger a permission prompt...
grep -aoE $'\x1b\\]9;4;[0-9];' /tmp/probe.log   # progress-state transitions
strings /tmp/probe.log | grep -i proceed        # permission-prompt wording
```

## Limitations

- macOS/BSD `script` only -- the `script -q logfile cmd...` argument order
  is BSD-specific; GNU `script` (Linux) takes flags differently.
- Tuned for Claude Code only. Other agents (Codex, etc.) print different
  status text and won't classify correctly without new patterns.
- If you switch which tab is focused before the wrapper captures
  `current-tab-info` (i.e. you didn't launch it in the tab you're currently
  looking at), it will track the wrong tab.
- `script`'s log-file writes are internally buffered (observed in ~4KB
  chunks), so there can be a lag of a few seconds between something
  appearing on screen and the monitor loop seeing it in the log, on top of
  its 1s poll interval.

Symlinked to `~/.local/bin/agent-status-wrap` by `home/darwin.nix`.

# zellij-sessionizer

fzf-driven project picker for zellij, in the style of ThePrimeagen's
tmux-sessionizer. Bound to `f` in `zellij/config.kdl`:

```kdl
bind "f" {
    Run "zellij-sessionizer" "/Users/dimitristsironis/code" "/Users/dimitristsironis/geant" {
        direction "Down"
        close_on_exit true
    }
}
```

Takes one or more root paths, lists their subdirectories 1-2 levels deep,
pipes to `fzf` for interactive picking, then takes one of three branches:

1. **Outside zellij, session already exists** — plain `zellij attach`, no
   greeting.
2. **Outside zellij, brand-new session** — `zellij --session NAME
   --new-session-with-layout greeting-layout.kdl`. The layout's single pane
   runs `greet.sh`, which prints tracked-project info (looked up from
   `../projects/projects.yaml`) or a "not tracked" hint, plus a pointer to
   `tools-registry`, then `exec`s into a normal interactive shell. Because of
   the `exec`, zellij's session-serialization snapshots the shell process, not
   `greet.sh` — a later resurrected session won't re-run the greeting.
   (Plain `--layout` does *not* reliably create a new session when combined
   with `--session` — verified empirically, it instead tries to attach and
   errors "session not found" if the name doesn't exist yet.
   `--new-session-with-layout` is the flag that actually guarantees this.)
3. **Already inside zellij** — opens a new tab, `cd`s into the picked
   directory, then runs `greet.sh` inline in that tab's shell (same script as
   branch 2, just invoked via `write-chars` instead of a layout pane command).

**Important:** pressing the `f` keybind always implies you're already inside
a zellij session (that's how keybinds get processed at all), so `$ZELLIJ` is
always set and branch 3 is the one it actually reaches day to day. Branches 1
and 2 only run when this script is invoked directly from a plain shell that
isn't inside any zellij session yet — e.g. a fresh terminal before entering
zellij:
```sh
zellij-sessionizer ~/code ~/geant
```

`greet.sh` and `greeting-layout.kdl` live in this directory (not a separate
top-level one) because they're only ever invoked by this script and have no
standalone use — same "one directory bundles a script + its supporting
config" convention as `render-pdf/`.

Symlinked to `~/.local/bin/zellij-sessionizer` by `home/darwin.nix`.

## Prerequisites (not managed by Nix — install manually)

- `fzf` on PATH.
- `fd` on PATH (falls back to `find` if missing).
- `yq` on PATH (used by `greet.sh` to read `projects.yaml`) — already
  installed via Homebrew, see `hosts/darwin/modules/apps.nix`.

## Provenance

Adapted from the sibling `tmux-sessionizer` script (kept separately at
`~/.local/bin/tmux-sessionizer`, not tracked in this repo) for zellij.

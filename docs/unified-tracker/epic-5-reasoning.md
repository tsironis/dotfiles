# EPIC 5 — Reasoning layer (spawned Claude Code sessions)

Rationale and dependencies: see `epics.md`. Gated behind the TUI shell
(EPIC 1) and at least one of artifacts/goals (EPIC 2 or 3).

## Story: Headless mode

- [ ] Render the rollup (EPIC 3) as plain text.
- [ ] Shell out to `claude -p "<text>"`, capture stdout.
- [ ] Render the captured output inline in the TUI, as one continuous app
      (no screen handoff).

## Story: Interactive handoff mode

- [ ] Suspend the TUI's screen.
- [ ] Exec `claude` interactively in the terminal.
- [ ] Resume the TUI on exit — follow the same pattern lazygit uses for
      `$EDITOR` handoff.

## Story: Session-note filing

- [ ] On keybind, prompt the user for `project` + `slug` (not
      auto-derived — a timestamp slug risks collisions and unhelpful
      filenames).
- [ ] Write the `session-note` artifact via EPIC 2's plumbing (frontmatter
      schema, vault walker, slug-uniqueness check).

## Non-goals for this EPIC (do not schedule work here)

- Piping session output through `~/code/lege` for a TTS review pass —
  P2, not committed, per design doc §4.
- Building any orchestration platform. Parallel/multi-step work uses Claude
  Code's own `Workflow`/`Agent` tools; no dify, no OpenHands native agent
  loop. OpenHands' ACP mode may be reached for later as a sandboxed execution
  backend, but building that integration isn't scheduled work here — it's a
  reserved option, not a committed story.

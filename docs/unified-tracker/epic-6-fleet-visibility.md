# EPIC 6 — Agent-fleet visibility

Rationale and dependencies: see `epics.md`. Gated behind the TUI shell
(EPIC 1). Independent of EPIC 5 otherwise — this watches Claude Code
sessions in general, not specifically ones this tracker spawned.

## Story: Local session detection

- [ ] Reuse `agent-status-wrap`'s state-detection approach: OSC 9;4
      progress-state escapes (`9;4;3;` working, `9;4;0;` idle), not
      screen-text scraping.
- [ ] Enumerate locally running Claude Code sessions (interactive terminals,
      zellij tabs) and their current state (working/idle/blocked).
- [ ] If state-detection needs extending beyond what `agent-status-wrap`
      already covers, capture a real session first (per that project's
      recapture instructions) rather than guessing at status text.

## Story: Scheduled/cloud session detection

- [ ] Enumerate cron/cloud agents (`CronCreate`, the `schedule` skill) and
      their last-run/next-run/current state.
- [ ] Enumerate any active OpenHands-ACP sandboxed sessions, if EPIC 5 has
      built that integration by this point.

## Story: TUI view

- [ ] List view: one row per session/agent — what it's running, where
      (repo/project), state, started when.
- [ ] No dispatch/control actions from this view in v1 (read-only
      visibility) — starting, stopping, or scheduling stays with each
      mechanism's own interface (terminal, `CronCreate`, etc.).

## Non-goals for this EPIC (do not schedule work here)

- No new scheduler or dispatch mechanism — this is read-only visibility over
  what Claude Code already runs/schedules.
- No cross-machine aggregation beyond what Claude Code's own cloud-agent
  state already provides.

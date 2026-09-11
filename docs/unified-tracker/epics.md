# Unified tracker: EPICs

Derived from `design.md` plus the grilling session that
closed its open holes (repo shape, data location, todo schema carry-over,
vault layout, slug scoping, commit model, reasoning context handoff, status
validation, distribution, launcher). Filed here as markdown for now — revisit
where these live once there's a real system to move them into.

Dependencies follow §7 of the design doc: independent tracks except where a
real dependency exists. EPIC 0 blocks nothing else conceptually but should
land first since every other EPIC needs the repo and config to exist.

Story/task breakdowns for each EPIC live alongside this file in the same
folder: `epic-0-bootstrap.md` through `epic-5-reasoning.md`. This file stays
the source of truth for rationale and dependencies; the per-EPIC files don't
restate either.

## EPIC 0 — Repo bootstrap, config, distribution

New standalone Go repo. No product behavior yet, just the scaffolding every
other EPIC assumes.

- `go.mod`, module layout: `core/` package (trait interfaces + backends),
  `tui/` package (bubbletea), `cmd/cli` for an agent-facing JSON interface —
  pulled into v1 (see design doc §0): EPIC 5's reasoning layer and any
  orchestrated agents need to read/write tracker state directly, not just
  through the TUI.
- Config file loader (e.g. `~/.config/tracker/config.yaml`): vault path,
  dotfiles data-repo path. Fails loudly on startup if either path is missing.
- Wire the binary into the dotfiles flake as a new input/package, matching
  how `projects`/`todo`-style tools are already wired via `home.file`.
- Quick-launch entry point (zellij-sessionizer keybind or greeting hook).
- No data files created yet — that's each domain EPIC's job.

## EPIC 1 — Core + TUI shell + Todo domain

The first real vertical slice. Gated on EPIC 0.

- `TodoBackend` trait (`list`/`add`/`complete`/etc.).
- `LocalYamlBackend` reading/writing `todo/todos.yaml` in the dotfiles repo
  (path from EPIC 0's config).
- Schema carried over verbatim from `linear-trial.md`'s appendix: `id`
  (`T-<n>`, global monotonic), `title`, `project` (nullable), `status`
  (`inbox|backlog|todo|doing|done|canceled`), `cycle`, `priority`, `labels`,
  `due`, `created`, `rolled`.
- Weekly ISO cycles (`date +%G-W%V`) with automatic rollover and `rolled`
  counter; four rollovers is a cancel signal (surfaced, not auto-actioned).
- Bubbletea TUI shell: app skeleton, navigation model, styling — even though
  only the todo view exists yet, other domains plug into this shell later.
- Todo list view: browse, add, complete.
- Triage view: native bubbletea multi-select component (not a shell-out to
  `fzf`) for cycle-picking and bulk-cancelling stale items.
- Dirty/uncommitted-changes indicator in the status line, reading `git
  status` on the dotfiles data-repo path. No auto-commit — committing stays
  the user's job outside the TUI.
- Phone-capture: `brain/Inbox.md` at the vault root, plain `- [ ]` lines. A
  triage action drains it into `todos.yaml` and rewrites drained lines to
  `- [x]` **in place**, not deleted, since iCloud sync may be mid-write.

## EPIC 2 — Artifacts registry + Obsidian vault

Decoupled from EPIC 1 except for sharing the TUI shell it establishes.
Wants a small pilot (1-2 real docs) before wider migration.

- Frontmatter schema: `id` (slug, filename-derived), `type` (`poc |
  proposal | research | tool-doc | session-note`), `project` (nullable
  `[[wikilink]]`), `status` (per-type vocabulary from the design doc §2),
  `derived-from` (nullable `[[wikilink]]`), `created`.
- Vault walker: Go core parses frontmatter across the vault on demand, no
  maintained index file.
- New top-level `Projects/` and `Notes/` folders in the existing `brain/`
  vault, alongside its current `Music/`, `Work/`, `Regen/`. One
  `Projects/<name>/<name>.md` index note per entry in `projects.yaml`;
  `Notes/` is the fallback for `project: null` artifacts.
- Slug uniqueness enforced **vault-wide** at `new` time, not just within a
  project folder — required because Obsidian resolves `[[wikilink]]`s by
  shortest-unique-path across the whole vault (confirmed via the vault's
  `app.json`: no unique-filename override).
- Status validation on read: flag invalid or out-of-order status against
  each type's vocabulary (frontmatter can be hand-edited directly in
  Obsidian, so the core can't just trust it), surfaced not blocking.
- TUI views: `list --type`, `--project`, `--status`, `show <id>`, `new
  <type> <project> <slug>`, `stale --weeks N`.
- Pilot migration of 1-2 real existing docs into the new layout before
  migrating everything else (opportunistic, not blocking).

## EPIC 3 — Goals/state rollup

Gated behind EPIC 1 and EPIC 2 — nothing to roll up before todos and
artifacts exist.

- `goals.yaml`: `yearly: [{id, theme, year, notes}]` and `monthly: [{id,
  title, month, status, parent_theme, project}]` (`status` =
  `active|done|dropped|carried`).
- Deterministic rollup function (no LLM): progress per goal, open items per
  project, stale artifacts — combining `goals.yaml` + todos + artifacts +
  `projects.yaml` + people.
- TUI view rendering the rollup directly.

## EPIC 4 — People / resources

Builds alongside EPIC 3, not gated behind it (per design doc §5 — the TUI
makes this cheap enough that deferring doesn't buy anything). Only real
dependency is the EPIC 1 TUI shell.

- `people/people.yaml`: `name`, `context` (`personal|work`), `relation`
  (`collaborator|contact|mentor|...`), `notes`, `last_contact`.
- `resources/resources.yaml`: `name`, `type`
  (`equipment|reference|link|subscription`), `owner`, `notes`, `url`.
- TUI views for both, same shape as the existing `projects.yaml`/
  `tools-registry.yaml` list views.

## EPIC 5 — Reasoning layer (spawned Claude Code sessions)

Gated behind the TUI shell (EPIC 1) and at least one of artifacts/goals
(EPIC 2 or 3), since it needs something real to reason over and somewhere
to file the result.

- Headless mode: render the rollup as text, shell to `claude -p "<text>"`,
  capture stdout, render inline in the TUI.
- Interactive handoff mode: suspend the TUI's screen, exec `claude`
  interactively, resume the TUI on exit (same pattern lazygit uses for
  `$EDITOR`).
- Session-note filing: on keybind, prompt the user for `project` + `slug`
  (not auto-derived — a timestamp slug risks collisions and unhelpful
  filenames for something meant to be findable later), write the
  `session-note` artifact via EPIC 2's plumbing.
- Parallel/orchestrated work (repo maintenance, multi-step pipelines,
  fan-out research) uses Claude Code's own `Workflow`/`Agent` tools — no new
  orchestration platform. OpenHands' ACP mode is the reserved sandboxed
  backend if a task needs process/network isolation beyond git worktree
  isolation (see design doc §4/§6). Nothing here builds a sandbox integration
  yet — worktree isolation covers today's needs.
- Explicitly out of scope for this EPIC: piping session output through
  `~/code/lege` for TTS review (P2, not committed, per design doc §4); dify
  and OpenHands' native agent loop (§6 non-goals).

## EPIC 6 — Agent-fleet visibility

Gated behind the TUI shell (EPIC 1). Independent of EPIC 5 otherwise — this
watches Claude Code sessions in general, not specifically ones this tracker
spawned.

- TUI view listing every Claude Code session running or scheduled right now:
  interactive sessions, cron/cloud agents (`CronCreate`, the `schedule`
  skill), and any OpenHands-ACP sandboxes.
- State per entry at minimum: what it's running, where (repo/project),
  working/idle/blocked/failed, started when.
- Reuses `agent-status-wrap`'s state-detection approach (OSC 9;4
  progress-state escapes, not screen-text scraping) for anything running
  locally; cron/cloud entries come from Claude Code's own scheduling state
  rather than terminal scraping.
- No new scheduler or dispatch mechanism — this is read-only visibility over
  what Claude Code already runs/schedules.

## Non-goals (carried from design doc §6 — not EPICs, don't file work here)

- No Linear backend for `TodoBackend`, even though the trait makes it
  pluggable.
- No scheduled/unattended nudges (`/loop`-style background check-ins) —
  plausible future direction, not designed or built as part of this effort.
- No syncing of the personal and work artifact-registry schemas.
- Not adopting Warren, dify, or OpenHands' native agent loop. OpenHands' ACP
  mode is the one narrow exception, reserved as a sandboxed execution
  backend (EPIC 5) — not a platform this project is otherwise built on.

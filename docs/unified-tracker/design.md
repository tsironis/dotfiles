# A personal assistant: todos, artifacts, goals, people, wrapped in a TUI

One hackable system for the five things I actually do in this repo's orbit:
PoCs, dotfiles/toolchain tooling, personal side projects, technical proposals
for work, and todos. This grew from a pure git-native tracker design into a
bigger shape: a Go TUI that lives in Ghostty as the primary way I interact
with all of it, a thin CLI on the same core for a future agents layer, and an
Obsidian vault for the parts that benefit from mobile capture and native
linking. This is a design, not code, most of it gated behind the 2026-10-07
Linear trial checkpoint or opportunistic timing. Nothing here builds itself.

Three things already existed and shaped this more than starting from scratch
would have. `linear-trial.md` already designed a local `todo` CLI in
full, in its appendix, before deciding to trial Linear instead. My own
Themelio proposal, `proposal-agentic-artifact-registry.md`, already worked
out a frontmatter-as-registry pattern for filing ADRs, DDs, research
reports, and session notes at work, and `proposal-harness-prior-art.md`
surveyed four existing harnesses for what to borrow before building it. The
personal and work registries stay independent designs, though: same
inspiration, no ongoing effort to keep the two schemas in sync. Nothing in
this repo covers the personal equivalent — `projects.yaml` tracks repos, not
the content produced inside them.

## 0. Shape: a shared core, two surfaces

A single Go core implements the todo/artifact/goal/people logic as a
library, in the tuicr sense: interaction code depends on trait shapes
(`TodoBackend`, and similarly for the other domains as they need it),
not on any one storage mechanism directly. Two surfaces sit on that core:

- **The TUI** (bubbletea-style) is the primary, everyday interface. It owns
  interaction — browsing todos, artifacts, goals, people, and triggering
  reasoning (see §4). This is where the old design's separate `todo`,
  `artifacts`, and `state` shell scripts converge: they stop being
  standalone user-facing tools and become internal calls into the core.
- **A CLI** on the same core, agent-facing from v1 rather than deferred: §4's
  reasoning layer and any orchestrated agents (parallel repo work, fan-out
  research) need to read and write tracker state themselves, not just a human
  via the TUI. JSON output by default, human-readable with a flag. Whether
  this is a plain CLI or also an MCP server is still open, but the "wait for
  an actual agent consumer" reason to defer it no longer holds — that
  consumer exists now.

Language is Go. It gives a single static binary, a strong TUI ecosystem
(bubbletea), and a clean way to expose both a library and a CLI without the
composition problems bash/`yq` scripts run into once something else needs to
call them as more than a subprocess.

## 1. Tasks

`linear-trial.md`'s appendix designed a local `todo` CLI: weekly ISO
cycles with rollover, `fzf`-driven triage. That data shape carries over, but
the build trigger changes. Storage sits behind a `TodoBackend` trait
(`list`/`add`/`complete`/etc.), with a `LocalYamlBackend` (`todo/todos.yaml`)
as the implementation that ships first. This is the same pattern tuicr uses
for its VCS and forge backends: the interaction logic depends on the trait
shape, not on shelling out to one specific tool.

That abstraction removes the Linear trial as a hard gate. The original design
waited for the trial's outcome before building anything; now the trait plus
`LocalYamlBackend` gets built regardless, since it's core to what the TUI
does. A `LinearBackend` becomes optional future work, pluggable behind the
same trait, only if the trial or something later actually calls for it. No
outcome of the trial blocks building the local backend.

`todos.yaml`, like `goals.yaml` and `projects.yaml` below, stays git-native
in this repo. None of the three move into Obsidian — they're written
programmatically by the core often (toggling a todo done, adding an item),
and git's atomic commits avoid the conflicted-copy risk that comes with a
program repeatedly rewriting a structured file under Obsidian's own sync.
Obsidian's sync is built for occasional hand-edited prose, which fits
artifacts and inbox capture (§2), not a file mutated many times a day.

## 2. Artifacts

Adapts `proposal-agentic-artifact-registry.md`'s pattern to personal use,
scaled down, but the storage location changes from the original tracker
design: **Obsidian becomes the primary home for every personal artifact**,
project-linked or not, rather than files scanned in place inside each
project's own repo. The work version's registry exists because multiple
agents and people file concurrently and can collide (the ADR `0019`/`0021`
double-assignment that proposal cites); solo use doesn't have that failure
mode, so the merge-time numbering ceremony doesn't carry over either.

**Frontmatter is still the registry**, same core lesson as the work version:

- `id` — slug, filename-derived. Filename *is* identity, per the opencode
  lesson in `proposal-harness-prior-art.md`: don't invent a second
  identifier a rename can silently orphan.
- `type` — `poc | proposal | research | tool-doc | session-note`.
- `project` — nullable, an Obsidian `[[wikilink]]` to that project's index
  note (see below), not a plain string. Null is for artifacts that are
  genuinely cross-cutting, not about any one project.
- `status` — per-type vocabulary, same 3-stage shape as the work version's
  decision gate but worded for what actually happens to each type:
  - `proposal`: `draft → proposed → accepted`
  - `research`: `draft → proposed → concluded`
  - `tool-doc`: `draft → proposed → published`
  - `poc`: `draft → filed`
  - `session-note`: `filed`, no gate at all — a synopsis doesn't need
    review, it needs to be findable.
- `derived-from` — lineage, nullable, also an Obsidian `[[wikilink]]` to the
  artifact it came from.
- `created`.

**Obsidian vault layout.** Each project in `projects.yaml` gets a folder
(`Projects/<name>/`) with one index note matching the folder name
(`<name>.md`). That index note is what `[[project-name]]` resolves to from
any artifact's frontmatter, wherever that artifact physically sits, and it's
the natural home for that project's own artifacts. Artifacts with no project
default to a top-level `Notes/` (or similar) area of the vault, tagged
`project: null`, same fallback role the old `docs/notes/` directory played.

Using real wikilinks instead of plain slugs is a deliberate coupling to
Obsidian: it means `derived-from` and `project` show up in Obsidian's native
graph and backlinks view for free, at the cost of the frontmatter no longer
being tool-agnostic. Combined with using Obsidian's own sync (not git) for
the whole vault, this is a second, related exception to the git-native
principle — accepted for artifacts and capture specifically, not extended to
tasks or goals (§1).

**Migration.** Existing artifacts already scattered across project repos and
the old `docs/notes/` fallback get moved into the vault eventually. This
reverses the original tracker design's stance of leaving files where they
already live — that made sense when the registry was just a script walking
repos in place, it doesn't once Obsidian is the actual primary home.
Migration is opportunistic cleanup, not a blocking prerequisite for anything
else here.

**Generated index, not maintained**, the same core lesson both of my
Themelio docs land on from different angles: the Go core walks the vault's
frontmatter and the TUI/CLI render views on demand (`list --type`, `--project`,
`--status`, `show <id>`, `new <type> <project> <slug>`, `stale --weeks N`).
No separate index file kept by hand.

## 3. Goals / state

"Where am I, where am I heading" — bullet-journal yearly/monthly goals,
rolled up against everything in §1 and §2.

- **`goals.yaml`** — flat-YAML registry, same family as `projects.yaml`,
  git-native, same reasoning as §1. Two tiers:
  - `yearly: [{id, theme, year, notes}]`
  - `monthly: [{id, title, month, status, parent_theme, project}]`, where
    `month` is `YYYY-MM`, `status` is `active | done | dropped | carried`,
    `parent_theme` nullably links a yearly entry, and `project` nullably
    links `projects.yaml`. `carried` makes the bullet-journal migration
    ritual an explicit status instead of a manual copy-paste into next
    month's page.
- **The rollup** — deterministic, no LLM, a Go core function rather than a
  standalone `state` script. Rolls up `goals.yaml` + todos + artifacts +
  `projects.yaml` + people (§5) into plain data: progress per goal, open
  items per project, stale artifacts. The TUI renders it directly, and it
  doubles as the context handed to a spawned Claude Code session (§4) when
  the reasoning step needs it.

The old design's `/review` Claude Code skill goes away as a separate
mechanism — reasoning moves into the TUI itself, see §4.

## 4. Reasoning: spawning Claude Code

The TUI can trigger real Claude Code sessions as child processes, rather
than reimplementing reasoning itself or delegating to a separate skill
invoked from outside the TUI. Two modes, chosen per task:

- **Headless**, for quick rollups and summaries: shell out to `claude -p
  "..."`, capture stdout, render it inline in the TUI. No screen handoff, it
  reads as one continuous app.
- **Interactive handoff**, for open-ended review or research: suspend the
  TUI's screen, exec `claude` interactively in the terminal, resume the TUI
  when that session exits. Same pattern lazygit uses for opening `$EDITOR`.

Nothing a spawned session produces is filed automatically. The user reviews
the output and decides via a keybind whether it's worth saving as a
`session-note` artifact (§2) — matches the work proposal's "session notes
just need to be findable" stance, but keeps the human gate on what's worth
finding in the first place. A future idea, low priority (P2, not committed):
pipe a session's output through `~/code/lege` for a TTS review pass before
deciding to file it.

**Parallel/orchestrated work.** Grilling surfaced a real want — parallel
repo maintenance, multi-step pipelines, fan-out research — but no new
platform for it. Claude Code's own `Workflow` tool (`pipeline()`/`parallel()`
combinators over `agent()`) and `Agent` tool (concurrent dispatch,
`isolation: "worktree"`) already cover all three shapes, running under the
existing subscription. dify and OpenHands' native agent loop are explicitly
out per §6. The one piece kept in reserve: **OpenHands' ACP mode** as a
sandboxed execution backend — it spawns the real `claude` CLI and reuses the
subscription login, so it's available for whichever future task actually
needs process/network isolation beyond what git worktree isolation already
gives. Not built now; worktree isolation covers today's needs.

**Agent-fleet visibility.** A TUI view showing every Claude Code session
running or scheduled right now — interactive, cron/cloud (`CronCreate`, the
`schedule` skill), or an OpenHands-ACP sandbox — replaces the earlier idea of
a separate sibling tool extending `agent-status-wrap`. It lives in the
tracker's TUI because it's one more thing to glance at alongside todos,
goals, and artifacts, not because the tracker's domain model needs it.
Unattended/scheduled execution itself reuses Claude Code's own cron/cloud
primitives — no new scheduler gets built here.

## 5. People / resources

No longer gated on "artifacts and todo proving insufficient first" — builds
alongside artifacts and goals as part of the initial TUI scope, since the
TUI makes a people/resources view cheap enough that deferring it doesn't buy
much. Flat YAML registries in the exact shape of `projects.yaml`/
`tools-registry.yaml`, git-native like todos and goals:

- `people/people.yaml`: `name`, `context` (`personal|work`), `relation`
  (`collaborator|contact|mentor|...`), `notes`, `last_contact`.
- `resources/resources.yaml`: `name`, `type`
  (`equipment|reference|link|subscription`), `owner`, `notes`, `url`.

## 6. Non-goals

- Not adopting Warren, dify, or OpenHands' own native agent loop. All three
  are agent-dispatch/orchestration platforms, orthogonal to this problem —
  same conclusion the Themelio proposal reaches for Warren, and confirmed by
  grilling for dify (a hosted app-builder for exposing agents as services,
  API-key billed, no capability beyond what §4's Workflow/Agent primitives
  already give this project under the existing Claude subscription) and for
  OpenHands' native mode (also API-key billed — as of January 2026 Anthropic
  blocks Claude subscription auth from any client other than Claude
  Code/claude.ai, so native mode means paying twice). The one exception is
  OpenHands' **ACP mode**, which spawns the real `claude` CLI as a subprocess
  and reuses the existing subscription login — that's in scope narrowly, see
  §4.
- Not keeping the personal and work registry schemas in sync. Same
  inspiration, independent evolution.
- Not building scheduled/unattended nudges yet, but no longer ruled out the
  way the original design ruled it out. Now that the TUI can spawn real
  Claude Code sessions, background check-ins (a `/loop`-style nudge, the
  `schedule` skill) are a plausible future direction — just not designed or
  built as part of this effort.
- Not building a Linear backend. The `TodoBackend` trait makes it pluggable
  later, but nothing here commits to writing one.

## 7. Trigger and build order

Independent tracks. No forced sequence except where a real dependency
exists.

- **Core + TUI shell, todo (`LocalYamlBackend`)** — no longer gated on the
  Linear trial outcome. The trait abstraction means the trial's result no
  longer decides whether this gets built at all, only whether a
  `LinearBackend` ever gets added alongside it later.
- **Artifacts registry + Obsidian vault** — decoupled from the Linear trial
  entirely. No fixed date, build it opportunistically whenever untracked
  PoCs/proposals actually start costing time. Wants its own small pilot on
  1-2 real docs, including the project-folder/wikilink layout, before
  migrating everything else in.
- **Goals/state rollup** — gated behind todo and artifacts existing, since
  the rollup has nothing to compute over before that.
- **People/resources** — builds alongside artifacts and goals, not gated
  behind them proving insufficient anymore.
- **Reasoning layer (spawned Claude Code sessions)** — wants the TUI shell
  and at least one of artifacts/goals in place first, since it needs
  something real to reason over and somewhere to file the result.

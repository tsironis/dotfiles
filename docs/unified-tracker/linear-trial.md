# Linear trial

**Started:** 2026-08-26 · **Checkpoint:** 2026-10-07 · **Status:** running

Trialling [Linear](https://linear.app) on the free tier as the cross-project
todo system, instead of building a local `todo` CLI. Build nothing until the
checkpoint.

## Why

Work is spread across tens of repos plus life admin, with no single place to see
what is open and nothing forcing a weekly narrowing. `projects/projects.yaml`
tracks the repos, but it is a registry of projects rather than of work.

A local `todo` CLI was designed first, in the shape of `projects`: a YAML store,
a vault note for phone capture, `fzf` flows, weekly cycles with rollover. Then a
better question came up. Linear already implements exactly these mechanics, it
has an iOS app, and the free tier might be enough.

Building the local tool bets that the weekly cycle ritual will stick, and no
amount of design verifies that. Six weeks of real use does. If the ritual holds
and the free ceiling or the cloud dependency then grates, we port with real data
and know which mechanics were actually used. If it does not hold, nothing was
wasted.

## What Linear is worth copying for

Five mechanics carry the value for one person. The rest of the product is team
overhead (assignees, estimates, velocity, dashboards, comments, project updates,
initiatives, SLAs, dependency graphs) and should be ignored.

1. **Triage as a separate state.** Capture without deciding, decide later in one
   pass.
2. **One flat item namespace** with project as an attribute, so cross-project
   views are free.
3. **Weekly cycles with rollover.** The forced narrowing, plus a rollover count
   that names cancel candidates.
4. **A small status enum including `canceled`.** Kill work without lying about
   it.
5. **Backlog decay.** Flag and bulk-cancel stale items so the store does not
   become a graveyard.

## What the research found

- **No first-party Linear CLI exists.** Linear ships a hosted MCP server, a
  GraphQL API, and a TypeScript SDK. The community filled the gap with roughly a
  dozen CLIs, most aimed at coding agents.
  [schpet/linear-cli](https://github.com/schpet/linear-cli) looks the most
  maintained: API-key auth, full read/write on issues, teams, projects, and
  milestones, and it is git-branch aware. Declared in
  `hosts/darwin/modules/apps.nix` as the `linear` brew from `schpet/tap`.
- **Claude Code has a Linear MCP connector**, so agent access costs nothing
  extra.
- **Free tier is 250 issues, 2 teams, 10MB uploads**, with API and webhook
  access. Paid starts at $10/user/month.
- Two teams maps cleanly onto the `owner` enum in `projects.yaml`, and projects
  are unlimited, so tens of projects is not the binding constraint. The 250 is.

### The one assumption to verify

Linear's own docs say only "if you have over 250 issues, you will no longer be
able to create new issues" without defining which issues count. Third-party
pricing writeups consistently claim the 250 counts _active_ issues, that
archived ones do not count, and that auto-archive-after-completion is
configurable. That claim is not from Linear. **Confirm it in the app.** It is
the riskiest assumption in the whole trial.

## Setup

- [x] `make darwin`, then `command -v linear`
- [x] Personal API key at Linear security settings, then `linear auth login`
- [x] Two teams in workspace `tsironis-personal`: `PER Personal` and
      `WOR Work`, matching the `owner` enum in `projects.yaml`
- [x] **Cycles and Triage enabled on both teams** (`cycleDuration: 1`,
      `cycleStartDay: 1`, `triageEnabled: true`). Both are opt-in and off by
      default, so this step is load-bearing — without it the central mechanic of
      the trial does not exist
- [x] One workspace **label** per repo: `dotfiles`, `wyteboard`, `themelio`,
      `kaloupi-verse`, created from `projects.yaml` so the names cannot drift.
      Labels, not Linear projects — see the mapping below
- [ ] Confirm what the 250 limit actually counts. Leave `autoArchivePeriod` at
      Linear's default of 6 months — see below for why it is not a setup step
- [ ] iOS app installed and signed in, with capture tested on day one. This is
      the whole reason Linear won over the local build
- [ ] Install the `linear-cli` Claude Code skill and compare its context cost
      against the MCP server — tracked as
      [PER-5](https://linear.app/tsironis-personal/issue/PER-5/install-and-evaluate-the-linear-cli-claude-code-skill):
      `claude plugin marketplace add schpet/linear-cli` then
      `claude plugin install linear-cli@linear-cli`
- [ ] Only if the skill proves insufficient, authenticate the Linear MCP
      connector in Claude Code

Life admin stays in the vault as plain `- [ ]` markdown for the duration. Linear
holds project work only. Whether that split is annoying is one of the things the
trial measures.

## How the model maps

Linear's docs define a project as "units of work that have a clear outcome or
planned completion date". Repos are long-lived and never complete, so mapping a
repo onto a Linear project fights the model: every one would sit permanently at
"In Progress", target dates and the progress graph would be meaningless, and
project updates would be noise.

| Local                                             | Linear                                                 |
| ------------------------------------------------- | ------------------------------------------------------ |
| `owner: personal` / `work` in `projects.yaml`     | the two teams (the free-plan limit)                    |
| a repo (`dotfiles`, `themelio`)                   | a **label**, defined at workspace level                |
| a finite effort inside a repo (a migration, a v1) | a **project**, where the progress graph earns its keep |
| a todo                                            | an issue                                               |

So the per-repo view is `linear issue list --label dotfiles`, and projects are
reserved for work that actually ends.

### Is free enough?

Yes, on the numbers. The pricing table caps exactly three things: **250 issues,
2 teams, 10MB uploads**. Projects, cycles, triage, initiatives, labels, API and
webhook access, and MCP access all sit in the Core row with no cap. So unlimited
projects and labels, and the 250 is the only ceiling. More than 250 _open_ items
for one person is a symptom rather than a capacity problem, which is exactly
what Linear's own philosophy argues.

### The 250 ceiling is not a day-one problem

Auto-archiving is the lever for staying under 250, but it is one to pull when the
count climbs rather than a setup step. The field is `autoArchivePeriod`, in
**months** (Float, `0` disables), and both teams sit at Linear's default of `6`.

The arithmetic: at 15 issues a week you generate roughly 65 a month, so with
6-month retention the active count drifts toward 250 somewhere around month four
of sustained use. The trial runs six weeks and will land near 90. Nowhere close.
Linear's default is presumably tuned for teams far larger than one person, and
for one person it is fine.

There is a mild argument for keeping 6 months specifically *during* the trial:
the October review wants maximum visible history of what actually got completed,
and a 1-month setting would archive the first weeks out of the default views
right when you want to look back at them. Archiving is reversible and archived
issues stay searchable, so the effect is small, but it points the same way.

Check the count whenever you wonder:

```sh
linear api '{ issues { nodes { id } } }' | jq '.data.issues.nodes | length'
```

If it climbs past roughly 150, shorten retention then:

```sh
linear api 'mutation { teamUpdate(id: "<team-id>", input: { autoArchivePeriod: 1 }) { success } }'
```

### The structural cost, worth knowing up front

**Cycles are team-specific, and Linear cannot show more than one team's cycles
at once.** Personal and work will be two separate cycle views permanently. That
directly undercuts the "one place to see everything" goal, and whether it
matters in practice is one of the things this trial is measuring. Sub-teams
would not help even in principle, since they start at the Basic plan.

## MCP and token overhead

The Linear MCP server is remote and hosted, OAuth 2.1, added with:

```sh
claude mcp add --transport http linear-server https://mcp.linear.app/mcp
```

then `/mcp` in a session to authenticate. In Claude Code, MCP tools are
**deferred**: only tool names sit in context and full schemas load on demand, so
the standing cost is a list of names rather than a wall of JSON schemas.

The lever if it still costs too much: `https://mcp.linear.app/mcp/readonly`
"only ever exposes read tools", roughly halving the tool count. Requesting only
the `read` OAuth scope on the standard endpoint achieves the same thing.

To measure it rather than guess: run `/context` in a fresh session before adding
the server and after, and diff the tool-definition line. Tracked as the trial's
first issue, which doubles as a test of the capture-and-triage loop.

## Two CLI findings that change the plan

**`.linear.toml` already does the `$PWD` inference.** `linear config` generates a
per-repo config file, checked at `./.linear.toml`, `<repo-root>/.linear.toml`,
`<repo-root>/.config/linear.toml`, then `~/.config/linear/linear.toml`. It sets
`team_id`, `workspace`, sort order, and self-assignment defaults. That removes the
single biggest reason the thin wrapper existed. It does **not** support a default
label, so auto-tagging an issue with its repo label is the only piece a wrapper
would still add.

**The CLI ships a Claude Code skill, which is a lighter agent path than MCP.**

```sh
claude plugin marketplace add schpet/linear-cli
claude plugin install linear-cli@linear-cli
```

A skill teaching Claude to drive the CLI costs no MCP tool schemas at all, and it
includes instructions for hitting the GraphQL API directly for anything the CLI
does not cover. Worth trying before the MCP server, and it reframes the overhead
question from "how much does MCP cost" to "do we need MCP at all".

## What the trial measures

Three questions, and only the first really matters.

1. **Did the Monday cycle pick actually happen?** Count the weeks it did. Fewer
   than four out of six and the ritual did not stick, which means the local
   build would have been a tool for a habit that does not exist. This is the
   entire reason for trialling instead of building.
2. **Did phone capture get used?** If issues created from iOS are near zero, the
   mobile argument that pushed us toward Linear was wrong, and the local
   plaintext build becomes much more attractive.
3. **Where did the friction land?** Specifically: active-issue count against the
   250 ceiling, how often you wanted `grep` or `git log` over the tracker,
   whether the two-team split held and whether two separate cycle views was a
   real problem, whether not knowing the current project from `$PWD` was
   irritating enough to want a wrapper, and whether life admin living elsewhere
   caused things to be dropped.

### Log

Append observations here as they happen, dated. Cheap now, decisive on
2026-10-07.

- `2026-08-26` — trial started, `linear` declared in `apps.nix`.
- `2026-08-26` — onboarded existing plan/todo content from three actively-worked
  repos: kaloupi-verse (6 epics from `docs/planning/epics/`), themelio (5 open
  phases from the ADR-0012/0013 remaining-work plan, plus the CLI spec, the
  planning-artifact-taxonomy realignment, and the Pharos planning proposal),
  splinter (6 slices from `CLAUDE.md`, new `splinter` label added, and the repo
  added to `projects.yaml` to keep the label-from-registry convention intact).
  20 issues total: PER-6..PER-17, WOR-1..WOR-8. wyteboard was considered but
  skipped — Phase 6 is already closed and nothing in the repo states a next
  phase, so there was no open item to lift rather than one to invent.
- `2026-08-26` — set each team's Home/Overview page to list its projects with a
  short description. Discovered the **255-character limit on team
  `description` is UI-only**: the GraphQL API accepted a description over
  1,000,000 characters via `teamUpdate`, but the web app blocks editing past
  255 with "Description cannot be longer than 255 characters." Documents are
  the field meant for longer content instead — server-enforced at **250,000
  characters** (confirmed by pushing `documentCreate`/`documentUpdate` past
  that point and reading back the validation error). Fixed by shrinking both
  descriptions to a one-liner and moving the full per-project list into a
  "Projects" document per team (PER, WOR), so the description stays editable
  in the UI going forward.
- `2026-08-26` — re-checked the 7 dropped repos more carefully (grepped commit
  history and doc bodies for "next steps"/"remaining" prose, not just
  filenames) and found two real misses: **midi-conversion** has a ranked
  backlog in `NOTES.md` ("## 12. Next steps, roughly ranked", 8 items,
  PER-18..PER-25) and **plantcal** has a 3-step recommended path at the end of
  `garden-planner-survey.md` (PER-26..PER-28). Both got a label,
  `projects.yaml` entry, and their bullet added to the PER Projects doc.
  **afterwords.github.io** turned out not to be missing anything — it already
  runs a live GitHub Issues tracker (79 open issues across epics/tracks) — so
  left alone rather than duplicated into Linear. broadway (one untracked
  "Phase 1" commit, no roadmap), zmk-config-charybdis-mini-wireless (BLE
  tuning only, issues disabled, `.bmad` is template boilerplate), lege (no
  plan doc), and habitat-commons (empty repo, last touched April) confirmed to
  still have nothing to lift.

## The three outcomes

- **Ritual stuck, Linear fits.** Add a thin wrapper, roughly 80 lines: infer
  team and project from `$PWD` via `projects find-path`, add an open-cycle line
  to `zellij-sessionizer/greet.sh`, delegate everything else to `linear`. Accept
  $10/month when the ceiling arrives.
- **Ritual stuck, Linear grates.** Port to the local design below, now with six
  weeks of data showing which fields and commands were actually touched. Linear
  exports via its API.
- **Ritual did not stick.** Stop. Drop the brew entry and the registry line.
  Capture stays in the vault, and the problem was never the tool.

## Appendix: the local design, if we port later

Recorded so the decisions already made are not relitigated.

- **Store:** `todo/todos.yaml` in this repo, read and written with `yq`,
  matching every other tool here (the repo has no JSONL or sqlite anywhere).
  `todo/archive.yaml` for retired items so the live file stays fast.
- **Phone capture:** `brain/Inbox.md` at the vault root, plain `- [ ]` lines.
  `todo triage` drains it and rewrites drained lines as `- [x]` **in place
  rather than deleting them**, because iCloud can be mid-sync and you may be
  typing on the phone during a drain.
- **Cycles:** weekly ISO (`date +%G-W%V`, verified on this macOS `date`), with
  automatic rollover and a `rolled` counter. Four rollovers is a cancel signal.
- **Scope:** everything, `project` nullable so life admin fits.
- **Fields:** `id` (global monotonic `T-<n>`, not per-project, since `project`
  is optional), `title`, `project`, `status`
  (`inbox|backlog|todo|doing|done|canceled`), `cycle`, `priority`, `labels`,
  `due`, `created`, `rolled`.
- **Interaction:** plain stdout for reads, `fzf --multi` for triage, cycle
  picking, and bulk-cancelling stale items. `fzf` is already Nix-managed in
  `hosts/darwin/modules/apps.nix`.
- **Conventions:** copy `projects/projects.sh` structurally, including its
  symlink-chain preamble and the `in_list`/`validate` enum helpers. One thing
  `projects.sh` gets away with that a free-text title cannot: pass strings via
  `strenv()` rather than interpolating into the concatenated `yq` filter.
- **Wiring:** one `home.file.".local/bin/todo"` block in `home/darwin.nix`,
  copying the `projects` block. No `executable = true`, since it does not
  combine with `mkOutOfStoreSymlink`, so `chmod +x` in the repo instead.
- **Greeting hook:** `zellij-sessionizer/greet.sh`, inside the tracked-project
  branch. That file runs `set -uo pipefail` without `-e` and must never fail
  into a broken shell, so swallow errors.

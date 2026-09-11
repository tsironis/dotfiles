# EPIC 1 — Core + TUI shell + Todo domain

Rationale and dependencies: see `epics.md`. Gated on EPIC 0. The first real
vertical slice.

## Story: TodoBackend trait

- [ ] Define `TodoBackend` trait/interface: `list`, `add`, `complete`, plus
      whatever else the todo list and triage views need (cancel, edit
      cycle/priority).
- [ ] Define the todo item schema (carried over verbatim from
      `linear-trial.md`'s appendix): `id` (`T-<n>`, global monotonic),
      `title`, `project` (nullable), `status`
      (`inbox|backlog|todo|doing|done|canceled`), `cycle`, `priority`,
      `labels`, `due`, `created`, `rolled`.

## Story: LocalYamlBackend

- [ ] Implement `LocalYamlBackend` reading/writing `todo/todos.yaml` in the
      dotfiles repo, path sourced from EPIC 0's config loader.
- [ ] Implement weekly ISO cycle computation (`date +%G-W%V` equivalent in
      Go).
- [ ] Implement automatic cycle rollover: bump `rolled` counter on
      un-completed items carried into a new cycle.
- [ ] Surface (not auto-action) a signal when an item's `rolled` counter
      hits four — a cancel candidate, decided by the user.
- [ ] Tests: rollover increments `rolled` correctly across cycle
      boundaries; four-rollover signal fires at the right threshold.

## Story: Bubbletea TUI shell

- [ ] App skeleton: entry point, top-level model/update/view loop.
- [ ] Navigation model — even with only the todo view existing yet, shape
      it so other domains (EPIC 2–4) can plug in views later.
- [ ] Base styling (colors, layout primitives) shared across future views.

## Story: Todo list view

- [ ] Browse view: list todos, filterable/sortable by status or cycle.
- [ ] Add flow: create a new todo item from the TUI.
- [ ] Complete flow: mark an item done from the TUI.

## Story: Triage view

- [ ] Native bubbletea multi-select component (not a shell-out to `fzf`).
- [ ] Cycle-picking: bulk-assign selected items to a cycle.
- [ ] Bulk-cancel: mark selected stale items canceled.

## Story: Dirty-state indicator

- [ ] Status-line component reading `git status` on the dotfiles data-repo
      path.
- [ ] Render a dirty/uncommitted-changes indicator when applicable.
- [ ] No auto-commit — confirm the TUI never calls `git commit`; committing
      stays the user's job outside the TUI.

## Story: Phone-capture inbox

- [ ] Define `brain/Inbox.md` at the vault root as the phone-capture
      target, plain `- [ ]` lines.
- [ ] Triage action: parse `Inbox.md`, drain entries into `todos.yaml`.
- [ ] Rewrite drained lines to `- [x]` **in place** (not deleted) — required
      because iCloud sync may be mid-write on the file.
- [ ] Test: draining is idempotent / safe to re-run against a partially
      synced file.

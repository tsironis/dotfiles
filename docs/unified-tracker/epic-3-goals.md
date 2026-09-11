# EPIC 3 — Goals/state rollup

Rationale and dependencies: see `epics.md`. Gated behind EPIC 1 and EPIC 2 —
nothing to roll up before todos and artifacts exist.

## Story: goals.yaml schema and storage

- [ ] Define `yearly: [{id, theme, year, notes}]`.
- [ ] Define `monthly: [{id, title, month, status, parent_theme, project}]`
      with `status` = `active|done|dropped|carried`.
- [ ] Implement read/write for `goals.yaml`, git-native like `todos.yaml`.

## Story: Deterministic rollup function

- [ ] Implement a Go core function combining `goals.yaml` + todos +
      artifacts + `projects.yaml` + people into rollup data.
- [ ] Compute progress per goal.
- [ ] Compute open items per project.
- [ ] Compute stale artifacts.
- [ ] Explicitly no LLM involvement in this function — pure deterministic
      logic, keep it that way even if the reasoning layer (EPIC 5) later
      consumes the output.

## Story: TUI rollup view

- [ ] Render the rollup function's output directly in a TUI view.

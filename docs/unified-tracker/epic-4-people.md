# EPIC 4 — People / resources

Rationale and dependencies: see `epics.md`. Builds alongside EPIC 3, not
gated behind it. Only real dependency is the EPIC 1 TUI shell.

## Story: people.yaml registry

- [ ] Define schema: `name`, `context` (`personal|work`), `relation`
      (`collaborator|contact|mentor|...`), `notes`, `last_contact`.
- [ ] Implement read/write for `people/people.yaml`.
- [ ] TUI list view, same shape as the existing `projects.yaml` list view.

## Story: resources.yaml registry

- [ ] Define schema: `name`, `type`
      (`equipment|reference|link|subscription`), `owner`, `notes`, `url`.
- [ ] Implement read/write for `resources/resources.yaml`.
- [ ] TUI list view, same shape as the existing `tools-registry.yaml` list
      view.

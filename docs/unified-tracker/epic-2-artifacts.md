# EPIC 2 — Artifacts registry + Obsidian vault

Rationale and dependencies: see `epics.md`. Decoupled from EPIC 1 except for
sharing the TUI shell it establishes. Wants a small pilot (1-2 real docs)
before wider migration.

## Story: Frontmatter schema

- [ ] Define frontmatter fields: `id` (slug, filename-derived), `type`
      (`poc | proposal | research | tool-doc | session-note`), `project`
      (nullable `[[wikilink]]`), `status` (per-type vocabulary, see design
      doc §2), `derived-from` (nullable `[[wikilink]]`), `created`.
- [ ] Encode the per-type status vocabularies from the design doc: proposal
      (`draft → proposed → accepted`), research (`draft → proposed →
      concluded`), tool-doc (`draft → proposed → published`), poc (`draft →
      filed`), session-note (`filed` only).

## Story: Vault walker

- [ ] Go core function that parses frontmatter across the vault on demand
      (no maintained index file).
- [ ] Handle malformed/missing frontmatter gracefully (surface as a
      validation issue, not a crash).

## Story: Vault layout

- [ ] Create `Projects/` and `Notes/` top-level folders in the existing
      `brain/` vault, alongside `Music/`, `Work/`, `Regen/`.
- [ ] Implement `Projects/<name>/<name>.md` index-note creation, one per
      entry in `projects.yaml`.
- [ ] Route artifacts with `project: null` to `Notes/` as the fallback.

## Story: Slug uniqueness enforcement

- [ ] Implement vault-wide (not per-project-folder) slug uniqueness check
      at `new` time.
- [ ] Confirm this matches Obsidian's shortest-unique-path wikilink
      resolution (already verified via the vault's `app.json`: no
      unique-filename override — no further research needed, just
      implement).

## Story: Status validation on read

- [ ] Validate each artifact's `status` against its type's vocabulary when
      read.
- [ ] Flag invalid or out-of-order status transitions.
- [ ] Surface flags in the TUI, non-blocking — hand-edited frontmatter in
      Obsidian must never be silently trusted, but also never block
      reading.

## Story: TUI views

- [ ] `list --type`, `list --project`, `list --status` filters.
- [ ] `show <id>` detail view.
- [ ] `new <type> <project> <slug>` creation flow (runs the slug-uniqueness
      check above).
- [ ] `stale --weeks N` view.

## Story: Pilot migration

- [ ] Pick 1-2 real existing docs to migrate first.
- [ ] Migrate them into the new `Projects/<name>/` or `Notes/` layout.
- [ ] Confirm wikilinks resolve correctly in Obsidian post-migration before
      treating the pilot as validated.
- [ ] Note: migrating everything else is opportunistic, not blocking —
      don't schedule it as a task here.

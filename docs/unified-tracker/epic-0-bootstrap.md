# EPIC 0 — Repo bootstrap, config, distribution

Rationale and dependencies: see `epics.md`. Blocks nothing conceptually but
should land first since every other EPIC needs the repo and config to exist.

## Story: Go module scaffolding

- [ ] Initialize `go.mod` for the new standalone repo.
- [ ] Create `core/` package directory (empty, trait interfaces land here in
      EPIC 1+).
- [ ] Create `tui/` package directory (empty, bubbletea shell lands here in
      EPIC 1).
- [ ] Create `cmd/cli` package directory (empty, agent-facing JSON commands
      land here as each domain EPIC builds — pulled into v1 per design doc
      §0, not deferred).

## Story: Config loader

- [ ] Define the config file schema: vault path, dotfiles data-repo path.
- [ ] Implement loader reading `~/.config/tracker/config.yaml`.
- [ ] Fail loudly (non-zero exit, clear error message) if the config file
      itself doesn't exist.
- [ ] Fail loudly (non-zero exit, clear error message) if either the vault
      path or the dotfiles data-repo path from the config is missing on disk.
- [ ] Write a test covering the missing-config-file failure case.
- [ ] Write a test covering the missing-path (vault or data-repo) failure
      case.

## Story: Dotfiles flake integration

- [ ] Add the new repo as a flake input in the dotfiles flake (`flake.nix`).
- [ ] Wire the built binary as a `home.file` package entry, following the
      existing pattern for `projects`/`tools-registry` in
      `home/darwin.nix` (symlink via `mkOutOfStoreSymlink`, or the
      build-output equivalent for a compiled Go binary rather than a shell
      script).
- [ ] Run a flake rebuild and confirm it completes without error.
- [ ] Confirm the binary is present and executable on `$PATH` after the
      rebuild.

## Story: Quick-launch entry point

- [ ] Decide: zellij-sessionizer keybind, greeting-hook launcher, or both.
- [ ] Implement the chosen keybind and/or hook to invoke the binary.
- [ ] Manually trigger the launch path and confirm the binary starts.
- [ ] Confirm no data files are created by any of the above — that's each
      domain EPIC's job, not EPIC 0's.

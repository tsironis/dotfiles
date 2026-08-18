# tools-registry

Manually curated index of available CLI tools — a quick answer to "what
utilities do I have and how are they managed?"

```sh
tools-registry list
tools-registry list --source homebrew
tools-registry list --search git
```

Symlinked to `~/.local/bin/tools-registry` by `home/darwin.nix`.

Entries in `tools-registry.yaml` are added **by hand** — this is intentionally
not auto-discovered from PATH or the Nix config. Auto-detection would pick up
every Homebrew formula and nixpkgs package rather than just the ones worth
knowing about, and couldn't attach a meaningful one-line description. When you
add a new personal tool (or start relying on a new third-party CLI), add an
entry here.

## Schema

Each entry in `tools-registry.yaml`:

| Field | Notes |
|-------|-------|
| `name` | Command name |
| `description` | One-line summary of what it does |
| `source` | Fixed enum: `nix-managed`, `homebrew`, `go-install`, `npm-global` |

## Prerequisites

- [`yq`](https://github.com/mikefarah/yq) on PATH — already installed via
  Homebrew, see `hosts/darwin/modules/apps.nix`.

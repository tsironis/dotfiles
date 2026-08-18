# projects

Thin CLI over `projects.yaml` — a personal/work project tracker.

```sh
projects list                              # everything
projects list --category poc               # filter by category
projects list --owner work --status active # combine filters
projects show dotfiles
projects add                               # run from inside the project dir: name/path/owner all inferred
projects add --category poc                # same, but tag a category
projects add --name foo --path ~/code/foo --category poc --owner personal
projects touch dotfiles                    # bump last_touched to today
projects find-path /some/dir               # exact-match lookup (used by zellij-sessionizer's greeting)
projects categories                        # print valid category values
projects statuses                          # print valid status values
```

Symlinked to `~/.local/bin/projects` by `home/darwin.nix`.

## Schema

Each entry in `projects.yaml`:

| Field | Required | Notes |
|-------|----------|-------|
| `name` | no (defaults to `path`'s basename) | Unique identifier, used by `show`/`touch`/`add` |
| `path` | no (defaults to `$PWD`) | Absolute filesystem path |
| `category` | no (may be blank) | Fixed enum when set: `poc`, `quality-of-life`, `product`, `other` |
| `owner` | no (inferred, see below) | Fixed enum: `personal`, `work` |
| `status` | no (defaults `active`) | Fixed enum: `active`, `paused`, `done`, `abandoned` |
| `description` | no | One-line free text |
| `repo` | no | Remote URL |
| `last_touched` | no (defaults to today) | `YYYY-MM-DD`, **manually maintained** — bump it with `projects touch <name>` when you work on something |

`add`'s defaults are geared toward running it from inside the project
directory: `--path` defaults to `$PWD`, `--name` to that path's basename.
`--owner` is inferred from the path prefix — `$HOME/code/...` → `personal`,
`$HOME/geant/...` → `work` — matching the two roots the `f` zellij keybind
already searches; if the path is under neither, `--owner` must be passed
explicitly. `--category` may be left blank entirely.

Enums are validated in the script itself, not just documented here — `add`
rejects anything outside the fixed lists (when a value is actually given).

## Prerequisites

- [`yq`](https://github.com/mikefarah/yq) (mikefarah's Go yq) on PATH — already
  installed via Homebrew, see `hosts/darwin/modules/apps.nix`.

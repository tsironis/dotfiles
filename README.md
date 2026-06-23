# dotfiles

Personal macOS / Linux configuration managed with [Nix](https://nixos.org),
[nix-darwin](https://github.com/lnl7/nix-darwin), and
[home-manager](https://github.com/nix-community/home-manager).

Machine-specific values (username, hostname) live in `flake.nix` and are easy to
swap when forking — see [Forking for your own machine](#forking-for-your-own-machine).

## What's in here

| Path | What it configures |
|------|--------------------|
| `flake.nix` | Entry point — darwin + home-manager outputs |
| `hosts/darwin/` | macOS system config (nix-darwin): apps, system defaults, users |
| `home/` | home-manager: zsh, program configs, macOS-only app symlinks |
| `nvim/` | Neovim config (kickstart-based) |
| `zsh/`, `ghostty/`, `aerospace/`, `sketchybar/` | App configs, symlinked into `~/.config` |
| `Makefile` | Convenience targets (`darwin`, `linux`, `update`, `fmt`) |

Config dirs like `nvim`, `ghostty`, `aerospace`, and `sketchybar` are linked
via `mkOutOfStoreSymlink`, so edits take effect immediately without a rebuild.

## Prerequisites

- [Nix](https://nixos.org/download) with flakes enabled.
- macOS: nix-darwin is bootstrapped on first `make darwin`.
- This repo cloned to `~/code/dotfiles` (the home-manager symlinks assume this
  path — see `home/*.nix` if you keep it elsewhere).

## Forking for your own machine

> This is the part that's easy to forget — only two places hold machine-specific
> values, and they must match each other.

1. **`flake.nix`** — the `EDIT THESE TWO FOR YOUR MACHINE` block near the top:
   ```nix
   username = "dimitristsironis";   # → your username
   hostname = "galadriel";          # → your macOS hostname
   ```
2. **`Makefile`** — replace `galadriel` (in the `darwin` target) and
   `dimitristsironis` (in the `linux` target) with the same values.

Then clone to `~/code/dotfiles` (the home-manager symlinks assume this path) and
run the relevant target below.

## Usage

```sh
make darwin     # macOS: build + darwin-rebuild switch
make linux      # Linux: standalone home-manager switch
make update     # nix flake update (bump all inputs)
make fmt        # format Nix files (alejandra)
```

## Notes

- **Linux** uses the standalone `homeConfigurations.<user>` output and applies
  only the home-manager layer (no nix-darwin).
- Stray local files (`result`, `*.zip`, `.DS_Store`) are git-ignored.

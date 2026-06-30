{ config, ... }:

let
  dotfiles = "${config.home.homeDirectory}/code/dotfiles";
in
{
  # direnv + nix-direnv: auto-load .envrc / `use flake` per project, with caching.
  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
  };

  xdg.configFile."nvim" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/nvim";
    force = true;
  };

  xdg.configFile."zellij" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/zellij";
    force = true;
  };

  # Symlinked (not copied) so edits to the repo file apply without a rebuild.
  xdg.configFile."starship.toml" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/starship/starship.toml";
    force = true;
  };
}

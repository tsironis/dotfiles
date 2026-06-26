{ config, ... }:

let
  dotfiles = "${config.home.homeDirectory}/code/dotfiles";
in
{
  xdg.configFile."nvim" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/nvim";
    force = true;
  };

  xdg.configFile."zellij" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/zellij";
    force = true;
  };
}

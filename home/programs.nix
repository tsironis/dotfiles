{ config, ... }:

let
  dotfiles = "${config.home.homeDirectory}/code/dotfiles";
in
{
  xdg.configFile."nvim" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/nvim";
    force = true;
  };
}

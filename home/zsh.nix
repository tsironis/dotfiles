{ config, ... }:

let
  dotfiles = "${config.home.homeDirectory}/code/dotfiles";
in
{
  home.file.".zshrc".source =
    config.lib.file.mkOutOfStoreSymlink "${dotfiles}/zsh/.zshrc";
}

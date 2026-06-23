{ config, pkgs, lib, ... }:

let
  dotfiles = "${config.home.homeDirectory}/code/dotfiles";
in
# macOS-only application configs — linked directly to the repo so edits
# are reflected immediately without rebuilding.
lib.mkIf pkgs.stdenv.isDarwin {
  xdg.configFile."ghostty" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/ghostty";
    force = true;
  };

  xdg.configFile."aerospace" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/aerospace";
    force = true;
  };

  xdg.configFile."sketchybar" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/sketchybar";
    force = true;
  };
}

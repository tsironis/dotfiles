{ pkgs, lib, username, ... }:

{
  imports = [
    ./zsh.nix
    ./programs.nix
    ./darwin.nix  # guarded internally with mkIf isDarwin
  ];

  home.username = username;
  home.homeDirectory =
    if pkgs.stdenv.isDarwin
    then "/Users/${username}"
    else "/home/${username}";

  home.stateVersion = "24.11";

  programs.home-manager.enable = true;
}

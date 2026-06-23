{ ... }:

{
  imports = [
    ./modules/nix-core.nix
    ./modules/system.nix
    ./modules/apps.nix
    ./modules/host-users.nix
  ];
}

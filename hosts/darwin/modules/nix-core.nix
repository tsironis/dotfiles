{ ... }:

{
  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # Nix itself is managed by Determinate (see the `determinate` flake input and
  # the darwinModules.default import in flake.nix). The module sets
  # `nix.enable = false` for us, so we must NOT also set it here, nor set
  # `nix.package` / `nix.gc` — determinate-nixd handles the daemon and GC.
  determinateNix.enable = true;

  # Custom daemon settings are written to /etc/nix/nix.custom.conf.
  determinateNix.customSettings = {
    experimental-features = [ "nix-command" "flakes" ];

    # Disable auto-optimise-store because of this issue:
    #   https://github.com/NixOS/nix/issues/7273
    # "error: cannot link '/nix/store/.tmp-link-xxxxx' to '/nix/store/.links/xxxx': File exists"
    auto-optimise-store = false;
  };
}

{
  description = "nix-darwin + home-manager dotfiles";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    darwin = {
      url = "github:lnl7/nix-darwin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-homebrew.url = "github:zhaofengli/nix-homebrew";

    # herdr — terminal workspace manager for AI coding agents. Built from source
    # (Rust + zig for the vendored libghostty-vt); pinned to a release tag, so
    # updates mean bumping the tag here.
    herdr = {
      url = "github:herdrdev/herdr/v0.8.2";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Determinate Nix — hardened daemon that survives macOS major upgrades
    # (signed LaunchDaemon, not BTM-gated). Manages Nix itself; see nix-core.nix.
    determinate.url = "https://flakehub.com/f/DeterminateSystems/determinate/3";
  };

  outputs = inputs @ { self, nixpkgs, darwin, home-manager, nix-homebrew, ... }:
  let
    # ── EDIT THESE TWO FOR YOUR MACHINE ──────────────────────────────────────
    # Forking this repo? Set your own username and macOS hostname here, then
    # update the matching values in the Makefile (`make darwin` / `make linux`).
    username = "dimitristsironis";
    hostname = "galadriel";
    # ─────────────────────────────────────────────────────────────────────────

    specialArgs = { inherit username hostname; };
  in
  {
    # ── macOS ──────────────────────────────────────────────────────────────
    darwinConfigurations.${hostname} = darwin.lib.darwinSystem {
      system = "aarch64-darwin";
      specialArgs = specialArgs // { inherit inputs; };
      modules = [
        inputs.determinate.darwinModules.default
        ./hosts/darwin/default.nix
        nix-homebrew.darwinModules.nix-homebrew
        home-manager.darwinModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = true;
            useUserPackages = true;
            backupFileExtension = "bak";
            extraSpecialArgs = specialArgs;
            users.${username} = import ./home/default.nix;
          };
        }
      ];
    };

    # ── Linux (standalone home-manager, works on Arch or any distro) ───────
    # Switch with: home-manager switch --flake .#<username>  (or: make linux)
    homeConfigurations.${username} = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages."x86_64-linux"; # change to aarch64-linux for ARM
      extraSpecialArgs = specialArgs;
      modules = [ ./home/default.nix ];
    };

    # ── Formatter ──────────────────────────────────────────────────────────
    formatter = {
      "aarch64-darwin" = nixpkgs.legacyPackages."aarch64-darwin".alejandra;
      "x86_64-linux"   = nixpkgs.legacyPackages."x86_64-linux".alejandra;
    };
  };
}

{ pkgs, username, ...}: {

  ##########################################################################
  #
  #  Install all apps and packages here.
  #
  #  NOTE: Your can find all available options in:
  #    https://daiderd.com/nix-darwin/manual/index.html
  #
  # TODO Fell free to modify this file to fit your needs.
  #
  ##########################################################################

  # Install packages from nix's official package repository.
  #
  # The packages installed here are available to all users, and are reproducible across machines, and are rollbackable.
  # But on macOS, it's less stable than homebrew.
  #
  # Related Discussion: https://discourse.nixos.org/t/darwin-again/29331
  environment.systemPackages = with pkgs; [
    git
    fzf
    rustc
    cargo
    go
    tmux
    ripgrep
    uv
    python3
    alejandra  # nix formatter (matches flake formatter; used by nvim conform)
    shfmt      # shell formatter (used by nvim conform)
  ];

  environment.variables.EDITOR = "nvim";

  # nix-homebrew manages the Homebrew installation itself (owner of the prefix),
  # while the `homebrew` block below declares what to install.
  nix-homebrew = {
    enable = true;
    user = username;     # owns the Homebrew prefix
    autoMigrate = true;  # adopt the existing /opt/homebrew install in place
    # mutableTaps left at its default (true) so the imperative taps below keep working.

    # Trust entries for third-party (non-official) taps, applied via `brew trust`
    # during activation. Per-item rather than whole-tap. Note: removing an entry
    # here does NOT untrust it — use `brew untrust` for that.
    trust = {
      formulae = [
        "felixkratz/formulae/sketchybar"
        "felixkratz/formulae/borders"
        "sst/tap/opencode"
      ];
      casks = [
        "nikitabobko/tap/aerospace"
      ];
    };
  };

  # TODO To make this work, homebrew need to be installed manually, see https://brew.sh
  #
  # The apps installed by homebrew are not managed by nix, and not reproducible!
  # But on macOS, homebrew has a much larger selection of apps than nixpkgs, especially for GUI apps!
  homebrew = {
    enable = true;

    onActivation = {
      autoUpdate = false;
      # 'zap': uninstalls all formulae(and related files) not listed here.
      cleanup = "zap";
    };

    taps = [
      "homebrew/services"
      "nikitabobko/tap"
      "felixkratz/formulae"
      "sst/tap"
    ];

    masApps = {
      Pages = 409201541;
      Numbers = 409203825;
    };

    # `brew install`
    # TODO Feel free to add your favorite apps here.
    brews = [
      # "aria2"  # download tool
      "lua"
      "git-lfs"
      "neovim"
      "fswatch"
      "starship"
      "zellij"
      "killport"
      "htop"
      "nowplaying-cli"
      "mas"
      "mole"
      "tree"
      "sketchybar"
      "stylua"
      "borders"
      "elixir"
      "zig"
      "opencode"
      "lazygit"
      "lazydocker"
      "minikube"
      "helm"
      "pandoc"
      "tectonic"
      "typst"
      "atuin"
      "glab"
      "gh"
      "yq"
      "zoxide"
      "bat"
    ];

    # `brew install --cask`
    # TODO Feel free to add your favorite apps here.
    casks = [
      "sf-symbols"
      "google-chrome"
      "firefox"
      "vscodium"
      "microsoft-teams"
      "visual-studio-code"
      "zen"
      "tunnelblick"
      "ghostty"
      "docker-desktop"
      "ollama-app"
      "slack"
      "aerospace"
      "zoom"
      "element"
      "vlc"
      "caffeine"
      "bambu-studio"
      "kicad"
      "obs"
      "autodesk-fusion"
      "signal"
      "figma"
      "claude-code"
      # "battery"
    ];
  };
}

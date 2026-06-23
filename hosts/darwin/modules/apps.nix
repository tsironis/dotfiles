{ pkgs, ...}: {

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
  ];

  environment.variables.EDITOR = "nvim";

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
      "arc"
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

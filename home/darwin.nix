{
  config,
  pkgs,
  lib,
  ...
}: let
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

    # Claude Code is installed via its native self-updating installer (not Homebrew), so it
    # tracks the `latest` channel and auto-updates in the background. This bootstraps it on a
    # fresh machine only when missing; existing self-updating installs are left untouched.
    # Non-fatal so a rebuild never fails on a transient network issue.
    home.activation.bootstrapClaudeCode = lib.hm.dag.entryAfter ["writeBoundary"] ''
      if [ ! -e "$HOME/.local/bin/claude" ]; then
        verboseEcho "Bootstrapping Claude Code native installer"
        ${pkgs.curl}/bin/curl -fsSL https://claude.ai/install.sh | bash || true
      fi
    '';

    # Native installer's launcher lives here; keep it on PATH declaratively for fresh machines.
    home.sessionPath = ["$HOME/.local/bin"];
  }

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

    # Markdown -> Typst -> PDF renderer (with mermaid diagrams as vector SVG). Needs
    # pandoc, typst, and mmdc (npm install -g @mermaid-js/mermaid-cli) on PATH.
    #
    # No `executable = true` here: it doesn't combine with mkOutOfStoreSymlink (home-manager
    # tries to build a derivation to set the bit, which fails against a live out-of-store path).
    # Unnecessary anyway — render-pdf.sh is chmod +x'd in the repo itself, and the symlink
    # follows through to those same permission bits.
    home.file.".local/bin/render-pdf" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/render-pdf/render-pdf.sh";
    };

    # PDF -> plain text (and, on request, annotations) via PyMuPDF, run through `uv run
    # --script` so its dependency is installed into an ephemeral venv on first use rather
    # than needing a Nix/Homebrew package. The opposite direction of render-pdf: for
    # reading a PDF's text cheaply instead of parsing it page-by-page as images.
    home.file.".local/bin/read-pdf" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/read-pdf/read-pdf.py";
    };

    # fzf-driven zellij session picker, moved into the repo from its previous
    # untracked location at ~/.local/bin/zellij-sessionizer. `force = true` because
    # that path is occupied by a real (non-symlink) file on any machine that had it
    # before this switch — same reason ghostty/aerospace/sketchybar use `force` above.
    home.file.".local/bin/zellij-sessionizer" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/zellij-sessionizer/zellij-sessionizer.sh";
      force = true;
    };

    # Reflects an agent CLI's working/blocked/idle state in the current zellij
    # tab name (see agent-status/README.md). Opt-in, run manually in place of
    # the agent command -- not wired into zellij-sessionizer/greet.sh.
    home.file.".local/bin/agent-status-wrap" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/agent-status/agent-status-wrap.sh";
    };

    # Personal projects tracker: thin CLI over projects/projects.yaml. Needs yq
    # (already a brew dependency, see hosts/darwin/modules/apps.nix) on PATH.
    home.file.".local/bin/projects" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/projects/projects.sh";
    };

    # Manually curated registry of installed CLI tools (see tools-registry/). Needs
    # yq on PATH, same as above.
    home.file.".local/bin/tools-registry" = {
      source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/tools-registry/tools-registry.sh";
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

    # openproject-cli isn't packaged in nixpkgs/Homebrew — only distributed via
    # `go install` or GitHub Releases binaries. Bootstrapped via the Go toolchain
    # (already in environment.systemPackages) the same way Claude Code's native
    # installer is bootstrapped above. Non-fatal so a rebuild never fails on a
    # transient network issue.
    home.activation.bootstrapOpenprojectCli = lib.hm.dag.entryAfter ["writeBoundary"] ''
      if [ ! -e "$HOME/go/bin/openproject-cli" ]; then
        verboseEcho "Bootstrapping openproject-cli via go install"
        ${pkgs.go}/bin/go install github.com/opf/openproject-cli@latest || true
      fi
    '';

    # Native installer's launcher lives here; keep it on PATH declaratively for fresh machines.
    home.sessionPath = ["$HOME/.local/bin" "$HOME/go/bin"];
  }

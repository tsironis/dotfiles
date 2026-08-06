{ config, ... }:

let
  dotfiles = "${config.home.homeDirectory}/code/dotfiles";
in
# Global Claude Code instructions — linked to the repo rather than copied, so
# edits (including ones Claude Code makes itself) land in git straight away.
# Only CLAUDE.md is tracked; the rest of ~/.claude is regenerable session state.
{
  home.file.".claude/CLAUDE.md" = {
    source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/claude/CLAUDE.md";
    force = true;
  };
}

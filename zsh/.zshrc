eval "$(starship init zsh)"

# fzf — ctrl+t (file search) and alt+c (dir navigation), but NOT ctrl+r
if [ -n "${commands[fzf-share]}" ]; then
  source "$(fzf-share)/key-bindings.zsh"
  source "$(fzf-share)/completion.zsh"
fi

# atuin — takes ctrl+r last so it wins over fzf's binding
command -v atuin &>/dev/null && eval "$(atuin init zsh)"

# zoxide — smarter `cd`; `z <partial>` jumps to frequent dirs, `zi` for interactive
command -v zoxide &>/dev/null && eval "$(zoxide init zsh)"

# direnv — per-project env via .envrc (hook added manually since zsh isn't HM-managed)
command -v direnv &>/dev/null && eval "$(direnv hook zsh)"

# fzf previews — richer ctrl+t / alt+c (uses ripgrep + bat when present)
if command -v rg &>/dev/null; then
  export FZF_DEFAULT_COMMAND='rg --files --hidden --glob "!.git"'
fi
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers {} 2>/dev/null || cat {}'"
export FZF_ALT_C_OPTS="--preview 'ls -la {}'"
# Tango Dark colors for fzf (transparent bg) + bat inherits the terminal palette
export FZF_DEFAULT_OPTS="\
  --color=bg+:#2e3436,bg:-1,spinner:#34e2e2,hl:#729fcf \
  --color=fg:#d3d7cf,header:#729fcf,info:#fce94f,pointer:#34e2e2 \
  --color=marker:#8ae234,fg+:#eeeeec,prompt:#fce94f,hl+:#729fcf"
export BAT_THEME="ansi"

# hdiff — side-by-side diff of two files, rendered to HTML and opened in the browser.
# Defaults to a temp dir so nothing is left behind in the working tree; -o pins
# the output path. Override the render width with HDIFF_COLS (default 200).
hdiff() {
  local -a o_flag
  zparseopts -D -E -- o:=o_flag || return 1

  if (( $# != 2 )); then
    print -u2 'usage: hdiff [-o out.html] <file-a> <file-b>'
    return 1
  fi

  local f
  for f in "$1" "$2"; do
    if [[ ! -f $f ]]; then
      print -u2 "hdiff: not a file: $f"
      return 1
    fi
  done

  if cmp -s -- "$1" "$2"; then
    print "hdiff: files are identical"
    return 0
  fi

  local out=${o_flag[2]:-"$(mktemp -d)/${1:t:r}-vs-${2:t:r}.html"}
  if [[ ! -d ${out:h} ]]; then
    print -u2 "hdiff: no such directory: ${out:h}"
    return 1
  fi
  icdiff --cols="${HDIFF_COLS:-200}" --highlight --line-numbers -- "$1" "$2" \
    | aha --black --title "${1:t} vs ${2:t}" > "$out"
  open "$out"
}

# dir aliases
alias ..='cd ..'
alias ...='cd ../..'
alias ~='cd ~'

# git aliases
alias ga='git add'
alias gco='git checkout'
alias gc='git commit'
alias gfo='git fetch origin'
alias gpr='git pull --rebase'
alias gst='git status'
alias glol="git log --pretty=oneline --abbrev-commit --graph --decorate"
alias gd='git diff'
alias gds='git diff --staged'

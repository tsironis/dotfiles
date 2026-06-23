eval "$(starship init zsh)"

# fzf — ctrl+t (file search) and alt+c (dir navigation), but NOT ctrl+r
if [ -n "${commands[fzf-share]}" ]; then
  source "$(fzf-share)/key-bindings.zsh"
  source "$(fzf-share)/completion.zsh"
fi

# atuin — takes ctrl+r last so it wins over fzf's binding
command -v atuin &>/dev/null && eval "$(atuin init zsh)"

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

# PATH: personal scripts (fzf-history-delete etc.)
typeset -U path
path=(~/.local/bin $path)

# History
HISTFILE=~/.zsh_history
HISTSIZE=100000
SAVEHIST=100000
setopt share_history hist_ignore_all_dups hist_ignore_space hist_reduce_blanks

# Completion
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
# File-type colours (from /etc/DIR_COLORS) for ls, eza, fd and the completion menu
eval "$(dircolors -b)"
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# Keys: emacs mode, plus Home/End/Delete/Ctrl-arrows as Konsole sends them
bindkey -e
bindkey '^[[H' beginning-of-line;  bindkey '^[OH' beginning-of-line
bindkey '^[[F' end-of-line;        bindkey '^[OF' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word;    bindkey '^[[1;5D' backward-word
bindkey '^[[3;5~' kill-word;       bindkey '^H' backward-kill-word
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search; zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search;  bindkey '^[OA' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search; bindkey '^[OB' down-line-or-beginning-search

# Prompt: user@host ~/dir (git-branch) [exit code if non-zero] %
autoload -Uz vcs_info add-zsh-hook
zstyle ':vcs_info:git:*' formats ' %F{magenta}(%b)%f'
add-zsh-hook precmd vcs_info
setopt prompt_subst
PROMPT='%F{green}%n@%m%f %F{blue}%~%f${vcs_info_msg_0_} %(?..%F{red}[%?]%f )%# '

# Colour where it helps; tools switch colour off by themselves in pipes and scripts
alias ls='eza --icons=auto --group-directories-first'
alias ll='eza -l --icons=auto --git --group-directories-first --time-style=long-iso'
alias la='eza -la --icons=auto --git --group-directories-first --time-style=long-iso'
alias lt='eza --tree --level=2 --icons=auto --group-directories-first'
alias cat='bat --paging=never --style=plain'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ip='ip -color=auto'

if [ -f /usr/share/fzf/key-bindings.zsh ]; then
    source /usr/share/fzf/key-bindings.zsh
fi

# FZF History Deletion Engine (Ctrl-R, then Ctrl-X deletes the selected entries)
# Ctrl-T file picker with a syntax-highlighted preview
export FZF_CTRL_T_OPTS="--preview 'bat --color=always --style=numbers --line-range=:200 {} 2>/dev/null || eza --tree --level=1 --icons=always --color=always {}'"
export FZF_CTRL_R_OPTS="--bind 'ctrl-x:execute-silent(fzf-history-delete {+f})+exclude-multi' --header 'Ctrl-X: Delete entry | Ctrl-R: Toggle sort'"
_fzf_history_wrapper() {
    fzf-history-widget "$@"
    local ret=$?
    local flag=${XDG_RUNTIME_DIR:-/tmp}/.zsh-history-edited-$UID
    if [[ -e $flag ]]; then
        # Drop the in-memory history and reload the pruned file
        rm -f -- $flag
        local hs=$HISTSIZE
        HISTSIZE=0; HISTSIZE=$hs
        fc -R
    fi
    return $ret
}
zle -N fzf-history-widget _fzf_history_wrapper


# Gentoo full system update (see gentoo-tuning-guide section 12)
alias up='sudo zsh -c "eix-sync && emerge -vuDN --with-bdeps=y --keep-going @world && emerge --depclean"'

# zoxide: `z <part of dir>` jumps to frequently used directories
command -v zoxide >/dev/null && eval "$(zoxide init zsh)"

# Syntax highlighting (app-shells/zsh-syntax-highlighting); must stay at the end
[ -f /usr/share/zsh/site-functions/zsh-syntax-highlighting.zsh ] && source /usr/share/zsh/site-functions/zsh-syntax-highlighting.zsh

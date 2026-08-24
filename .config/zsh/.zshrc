# Bail out early for dumb terminals (TRAMP, etc.)
[[ $TERM == "dumb" ]] && unsetopt zle && PS1='$ ' && return

: "${ZDOTDIR:=$HOME/.config/zsh}"
export ZDOTDIR

# History
HISTSIZE=100000
SAVEHIST=$HISTSIZE
HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
mkdir -p "${HISTFILE:h}"
setopt AUTO_MENU
setopt AUTO_LIST
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_IGNORE_SPACE
setopt HIST_EXPIRE_DUPS_FIRST
setopt SHARE_HISTORY
setopt NUMERIC_GLOB_SORT

# Shell behaviour
setopt AUTOCD
setopt NOBEEP

# Plugins (adds completions, must come before compinit)
[[ -r "$ZDOTDIR/plugins.zsh" ]] && source "$ZDOTDIR/plugins.zsh"

# Completion
autoload -Uz compinit
mkdir -p "${XDG_CACHE_HOME:-$HOME/.cache}/zsh"
# -i ignores insecure (e.g. group-writable) fpath dirs instead of prompting
# interactively, which would otherwise stall login on shared/HPC systems.
compinit -i -d "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump"

# Populate LS_COLORS so completion listings (and ls) are colorized.
command -v dircolors >/dev/null 2>&1 && eval "$(dircolors -b)"

zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu select
zstyle ':fzf-tab:complete:*:*' fzf-preview \
    '[ -n "$realpath" ] || exit 0; [ -d "$realpath" ] && { eza --tree --color=always -- "$realpath" 2>/dev/null || ls -la --color=always -- "$realpath"; } || { bat --color=always -- "$realpath" 2>/dev/null || cat -- "$realpath"; }'
zstyle ':fzf-tab:complete:ssh:*' fzf-preview 'grep -A5 -- "Host $_" "$HOME/.ssh/config"'
zstyle ':fzf-tab:*' fzf-flags --height=80% --preview-window=right:50%

# Prompt
[[ -r "$ZDOTDIR/prompt.zsh" ]] && source "$ZDOTDIR/prompt.zsh"

# Shell integrations
command -v fzf >/dev/null 2>&1 && source <(fzf --zsh)
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"
command -v fnm >/dev/null 2>&1 && eval "$(fnm env --use-on-cd)"
command -v "$MAMBA_EXE" >/dev/null 2>&1 &&
    eval "$("$MAMBA_EXE" shell hook --shell zsh --root-prefix "$MAMBA_ROOT_PREFIX" 2>/dev/null)"
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh --cmd cd)" && export _ZO_DOCTOR=0

# FZF options
command -v rg >/dev/null 2>&1 && export FZF_DEFAULT_COMMAND='rg --files --hidden --follow --glob "!.git/*"'
command -v bat >/dev/null 2>&1 && export FZF_CTRL_T_OPTS="--preview 'bat --style=numbers --color=always {}'"
export FZF_DEFAULT_OPTS="
--ansi
--cycle
--multi
--height=40%
--layout=reverse
--border
--info=inline
"

# Aliases
alias ls='ls --color=auto'
alias wget='wget --hsts-file=$XDG_DATA_HOME/wget-hsts'
if command -v eza >/dev/null 2>&1; then
    alias ll='eza -lh --icons --git'
    alias la='eza -lah --icons --git'
    alias lt='eza --tree --icons'
    compdef eza=ls
fi

# Deduplicate PATH
typeset -U PATH

# Pi shell helpers
__pi_shell_readonly_prompt='Answer concisely for shell use. Read-only route. Do not edit files, write files, or run shell commands.'
__pi_shell_command_prompt='Convert the user intent into exactly one safe Linux shell command. Output only the command. No markdown. No explanation. Do not execute anything.'

function '?' {
    pi -p --offline \
        --tools read,grep,find,ls,web_search,fetch_content \
        --thinking off \
        --model opencode-go/deepseek-v4-flash \
        --system-prompt "$__pi_shell_readonly_prompt" \
        "$*"
}

function ',' {
    local command
    command="$(pi -p --offline --no-tools \
        --no-context-files \
        --no-extensions \
        --no-skills \
        --thinking off \
        --model opencode-go/deepseek-v4-flash \
        --system-prompt "$__pi_shell_command_prompt" \
        "$*")" || return $?
    print -r -- "$command"
    [[ -n "$command" ]] && print -z -- "$command"
}

alias '?'='noglob ?'
alias ','='noglob ,'

# Machine-local config
[[ -r "$HOME/.localrc" ]] && source "$HOME/.localrc"

# Attach to tmux in fresh interactive shells, including SSH logins.
if [[ -o interactive ]] &&
    [[ "${ZSH_TMUX_AUTOSTART:-1}" == "1" ]] &&
    [[ -n "$TERM_PROGRAM$KITTY_WINDOW_ID$ALACRITTY_WINDOW_ID$WEZTERM_PANE$SSH_CONNECTION" ]] &&
    [[ -z "$TMUX" ]] &&
    [[ -z "$INSIDE_EMACS" ]] &&
    [[ -t 0 && -t 1 ]] &&
    command -v tmux >/dev/null 2>&1; then
    # xterm-256color is universally present; xterm-kitty terminfo may be
    # absent on remote/HPC nodes, which would stop tmux from starting.
    [[ "$TERM" == "dumb" ]] && export TERM=xterm-256color
    tmux start-server 2>/dev/null
    tmux attach-session -d 2>/dev/null || tmux new-session -s main
fi

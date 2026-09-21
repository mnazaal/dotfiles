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

# Ref candidates carry no $realpath, so the file preview above is inert for
# them. Show what the ref actually points at instead. Listed per subcommand:
# a ':fzf-tab:complete:git-*:*' pattern would outrank the '*:*' file preview
# and break `git add` too.
zstyle ':fzf-tab:complete:git-merge:*' fzf-preview 'git log --oneline --graph --color=always -20 $word 2>/dev/null'
zstyle ':fzf-tab:complete:git-checkout:*' fzf-preview 'git log --oneline --graph --color=always -20 $word 2>/dev/null'
zstyle ':fzf-tab:complete:git-switch:*' fzf-preview 'git log --oneline --graph --color=always -20 $word 2>/dev/null'
zstyle ':fzf-tab:complete:git-rebase:*' fzf-preview 'git log --oneline --graph --color=always -20 $word 2>/dev/null'

# `git merge` completes any commit-ish, so zsh offers local+remote heads, tags,
# and the last 20 commits with their subject lines. Try branches first.
zstyle ':completion:*:*:git-merge:*' tag-order 'heads' 'commit-tags' 'commit-objects'
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
#
# Both run the same stripped harness, because everything pi loads by default is
# paid for on every call. Measured 2026-09-21 on "random permutation of
# highlighted lines neovim": the full harness took 85.5s, and the session record
# showed a 5288-token prompt for a one-line question. Skills and AGENTS.md are
# what fill it -- they cost nothing at startup, so only the token count shows
# them. Extension discovery loads the nine packages in pi's settings.json, seven
# of which only serve the TUI that -p never draws, and costs ~7s of an ~8.8s
# startup. Dropping all of it, plus the tools, gives 1.8-3.3s.
#
# --no-tools is what makes the rest safe to drop: with no tools there is nothing
# for the guardrails extension to gate, which is why neither helper loads it.
# It also removes the round trips -- given file tools, `?` went off to read the
# config the question happened to name, and each tool call is another full model
# call. Ask pi directly for anything needing the web or this machine's files.
#
# The line budget in the prompt is not cosmetic: output tokens ran at ~9/s, so
# length is most of the wait.
__pi_shell_readonly_prompt='Answer for shell use in at most 6 lines. Give the command or answer first, then at most three short bullets. No headings, no preamble, no code fences unless the answer is multi-line.'
__pi_shell_command_prompt='Convert the user intent into exactly one safe Linux shell command. Output only the command. No markdown. No explanation. Do not execute anything.'

function '?' {
    pi -p --offline --no-tools \
        --no-context-files \
        --no-extensions \
        --no-skills \
        --no-prompt-templates \
        --thinking off \
        --model openrouter/deepseek/deepseek-v4.1-flash \
        --system-prompt "$__pi_shell_readonly_prompt" \
        "$*"
}

function ',' {
    local command
    command="$(pi -p --offline --no-tools \
        --no-context-files \
        --no-extensions \
        --no-skills \
        --no-prompt-templates \
        --thinking off \
        --model openrouter/deepseek/deepseek-v4.1-flash \
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

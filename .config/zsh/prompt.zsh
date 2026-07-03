autoload -Uz vcs_info
setopt PROMPT_SUBST

zstyle ':vcs_info:*'     enable git
zstyle ':vcs_info:git:*' check-for-changes true
zstyle ':vcs_info:git:*' stagedstr '+'
zstyle ':vcs_info:git:*' unstagedstr '!'
zstyle ':vcs_info:git:*' formats       ' on %F{blue}%b%f'
zstyle ':vcs_info:git:*' actionformats ' on %F{blue}%b%f|%F{red}%a%f'

_git_ab() {
  command git rev-parse --is-inside-work-tree &>/dev/null || return
  local ab; ab=$(command git rev-list --count --left-right '@{upstream}...HEAD' 2>/dev/null) || return
  local b=${ab%%$'\t'*} a=${ab##*$'\t'} o=''
  (( a > 0 )) && o+="⇡${a}"
  (( b > 0 )) && o+="⇣${b}"
  [[ -n $o ]] && echo " $o"
}

_git_st() {
  command git rev-parse --is-inside-work-tree &>/dev/null || return
  local s=''
  command git ls-files --others --exclude-standard --error-unmatch . &>/dev/null 2>&1 && s+='?'
  command git diff --quiet 2>/dev/null         || s+='!'
  command git diff --cached --quiet 2>/dev/null || s+='+'
  command git stash list 2>/dev/null | grep -q . && s+='$'
  local ab; ab=$(_git_ab)
  [[ -n $s || -n $ab ]] && echo " %F{red}[${s}${ab}]%f"
}

_py_env() {
  local e=${VIRTUAL_ENV:t}${CONDA_DEFAULT_ENV}
  [[ -n $e ]] && echo " [🐍${e}]"
}

precmd() { vcs_info }

PROMPT='
%F{blue}%B[%n%b%f%F{red}%B@%m%b%f%F{blue}%B | %F{yellow}%T%F{blue}]%b%f %F{white}%~%f${vcs_info_msg_0_}$(_git_st)$(_py_env)
%(?.%F{green}❯%f.%F{red}❯%f) '

# Automatically start Zsh for interactive TTY bash sessions. This is the default
# shell where chsh is unavailable (HPC login nodes), and there zsh is often a
# user build in ~/.local/bin, which is not on PATH yet when bash reads this.
# SHELL is exported so tmux and other shell spawners start zsh too.
# Set DOTFILES_NO_EXEC_ZSH=1 to stay in bash.
case $- in
  *i*)
    zsh_bin=$(command -v zsh 2>/dev/null) \
      || { [ -x "$HOME/.local/bin/zsh" ] && zsh_bin="$HOME/.local/bin/zsh"; }
    if [ -t 1 ] \
      && [ -z "${ZSH_VERSION:-}" ] \
      && [ "${DOTFILES_NO_EXEC_ZSH:-0}" != 1 ] \
      && [ -n "$zsh_bin" ]; then
      export SHELL="$zsh_bin"
      exec "$zsh_bin"
    fi
    unset zsh_bin
    ;;
esac

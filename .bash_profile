# Automatically start Zsh for interactive TTY bash sessions.
# Set DOTFILES_NO_EXEC_ZSH=1 to stay in bash.
case $- in
  *i*)
    if [ -t 1 ] \
      && [ -z "${ZSH_VERSION:-}" ] \
      && [ "${DOTFILES_NO_EXEC_ZSH:-0}" != 1 ] \
      && command -v zsh >/dev/null 2>&1; then
      exec zsh
    fi
    ;;
esac

# Deliberately empty. GDM starts the session as `Exec=mango-session` with no
# login shell, so nothing here would run for the desktop; the session gets its
# environment from .local/scripts/mango-session, which sources .zshenv before
# exec'ing the compositor. A zsh login shell in a terminal reads .zshenv
# directly, so this file has nothing left to set.

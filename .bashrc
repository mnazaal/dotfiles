# Automatically start Zsh for interactive TTY bash sessions. This is the default
# shell where chsh is unavailable (HPC login nodes), and there zsh is often a
# user build in ~/.local/bin, which is not on PATH yet when bash reads this.
# A home shared by login nodes of different CPU architectures keeps one build
# per arch under ~/.local/<uname -m>/bin; each candidate is test-run before
# exec, since -x cannot tell an x86_64 binary from one this node can execute
# and a failed exec kills the login shell.
# SHELL is exported so tmux and other shell spawners start zsh too.
# FPATH is unset because zsh adopts an inherited FPATH IN PLACE OF its built-in
# fpath: Lmod exports one for ksh, and zsh then cannot find compinit, vcs_info
# or any other function it ships.
# Set DOTFILES_NO_EXEC_ZSH=1 to stay in bash.

[ -r "$HOME/.localenv" ] && . "$HOME/.localenv"

case $- in
*i*)
	zsh_bin=
	for zsh_candidate in "$(command -v zsh 2>/dev/null)" \
		"$HOME/.local/$(uname -m 2>/dev/null)/bin/zsh" \
		"$HOME/.local/bin/zsh"; do
		if [ -n "$zsh_candidate" ] && "$zsh_candidate" -fc true 2>/dev/null; then
			zsh_bin=$zsh_candidate
			break
		fi
	done
	unset zsh_candidate
	if [ -t 1 ] &&
		[ -z "${ZSH_VERSION:-}" ] &&
		[ "${DOTFILES_NO_EXEC_ZSH:-0}" != 1 ] &&
		[ -n "$zsh_bin" ]; then
		export SHELL="$zsh_bin"
		unset FPATH
		exec "$zsh_bin"
	fi
	unset zsh_bin
	;;
esac

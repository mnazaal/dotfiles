# shellcheck shell=bash
# Claude over the Agent Client Protocol, as launched by an editor. Loaded by
# `renv claude-agent-acp`; Emacs points agent-shell's ACP command at it.
#
# Same door as the terminal launch, deliberately: this sources claude.sh rather
# than restating any of it, so the branch prefix, the secrets, the Headroom
# proxy and the sandbox profile are defined in exactly one place. Adding a
# harness to the editor should never mean a second copy of its policy.
#
# The adapter speaks JSON-RPC over stdio, so nothing may reach stdout. Verified
# clean: renv is silent, and claude.sh keeps its one diagnostic on stderr and
# redirects the proxy's own output to a log.
# shellcheck source=/dev/null
. "${XDG_CONFIG_HOME:-$HOME/.config}/renv/claude.sh"

# Nothing is subtracted from RENV_PRE_ARGS here any more. It used to carry
# `--permission-mode bypassPermissions`, a claude CLI flag this adapter rejects,
# so this file unset the array -- which also discarded the native-sandbox
# override sharing it, and every Bash call in an agent-shell session then failed
# with `Can't mount proc on /newroot/proc`. The permission mode has since moved
# to settings.json, leaving only the override, which this path needs verbatim.

# The sandbox wrapper inherited from claude.sh binds the repository read-write
# by resolving `git rev-parse --show-toplevel` in the current directory. That
# works here because agent-shell binds `default-directory` to the project root
# before spawning this process (agent-shell.el, `agent-shell-cwd`), so the
# adapter starts inside the repository it will edit, one process per shell.

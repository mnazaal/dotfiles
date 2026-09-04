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

# claude.sh adds `--permission-mode bypassPermissions`, which is a flag of the
# claude CLI and not of this adapter — passing it through would abort the
# launch. Dropping it is also the point of the editor path: the per-tool-call
# prompt shown in Emacs is what replaces the terminal's blanket bypass.
unset RENV_PRE_ARGS

# The sandbox wrapper inherited from claude.sh binds the repository read-write
# by resolving `git rev-parse --show-toplevel` in the current directory. That
# works here because agent-shell binds `default-directory` to the project root
# before spawning this process (agent-shell.el, `agent-shell-cwd`), so the
# adapter starts inside the repository it will edit, one process per shell.
#
# UNVERIFIED as of 2026-09-04: nothing has run this yet. If a shell fails to
# start, comment the line below to fall back to an unconfined adapter — the
# guardrail hook and the permission prompts still apply either way — and report
# what the process said.
# unset RENV_WRAP

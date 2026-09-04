# shellcheck shell=bash
# Pi over the Agent Client Protocol, as launched by an editor. Loaded by
# `renv pi-acp`; Emacs points agent-shell's pi ACP command at it.
#
# `pi-acp` is a separate binary from `pi`, so renv looks for this file rather
# than pi.sh. Source that instead of restating it: same branch prefix, same
# secrets, same sandbox profile, defined once.
#
# The adapter speaks JSON-RPC over stdio; keep anything added here on stderr.
#
# Opencode needs no equivalent file: its ACP mode is a subcommand of the same
# binary, so `renv opencode acp` already loads opencode.sh unchanged.
# shellcheck source=/dev/null
. "${XDG_CONFIG_HOME:-$HOME/.config}/renv/pi.sh"

# UNVERIFIED as of 2026-09-04. If the shell fails to start, uncomment to fall
# back to an unconfined adapter and report what the process said.
# unset RENV_WRAP

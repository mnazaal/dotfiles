# shellcheck shell=bash
# Claude Code environment variables
# # Loaded by renv before running `claude`

# Nothing here routes through Headroom any more. The proxy is a systemd user
# service (`headroom install apply --preset persistent-service`), enabled and
# restarted on failure by systemd, and settings.json points ANTHROPIC_BASE_URL
# at it for every launch path. This file used to start the proxy itself and
# export the base URL, which only ever worked for launches that went through
# it -- a bare `claude` got nothing.

# --- Filesystem sandbox + permission mode -----------------------------------
# Switch OFF Claude Code's own native sandbox for this launch. It cannot nest
# inside podman (bwrap cannot mount proc in a second user namespace), and the
# global flag that would allow it, enableWeakerNestedSandbox, exposes the host
# /proc to every Bash command -- which would weaken the BARE `claude` path too,
# where the native sandbox IS the only boundary. Podman is the boundary here, so
# turning the inner one off loses nothing. Delete when this launcher retires and
# settings.json's sandbox block is the only boundary left.
#
# This is now the only pre-arg, so the ACP launcher can inherit it wholesale.
# It briefly shared an array with --permission-mode, and that file's blanket
# `unset` -- there to drop the permission flag, which the adapter rejects --
# took this with it, leaving the editor path trying to nest. Removing the
# git-gated permission mode removed the need to subtract anything at all.
# shellcheck disable=SC2034  # read by renv after sourcing
RENV_PRE_ARGS=(--settings '{"sandbox":{"enabled":false}}')
# Run this harness confined to an allowlist of dirs via `sandbox`, and let it
# work unprompted inside that confinement. The sandbox is the boundary, not the
# permission prompt: every reachable path is an allowlisted bind.
#
# The writable unit is the *repository*, not $PWD. sandbox auto-binds $PWD
# read-write, so launching from a subdirectory would leave .git under the
# read-only ~/projects or ~/dotfiles bind — the agent would edit files
# unprompted while git itself was unwritable, destroying the recoverability the
# bypass depends on. --rw lands in the RW array, emitted after RO, so it
# correctly overrides the enclosing read-only bind.
#
# The permission mode is no longer decided here. It was gated on being inside a
# git worktree, on the reasoning that unprompted edits are safe because git can
# undo them -- but a prompt you approve is exactly as unrecoverable as an edit
# you were never asked about, so outside a repo the prompt restored nothing. It
# is now settings.json's flat `defaultMode`, which both launch paths read.
# Comment out the RENV_WRAP lines to disable confinement. See `sandbox --help`.
if _toplevel=$(git rev-parse --show-toplevel 2>/dev/null); then
	_rw=(--rw "$_toplevel")
	# In a linked worktree the real git dir lives in the MAIN repo, which may
	# sit under a read-only bind — bind it too or nothing can be committed.
	# --git-common-dir is relative to cwd in a normal checkout ('.git',
	# '../../.git') and absolute in a worktree, so resolve before comparing.
	if _common=$(git rev-parse --git-common-dir 2>/dev/null) &&
		_common=$(cd "$_common" 2>/dev/null && pwd); then
		case "$_common" in
		"$_toplevel" | "$_toplevel"/*) ;;
		*) _rw+=(--rw "$_common") ;;
		esac
	fi
	# shellcheck disable=SC2034  # read by renv after sourcing
	RENV_WRAP=(sandbox -p agent-claude "${_rw[@]}" --)
else
	# shellcheck disable=SC2034  # read by renv after sourcing
	RENV_WRAP=(sandbox -p agent-claude --)
fi
unset _toplevel _common _rw

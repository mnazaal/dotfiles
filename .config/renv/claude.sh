# shellcheck shell=bash
# Claude Code environment variables
# # Loaded by renv before running `claude`

# Confine this agent's git history to claude/* branches (enforced by the shared
# git hooks in ~/.config/git/hooks). Mirrors opencode's OPENCODE=1 convention.
AGENT_BRANCH_PREFIX="claude"
RENV_REQUIRE_GUARDRAILS=1

renv_secret ASTA_MCP_API_KEY asta-mcp

# Route Claude Code through the local Headroom proxy. This is intentionally kept
# in renv instead of `headroom wrap claude` so dotfiles remain the source of
# truth and the sandbox/secrets flow stays unchanged.
HEADROOM_PORT="${HEADROOM_PORT:-8787}"
HEADROOM_ANTHROPIC_BASE_URL="${HEADROOM_ANTHROPIC_BASE_URL:-http://127.0.0.1:${HEADROOM_PORT}}"

# Pin Headroom's workspace + memory DB to a stable home. Otherwise the proxy
# defaults the memory store to {cwd}/.headroom (server.py hardcodes Path.cwd()
# for the DB and ignores HEADROOM_WORKSPACE_DIR for it), so it lands in whatever
# project dir the agent happens to launch from. Absolute paths, exported before
# the proxy spawns so the child inherits them, make the location cwd-independent.
HEADROOM_WORKSPACE_DIR="${HEADROOM_WORKSPACE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/headroom}"
HEADROOM_MEMORY_DB_PATH="${HEADROOM_MEMORY_DB_PATH:-${HEADROOM_WORKSPACE_DIR}/memory.db}"
export HEADROOM_WORKSPACE_DIR HEADROOM_MEMORY_DB_PATH

if ! curl -fsS "${HEADROOM_ANTHROPIC_BASE_URL}/readyz" >/dev/null 2>&1; then
	mkdir -p "${HEADROOM_WORKSPACE_DIR}"
	nohup headroom proxy --port "$HEADROOM_PORT" --mode "${HEADROOM_MODE:-cache}" \
		--lossless --intercept-tool-results \
		>"${HEADROOM_WORKSPACE_DIR}/proxy-${HEADROOM_PORT}.log" 2>&1 &
	sleep 2
fi
ANTHROPIC_BASE_URL="$HEADROOM_ANTHROPIC_BASE_URL"

# Claude Code can eagerly load large tool definitions when a custom base URL is
# used unless tool search/deferral is explicitly enabled.
ENABLE_TOOL_SEARCH="${ENABLE_TOOL_SEARCH:-false}"

export AGENT_BRANCH_PREFIX RENV_REQUIRE_GUARDRAILS HEADROOM_PORT \
	HEADROOM_ANTHROPIC_BASE_URL ANTHROPIC_BASE_URL ENABLE_TOOL_SEARCH

# --- Filesystem sandbox + permission mode -----------------------------------
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
# Outside a worktree there is nothing to recover from, so stay confined but keep
# normal prompting. Deny rules, and guardrail-hook ask/deny, apply in every mode.
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
	# shellcheck disable=SC2034  # read by renv after sourcing
	RENV_PRE_ARGS=(--permission-mode bypassPermissions)
else
	# shellcheck disable=SC2034  # read by renv after sourcing
	RENV_WRAP=(sandbox -p agent-claude --)
	printf 'claude.sh: cwd is not a git worktree — starting with normal permissions\n' >&2
fi
unset _toplevel _common _rw

# The sandbox mounts the claude binary read-only, so its self-updater can't write
# (you'd see "Auto-update failed"). Disable it in the sandbox; update claude on
# the host instead (outside renv).
DISABLE_AUTOUPDATER=1
export DISABLE_AUTOUPDATER

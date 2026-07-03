# Claude Code environment variables
# # Loaded by renv before running `claude`

# Confine this agent's git history to claude/* branches (enforced by the shared
# git hooks in ~/.config/git/hooks). Mirrors opencode's OPENCODE=1 convention.
AGENT_BRANCH_PREFIX="claude"

ASTA_MCP_API_KEY="$(pass show asta-mcp)" ||
	{
		printf 'claude.sh: failed to read asta-mcp from pass\n' >&2
		return 1
	}

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
	nohup headroom proxy --port "$HEADROOM_PORT" --mode "${HEADROOM_MODE:-cache}" --memory \
		>"${HEADROOM_WORKSPACE_DIR}/proxy-${HEADROOM_PORT}.log" 2>&1 &
	sleep 2
fi
ANTHROPIC_BASE_URL="$HEADROOM_ANTHROPIC_BASE_URL"

# Claude Code can eagerly load large tool definitions when a custom base URL is
# used unless tool search/deferral is explicitly enabled.
ENABLE_TOOL_SEARCH="${ENABLE_TOOL_SEARCH:-true}"

export AGENT_BRANCH_PREFIX
export ASTA_MCP_API_KEY
export HEADROOM_PORT
export HEADROOM_ANTHROPIC_BASE_URL
export ANTHROPIC_BASE_URL
export ENABLE_TOOL_SEARCH

# --- Filesystem sandbox -----------------------------------------------------
# Run this harness confined to an allowlist of dirs via `sandbox`.
# Comment this out to disable. See `sandbox --help`.
# shellcheck disable=SC2034  # read by renv after sourcing
RENV_WRAP=(sandbox -p agent-claude --)

# The sandbox mounts the claude binary read-only, so its self-updater can't write
# (you'd see "Auto-update failed"). Disable it in the sandbox; update claude on
# the host instead (outside renv).
DISABLE_AUTOUPDATER=1
export DISABLE_AUTOUPDATER

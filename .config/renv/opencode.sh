# Opencode coding agent environment variables
# Loaded by renv before running `opencode`
EDITOR="nvim"

# Confine this agent's git history to opencode/* branches (enforced by the shared
# git hooks in ~/.config/git/hooks). opencode's runtime also sets OPENCODE=1, which
# the hooks fall back to; set it explicitly here so enforcement doesn't depend on it.
AGENT_BRANCH_PREFIX="opencode"

OPENROUTER_API_KEY="$(pass show openrouter-opencode)" ||
	{
		printf 'opencode.sh: failed to read openrouter-opencode from pass\n' >&2
		return 1
	}

ASTA_MCP_API_KEY="$(pass show asta-mcp)" ||
	{
		printf 'opencode.sh: failed to read asta-mcp from pass\n' >&2
		return 1
	}

export EDITOR
export AGENT_BRANCH_PREFIX
export OPENROUTER_API_KEY
export ASTA_MCP_API_KEY

# --- Filesystem sandbox -----------------------------------------------------
# Run this harness confined to an allowlist of dirs via `sandbox`.
# Comment this out to disable. See `sandbox --help`.
# shellcheck disable=SC2034  # read by renv after sourcing
RENV_WRAP=(sandbox -p agent-opencode --)

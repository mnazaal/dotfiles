# Codex CLI environment variables. Loaded by `renv codex`.

# Shared Git hooks restrict this session to codex/* branches.
AGENT_BRANCH_PREFIX="codex"
RENV_REQUIRE_GUARDRAILS=1
CODEX_HOME="${CODEX_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/codex}"

ASTA_MCP_API_KEY="$(pass show asta-mcp)" ||
	{
		printf 'codex.sh: failed to read asta-mcp from pass\n' >&2
		return 1
	}

export AGENT_BRANCH_PREFIX RENV_REQUIRE_GUARDRAILS CODEX_HOME ASTA_MCP_API_KEY

# The outer sandbox is the filesystem boundary for this explicit launch. Keep
# bare `codex` on its conservative local default.
# shellcheck disable=SC2034  # read by renv after sourcing
RENV_PRE_ARGS=(--sandbox danger-full-access --ask-for-approval never)
# shellcheck disable=SC2034  # read by renv after sourcing
RENV_WRAP=(sandbox -p agent-codex --)

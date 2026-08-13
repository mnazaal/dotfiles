# shellcheck shell=bash
# Pi coding agent environment variables
# Loaded by renv before running `pi`

# Confine this agent's git history to pi/* branches (enforced by the shared
# git hooks in ~/.config/git/hooks). Mirrors opencode's OPENCODE=1 convention.
AGENT_BRANCH_PREFIX="pi"
RENV_REQUIRE_GUARDRAILS=1

OPENROUTER_API_KEY="$(pass show openrouter-pi)" ||
	{
		printf 'pi.sh: failed to read openrouter-pi from pass\n' >&2
		return 1
	}

ASTA_MCP_API_KEY="$(pass show asta-mcp)" ||
	{
		printf 'pi.sh: failed to read asta-mcp from pass\n' >&2
		return 1
	}

export AGENT_BRANCH_PREFIX
export RENV_REQUIRE_GUARDRAILS
export OPENROUTER_API_KEY
export ASTA_MCP_API_KEY

# --- Filesystem sandbox -----------------------------------------------------
# Run this harness confined to an allowlist of dirs via `sandbox`.
# Comment this out to disable. See `sandbox --help`.
# shellcheck disable=SC2034  # read by renv after sourcing
RENV_WRAP=(sandbox -p agent-pi --)

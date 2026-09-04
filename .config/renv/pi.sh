# shellcheck shell=bash
# Pi coding agent environment variables
# Loaded by renv before running `pi`

# Confine this agent's git history to pi/* branches (enforced by the shared
# git hooks in ~/.config/git/hooks).
AGENT_BRANCH_PREFIX="pi"
RENV_REQUIRE_GUARDRAILS=1

renv_secret OPENROUTER_API_KEY openrouter-pi
renv_secret ASTA_MCP_API_KEY asta-mcp

export AGENT_BRANCH_PREFIX RENV_REQUIRE_GUARDRAILS

# shellcheck disable=SC2034  # read by renv after sourcing
RENV_WRAP=(sandbox -p agent-pi --)

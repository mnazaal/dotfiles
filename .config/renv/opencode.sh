# shellcheck shell=bash
# Opencode coding agent environment variables
# Loaded by renv before running `opencode`
EDITOR="nvim"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache/opencode}"
mkdir -p "$XDG_CACHE_HOME"

# Confine this agent's git history to opencode/* branches (enforced by the shared
# git hooks in ~/.config/git/hooks). opencode's runtime also sets OPENCODE=1, which
# the hooks fall back to; set it explicitly here so enforcement doesn't depend on it.
AGENT_BRANCH_PREFIX="opencode"
RENV_REQUIRE_GUARDRAILS=1

renv_secret OPENROUTER_API_KEY openrouter-opencode
renv_secret ASTA_MCP_API_KEY asta-mcp

export EDITOR XDG_CACHE_HOME AGENT_BRANCH_PREFIX RENV_REQUIRE_GUARDRAILS

# shellcheck disable=SC2034  # read by renv after sourcing
RENV_WRAP=(sandbox -p agent-opencode --)

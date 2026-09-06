# shellcheck shell=bash
# Pi coding agent environment variables
# Loaded by renv before running `pi`

renv_secret ASTA_MCP_API_KEY asta-mcp

# shellcheck disable=SC2034  # read by renv after sourcing
RENV_WRAP=(sandbox -p agent-pi --)

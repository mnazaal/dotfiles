# agent-pi — pi. Used by `renv pi`, which sets
# RENV_WRAP=(sandbox -p agent-pi --).
#
# Inherits the shared agent base, so both harnesses reach the same places: a
# difference in what an agent can see should be a decision, not a side effect of
# which profile it happened to compose. Everything below is pi-specific.
use agent

# The pi runtime lives in ~/.local/share/bun, bound by `dev`. Its control plane
# stays immutable during a managed run — `agent` already binds ~/.config
# read-only — and only the package and session locations are writable. A plain
# RW bind nested in a plain RO one wins, which is what makes these override.
RW+=( "$H/.config/pi/agent/sessions" "$H/.config/pi/agent/npm" )
RW_FILES+=( "$H/.config/pi/agent/mcp-cache.json" "$H/.config/pi/agent/run-history.jsonl" )
SANDBOX_ENV+=( "AGENT_BRANCH_PREFIX" "OPENROUTER_API_KEY" "ASTA_MCP_API_KEY" )

# agent-codex — Codex CLI. Used by `renv codex`.
#
# Do not inherit the broad `agent` profile: Codex only needs shared policy,
# its own runtime configuration, and hook receipt state.
use dev
use machinery-ro

RO+=(
  "$H/.agents"
)

# Codex records local project/trust state in config.toml; the guardrails hook
# still blocks tool-mediated writes to it. Hook skill receipts are stateful.
RW+=(
  "$H/.local/state/codex"
  "$H/.config/codex"
)
RW_FILES+=( "$H/.config/codex/config.toml" )
SANDBOX_ENV+=( "AGENT_BRANCH_PREFIX" "CODEX_HOME" "ASTA_MCP_API_KEY" )

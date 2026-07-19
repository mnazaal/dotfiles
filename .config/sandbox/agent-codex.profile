# agent-codex — Codex CLI. Used by `renv codex`.
#
# Do not inherit the broad `agent` profile: Codex only needs shared policy,
# its own runtime configuration, and hook receipt state.
use dev

RO+=(
	"$H/.agents"
	"$H/.config/codex"
)

# Codex records local project/trust state in config.toml; the guardrails hook
# still blocks tool-mediated writes to it. Hook skill receipts are stateful.
RW+=( "$H/.local/state/codex" )
RW_FILES+=( "$H/.config/codex/config.toml" )

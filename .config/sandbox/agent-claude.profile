# agent-claude — Claude Code. Used by `renv claude`, which sets
# RENV_WRAP=(sandbox -p agent-claude --).
use agent

RO+=( "$H/.local/share/claude" )          # native binary + versions
RW+=( "$H/.claude" "$H/.local/state/claude" )
RW_FILES+=( "$H/.claude.json" )
SANDBOX_ENV+=(
	"AGENT_BRANCH_PREFIX"
	"ASTA_MCP_API_KEY"
	"HEADROOM_PORT"
	"HEADROOM_ANTHROPIC_BASE_URL"
	"ANTHROPIC_BASE_URL"
	"ENABLE_TOOL_SEARCH"
	"DISABLE_AUTOUPDATER"
)

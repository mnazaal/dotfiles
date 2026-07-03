# agent-claude — Claude Code. Used by `renv claude`, which sets
# RENV_WRAP=(sandbox -p agent-claude --).
use agent

RO+=( "$H/.local/share/claude" )          # native binary + versions
RW+=( "$H/.claude" "$H/.local/state/claude" )
RW_FILES+=( "$H/.claude.json" )

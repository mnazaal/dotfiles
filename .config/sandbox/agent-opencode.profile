# agent-opencode — opencode. Used by `renv opencode`, which sets
# RENV_WRAP=(sandbox -p agent-opencode --).
# The opencode runtime lives in ~/.local/share/bun (bound by `dev`).  Do not
# inherit `agent`: OpenCode needs only its own control plane and state, not
# every project or configuration directory in $HOME.
use dev
use machinery-ro

RO+=( "$H/.agents" "$H/.config/opencode" )
RO+=( "$H/dotfiles" )
RW+=( "$H/.local/share/opencode" "$H/.local/state/opencode" )
RW+=( "$H/.cache/opencode" )
SANDBOX_ENV+=( "AGENT_BRANCH_PREFIX" "OPENROUTER_API_KEY" "ASTA_MCP_API_KEY" "EDITOR" )

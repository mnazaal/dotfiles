# agent-pi — pi. Used by `renv pi`, which sets
# RENV_WRAP=(sandbox -p agent-pi --).
# The pi runtime lives in ~/.local/share/bun (bound by `dev`).  Keep its
# control plane immutable during a managed run; only package/state locations
# need writes.
use dev

RO+=( "$H/.agents" "$H/.config/pi" )
RO+=( "$H/dotfiles" )
RW+=( "$H/.local/share/pi" "$H/.local/state/pi" )
SANDBOX_ENV+=( "AGENT_BRANCH_PREFIX" "OPENROUTER_API_KEY" "ASTA_MCP_API_KEY" )

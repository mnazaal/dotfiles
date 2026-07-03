# agent-opencode — opencode. Used by `renv opencode`, which sets
# RENV_WRAP=(sandbox -p agent-opencode --).
# The opencode runtime lives in ~/.local/share/bun (bound by `dev`).
use agent

RO+=( "$H/.config/opencode" )
RW+=( "$H/.local/share/opencode" "$H/.local/state/opencode" )

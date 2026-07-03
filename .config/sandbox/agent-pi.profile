# agent-pi — pi. Used by `renv pi`, which sets
# RENV_WRAP=(sandbox -p agent-pi --).
# The pi runtime lives in ~/.local/share/bun (bound by `dev`).
use agent

RW+=( "$H/.config/pi" "$H/.local/share/pi" "$H/.local/state/pi" )

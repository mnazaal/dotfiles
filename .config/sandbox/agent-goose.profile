# agent-goose — goose. Used by `renv goose`, which sets
# RENV_WRAP=(sandbox -p agent-goose --).
# goose has no guardrails adapter: this sandbox plus the shared git hooks are
# its entire enforcement stack. Do not inherit `agent`: goose needs only its
# own control plane and state.
use dev
use machinery-ro

RO+=( "$H/.agents" "$H/.config/goose" )
# The chatgpt_codex provider drives the codex CLI, which needs its home —
# auth.json included, same standing as agent-codex: mounted read-only, not a
# secret boundary against the codex process itself.
RO+=( "$H/.config/codex" )
RO+=( "$H/dotfiles" )
RW+=( "$H/.local/share/goose" "$H/.local/state/goose" "$H/.cache/goose" )
SANDBOX_ENV+=( "AGENT_BRANCH_PREFIX" "CODEX_HOME" "EDITOR" )

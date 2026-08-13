# shellcheck shell=bash
# Goose environment variables. Loaded by `renv goose`.

# Confine this agent's git history to goose/* branches (enforced by the shared
# git hooks in ~/.config/git/hooks).
AGENT_BRANCH_PREFIX="goose"
# The chatgpt_codex provider shells out to the codex CLI, which reads its
# auth/config from CODEX_HOME.
CODEX_HOME="${CODEX_HOME:-${XDG_CONFIG_HOME:-$HOME/.config}/codex}"
export AGENT_BRANCH_PREFIX CODEX_HOME

# goose has NO guardrails adapter (it exposes no tool-call hook API): this
# sandbox profile plus the shared git hooks are its entire enforcement stack,
# so RENV_REQUIRE_GUARDRAILS would verify assets nothing loads. Never launch
# goose outside `renv goose`.
# shellcheck disable=SC2034  # read by renv after sourcing
RENV_WRAP=(sandbox -p agent-goose --)

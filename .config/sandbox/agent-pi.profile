# agent-pi — pi. Used by `renv pi`, which sets
# RENV_WRAP=(sandbox -p agent-pi --).
#
# Inherits the shared agent base, so both harnesses reach the same places: a
# difference in what an agent can see should be a decision, not a side effect of
# which profile it happened to compose. Everything below is pi-specific.
use agent

# The pi runtime lives in ~/.local/share/bun, bound by `dev`. Its control plane
# stays immutable during a managed run — `agent` already binds ~/.config
# read-only — and only the package and session locations are writable. A plain
# RW bind nested in a plain RO one wins, which is what makes these override.
RW+=( "$H/.config/pi/agent/sessions" "$H/.config/pi/agent/npm" )
RW_FILES+=( "$H/.config/pi/agent/mcp-cache.json" "$H/.config/pi/agent/run-history.jsonl" )
# PI_CODING_AGENT_DIR is load-bearing, not a convenience. pi finds its config
# directory from it and otherwise falls back to ~/.pi/agent — a symlink that
# exists on the host and NOT inside, where $HOME is a tmpfs holding only the
# allowlist. Without it pi started with no auth.json, no settings.json and no
# mcp.json, and reported "No models available" while looking perfectly healthy.
# The writable binds above are for exactly that directory, so the profile was
# always built for pi to find it; only the variable was missing.
SANDBOX_ENV+=( "ASTA_MCP_API_KEY" "PI_CODING_AGENT_DIR" "PI_OFFLINE" "PI_SKIP_VERSION_CHECK" )

# pi runs under bubblewrap rather than podman. Not a preference: podman refuses a
# repeated mount destination, which `use agent` produces whenever cwd is a
# directory a profile also binds read-only, and its --tmpfs copies a masked store
# into RAM unless notmpcopyup is remembered. bwrap has neither trap, documents the
# bind ordering RO_LAST depends on, and is already the engine of Claude Code's own
# sandbox on this host. Verified live before this line was added: writes outside
# the allowlist reach nothing, pins survive a writable cwd bind, masked stores are
# unreadable, and a broken pin exits 78 before the command runs.
# `--engine podman` still selects the old path while it exists.
PROFILE_ENGINE=bwrap

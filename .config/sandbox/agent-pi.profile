# agent-pi — pi. Used by `renv pi`, which sets
# RENV_WRAP=(sandbox -p agent-pi --).
#
# Inherits the shared agent base, so both harnesses reach the same places: a
# difference in what an agent can see should be a decision, not a side effect of
# which profile it happened to compose. Everything below is pi-specific.
use agent

# The pi runtime lives in ~/.local/share/bun, bound by `dev`. Its CONTROL PLANE
# cannot be read-only, which an earlier version of this profile assumed: pi
# creates a lock directory beside each file it reads (settings.json.lock,
# auth.json.lock), so a read-only bind makes it report its own settings as
# invalid and abandon the OAuth availability refresh — the symptom is a bare
# "No models available" with the real cause two lines above it. It also
# REWRITES auth.json when a token refreshes, so that file cannot be pinned
# either. Bind the directory; a plain RW nested in a plain RO one wins.
#
# What still protects the machinery in here: settings.json and extensions/ are
# stow symlinks into ~/dotfiles, and machinery-ro pins those TARGETS read-only
# after every writable bind, so their contents cannot change from inside.
# Replacing a symlink itself remains possible and is deliberate circumvention,
# which this guard has never claimed to stop (see .agents/guardrails/README.md).
RW+=( "$H/.config/pi/agent" )
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

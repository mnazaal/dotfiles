#!/usr/bin/env bash
# Which environment variables cross the boundary, per profile, and that no VALUE
# ever enters argv. bwrap inherits the environment wholesale and the launcher
# subtracts from it, so the assertion here is INVERTED against what a
# whitelisting engine would need: an allowlisted name is one that does NOT
# appear in the --unsetenv list.
#
# A fake bwrap can only observe argv — the real filtering happens inside bwrap
# itself — so "the allowlisted value actually arrives" is asserted by the
# real-launch test in tests/sandbox-profile-test.sh instead, which runs the
# genuine binary and reads the environment from inside.
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

home="$tmp/home"
project="$tmp/project"
bin="$tmp/bin"
capture="$tmp/bwrap-args"
mkdir -p "$home" "$project" "$bin"

cat >"$bin/bwrap" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >"$SANDBOX_CAPTURE"
EOF
chmod +x "$bin/bwrap"

assert_profile_env() { # profile allowlisted names... -- excluded names...
	local profile=$1
	shift
	local expected=() forbidden=() name='' seen_separator=0
	for name in "$@"; do
		if [ "$name" = -- ]; then
			seen_separator=1
			continue
		fi
		if [ "$seen_separator" -eq 0 ]; then expected+=("$name"); else forbidden+=("$name"); fi
	done

	# Truncate first: the capture is what the FAKE bwrap writes, so a launch that
	# never happens leaves the previous run's file in place and every assertion
	# below then passes against stale argv. That is how an earlier version of this
	# test asserted nothing at all for one profile (found 2026-09-07).
	: >"$capture"
	(
		cd "$project"
		HOME="$home" PATH="$bin:$PATH" SANDBOX_PROFILE_PATH="$repo/.config/sandbox" \
			SANDBOX_CAPTURE="$capture" \
			ASTA_MCP_API_KEY=asta-key OPENROUTER_API_KEY=openrouter-key \
			HEADROOM_PORT=8787 PI_CODING_AGENT_DIR="$home/.config/pi/agent" \
			ANTHROPIC_BASE_URL=http://127.0.0.1:8787 ENABLE_TOOL_SEARCH=false \
			EDITOR=nvim UNRELATED_SECRET=must-not-reach-container \
			"$repo/.local/scripts/sandbox" -p "$profile" -- /bin/true
	)
	[ -s "$capture" ] || {
		printf '%s profile: the launcher never reached bwrap, so this proves nothing\n' "$profile" >&2
		exit 1
	}

	args=$(<"$capture")
	# Match whole lines: the fake writes one argv token per line, so a loose match
	# would let HEADROOM_ANTHROPIC_BASE_URL satisfy ANTHROPIC_BASE_URL.
	for name in "${expected[@]}"; do
		case $'\n'"$args" in *$'\n--unsetenv'$'\n'"$name"$'\n'*)
			printf '%s profile stripped %s, which it must forward\n' "$profile" "$name" >&2
			exit 1
			;;
		esac
	done
	for name in "${forbidden[@]}"; do
		case $'\n'"$args" in *$'\n--unsetenv'$'\n'"$name"$'\n'*) ;; *)
			printf '%s profile did not strip %s\n' "$profile" "$name" >&2
			exit 1
			;;
		esac
	done
	# Regression guard for every profile: no VALUE may appear in argv, whatever the
	# allowlist says. An argv value is readable by any process through `ps` for the
	# life of the sandbox, and --dry-run prints it verbatim; that is how a live API
	# key once reached a session transcript. Names in argv are accepted and stated.
	for secret in asta-key openrouter-key must-not-reach-container; do
		case "$args" in *"$secret"*)
			printf '%s profile leaked an environment value into argv: %s\n' "$profile" "$secret" >&2
			exit 1
			;;
		esac
	done
}

# PI_CODING_AGENT_DIR must cross or pi runs with no configuration at all.
assert_profile_env agent-pi ASTA_MCP_API_KEY PI_CODING_AGENT_DIR -- OPENROUTER_API_KEY UNRELATED_SECRET

printf 'sandbox env: the per-profile allowlist holds and no value enters argv\n'

#!/usr/bin/env bash
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

home="$tmp/home"
project="$tmp/project"
profiles="$tmp/profiles"
bin="$tmp/bin"
capture="$tmp/podman-args"
mkdir -p "$home" "$project" "$profiles" "$bin"

cat >"$profiles/scoped.profile" <<'EOF'
SANDBOX_ENV+=( "SAFE_VALUE" )
EOF

cat >"$bin/podman" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >"$SANDBOX_CAPTURE"
# Values arrive by name, so podman resolves them from its own environment.
# Record that separately to prove forwarding still works with no argv exposure.
env >"$SANDBOX_CAPTURE.env"
EOF
chmod +x "$bin/podman"

(
	cd "$project"
	HOME="$home" PATH="$bin:$PATH" SANDBOX_PROFILE_PATH="$profiles" \
		SANDBOX_CAPTURE="$capture" SAFE_VALUE=visible UNRELATED_SECRET=must-not-reach-container \
		"$repo/.local/scripts/sandbox" --backend podman -p scoped -- /bin/true
)

args=$(<"$capture")
case "$args" in
*"--env-host"*)
	printf 'sandbox forwarded the complete host environment\n' >&2
	exit 1
	;;
esac
case $'\n'"$args" in *$'\n'"SAFE_VALUE"$'\n'*) ;; *)
	printf 'sandbox did not forward the profile allowlisted variable\n' >&2
	exit 1
	;;
esac
# The value must reach the container without ever entering argv. An argv value is
# readable by any process via `ps` for the life of the container, and --dry-run
# prints it verbatim; that is how a live API key reached a session transcript.
case "$args" in *visible*)
	printf 'sandbox put an environment VALUE into the podman argv\n' >&2
	exit 1
	;;
esac
grep -qx 'SAFE_VALUE=visible' "$capture.env" || {
	printf 'the allowlisted value did not reach podman at all\n' >&2
	exit 1
}
case "$args" in
*"UNRELATED_SECRET"*)
	printf 'sandbox forwarded an unallowlisted environment variable\n' >&2
	exit 1
	;;
esac

assert_profile_env() { # profile expected names... -- forbidden names...
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

	(
		cd "$project"
		HOME="$home" PATH="$bin:$PATH" SANDBOX_PROFILE_PATH="$repo/.config/sandbox" \
			SANDBOX_CAPTURE="$capture" AGENT_BRANCH_PREFIX="test-agent" \
			ASTA_MCP_API_KEY=asta-key OPENROUTER_API_KEY=openrouter-key \
			HEADROOM_PORT=8787 \
			HEADROOM_ANTHROPIC_BASE_URL=http://127.0.0.1:8787 \
			ANTHROPIC_BASE_URL=http://127.0.0.1:8787 ENABLE_TOOL_SEARCH=false \
			DISABLE_AUTOUPDATER=1 EDITOR=nvim UNRELATED_SECRET=must-not-reach-container \
			"$repo/.local/scripts/sandbox" --backend podman -p "$profile" -- /bin/true
	)

	args=$(<"$capture")
	# Match a whole line: the fake podman writes one argv entry per line, and a
	# loose match lets HEADROOM_ANTHROPIC_BASE_URL satisfy ANTHROPIC_BASE_URL.
	for name in "${expected[@]}"; do
		case $'\n'"$args" in *$'\n'"$name"$'\n'*) ;; *)
			printf '%s profile did not forward %s\n' "$profile" "$name" >&2
			exit 1
			;;
		esac
	done
	for name in "${forbidden[@]}"; do
		case $'\n'"$args" in *$'\n'"$name"$'\n'*)
			printf '%s profile forwarded forbidden %s\n' "$profile" "$name" >&2
			exit 1
			;;
		esac
	done
	# Regression guard for every profile: no VALUE may appear in argv, whatever
	# the allowlist says. Names are forwarded; values are resolved by podman.
	for secret in asta-key openrouter-key must-not-reach-container; do
		case "$args" in *"$secret"*)
			printf '%s profile leaked an environment value into argv: %s\n' "$profile" "$secret" >&2
			exit 1
			;;
		esac
	done
}

assert_profile_env agent-claude AGENT_BRANCH_PREFIX ASTA_MCP_API_KEY HEADROOM_PORT ANTHROPIC_BASE_URL -- OPENROUTER_API_KEY UNRELATED_SECRET
assert_profile_env agent-pi AGENT_BRANCH_PREFIX OPENROUTER_API_KEY ASTA_MCP_API_KEY -- UNRELATED_SECRET

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
case "$args" in
*"SAFE_VALUE=visible"*) ;;
*)
	printf 'sandbox did not forward the profile allowlisted variable\n' >&2
	exit 1
	;;
esac
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
			CODEX_HOME="$home/.config/codex" HEADROOM_PORT=8787 \
			HEADROOM_ANTHROPIC_BASE_URL=http://127.0.0.1:8787 \
			ANTHROPIC_BASE_URL=http://127.0.0.1:8787 ENABLE_TOOL_SEARCH=false \
			DISABLE_AUTOUPDATER=1 EDITOR=nvim UNRELATED_SECRET=must-not-reach-container \
			"$repo/.local/scripts/sandbox" --backend podman -p "$profile" -- /bin/true
	)

	args=$(<"$capture")
	for name in "${expected[@]}"; do
		case "$args" in *"$name="*) ;; *)
			printf '%s profile did not forward %s\n' "$profile" "$name" >&2
			exit 1
			;;
		esac
	done
	for name in "${forbidden[@]}"; do
		case "$args" in *"$name="*)
			printf '%s profile forwarded forbidden %s\n' "$profile" "$name" >&2
			exit 1
			;;
		esac
	done
}

assert_profile_env agent-claude AGENT_BRANCH_PREFIX ASTA_MCP_API_KEY HEADROOM_PORT ANTHROPIC_BASE_URL -- OPENROUTER_API_KEY UNRELATED_SECRET
assert_profile_env agent-codex AGENT_BRANCH_PREFIX CODEX_HOME ASTA_MCP_API_KEY -- OPENROUTER_API_KEY UNRELATED_SECRET
assert_profile_env agent-opencode AGENT_BRANCH_PREFIX OPENROUTER_API_KEY ASTA_MCP_API_KEY EDITOR -- UNRELATED_SECRET
assert_profile_env agent-pi AGENT_BRANCH_PREFIX OPENROUTER_API_KEY ASTA_MCP_API_KEY -- UNRELATED_SECRET
assert_profile_env agent-goose AGENT_BRANCH_PREFIX CODEX_HOME -- OPENROUTER_API_KEY ASTA_MCP_API_KEY UNRELATED_SECRET

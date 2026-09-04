#!/usr/bin/env bash
# renv wiring for every non-claude harness: which sandbox profile, branch
# prefix, secrets and pre-args each launch carries, and that a launch dies
# rather than running bare when its guardrail assets or its wrapper are absent.
# `renv claude` keeps its own test: its --rw logic needs a git fixture.
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

bin="$tmp/bin" home="$tmp/home" config="$tmp/config" capture="$tmp/capture"
mkdir -p "$bin" "$home" "$config"
ln -s "$repo/.config/renv" "$config/renv"

cat >"$bin/pass" <<'EOF'
#!/usr/bin/env bash
[ "$1" = show ] || exit 1
printf '%s\n' "test-$2"
EOF
# Capture everything any harness cares about; each case asserts its own subset.
cat >"$bin/sandbox" <<'EOF'
#!/usr/bin/env bash
printf 'prefix=%s\nasta=%s\nopenrouter=%s\ncache=%s\n' \
	"${AGENT_BRANCH_PREFIX:-}" "${ASTA_MCP_API_KEY:-}" "${OPENROUTER_API_KEY:-}" \
	"${XDG_CACHE_HOME:-}" >"$RENV_CAPTURE"
printf '%s\n' "$@" >>"$RENV_CAPTURE"
EOF
printf '#!/usr/bin/env bash\nexit 0\n' >"$bin/pi"
chmod +x "$bin"/*

deploy_guardrails() { # [malformed]
	mkdir -p "$home/.agents/guardrails"
	touch "$home/.agents/guardrails/core.ts"
	printf '%s\n' "${1-$(printf '{"credentials": []}')}" >"$home/.agents/guardrails/sensitive-paths.json"
	printf '{"escalators": []}\n' >"$home/.agents/guardrails/dangerous-commands.json"
	printf '{"gates": []}\n' >"$home/.agents/guardrails/skill-gates.json"
}

run() { # harness [args...] -> capture on stdout
	rm -f "$capture"
	env -u XDG_CACHE_HOME \
		HOME="$home" PATH="$bin:$PATH" XDG_CONFIG_HOME="$config" RENV_CAPTURE="$capture" \
		"$repo/.local/scripts/renv" "$@"
	cat "$capture"
}

expect() { # label actual expected-substring
	case "$2" in *"$3"*) ;; *)
		printf 'renv %s: expected %s in\n%s\n' "$1" "$3" "$2" >&2
		exit 1
		;;
	esac
}

refuses() { # label harness -> renv must exit non-zero AND never reach the sandbox
	rm -f "$capture"
	if run "$2" --version >/dev/null 2>&1; then
		printf 'renv %s: launched anyway\n' "$1" >&2
		exit 1
	fi
	[ ! -e "$capture" ] || {
		printf 'renv %s: reached the sandbox\n' "$1" >&2
		exit 1
	}
}

# --- guardrail preflight: fail closed before the wrapper runs ----------------
refuses 'with no deployed guardrail assets' pi
deploy_guardrails '{not-json'
refuses 'with malformed guardrail policy' pi
deploy_guardrails

# --- per-harness wiring ------------------------------------------------------
out=$(run pi --version)
expect pi "$out" "prefix=pi"
expect pi "$out" "openrouter=test-openrouter-pi"
expect pi "$out" "$(printf -- '-p\nagent-pi\n--\n%s\n--version' "$bin/pi")"

# --- fail closed when the wrapper itself is missing --------------------------
# Without this, a PATH without `sandbox` would run the harness unconfined.
# A PATH that keeps bun (the policy checker needs it) but drops the real
# sandbox, so this fails for the reason under test and not for a missing profile.
rm "$bin/sandbox"
bare="$bin:$(dirname "$(command -v bun)"):/usr/bin:/bin"
if env HOME="$home" PATH="$bare" XDG_CONFIG_HOME="$config" \
	RENV_CAPTURE="$capture" "$repo/.local/scripts/renv" pi --version >/dev/null 2>&1; then
	printf 'renv ran pi unconfined with no sandbox on PATH\n' >&2
	exit 1
fi

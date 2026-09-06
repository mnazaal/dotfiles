#!/usr/bin/env bash
# renv wiring for every non-claude harness: which sandbox profile, secrets and
# pre-args each launch carries, and that a launch dies rather than running bare
# when its wrapper is absent.
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
printf 'asta=%s\nopenrouter=%s\ncache=%s\n' \
	"${ASTA_MCP_API_KEY:-}" "${OPENROUTER_API_KEY:-}" \
	"${XDG_CACHE_HOME:-}" >"$RENV_CAPTURE"
printf '%s\n' "$@" >>"$RENV_CAPTURE"
EOF
printf '#!/usr/bin/env bash\nexit 0\n' >"$bin/pi"
chmod +x "$bin"/*

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

# --- per-harness wiring ------------------------------------------------------
out=$(run pi --version)
expect pi "$out" "$(printf -- '-p\nagent-pi\n--\n%s\n--version' "$bin/pi")"

# --- the editor's ACP launcher ------------------------------------------------
# It sources its CLI sibling for one policy definition, then drops the sibling's
# --permission-mode: that is a flag of the CLI and not of the adapter, so passing
# it through would abort the launch. The sandbox wrapper must survive, or the
# editor path would run unconfined while looking identical.
# The SHIPPED editor launcher, not a stand-in. $config/renv is symlinked at the
# real repository above, so this loads the pi-acp.sh that actually deploys: it
# sources pi.sh for one definition of the policy, then drops the CLI-only
# --permission-mode, which is a flag of the CLI and not of the adapter and would
# abort the launch. The sandbox wrapper has to survive that, or the editor path
# would run unconfined while looking identical to the terminal one.
printf '#!/usr/bin/env bash\nexit 0\n' >"$bin/pi-acp"
chmod +x "$bin/pi-acp"

out=$(run pi-acp --version)
expect pi-acp "$out" "$(printf -- '-p\nagent-pi\n--\n%s\n--version' "$bin/pi-acp")"
case "$out" in *--permission-mode*)
	printf 'renv pi-acp: a CLI-only --permission-mode reached the adapter\n' >&2
	exit 1
	;;
esac

# What claude-agent-acp.sh passes through is now asserted behaviourally, by
# renv-claude-test.sh, which stubs headroom-ensure so sourcing claude.sh does
# not start a real proxy. A grep for `unset RENV_PRE_ARGS` used to stand in for it
# here; that assertion pinned a contract that turned out to be the bug -- the
# unset also discarded the native-sandbox override the editor path needs -- so
# the proxy is gone and only the sourcing relationship is checked here.
claude_acp="$repo/.config/renv/claude-agent-acp.sh"
grep -q 'renv/claude\.sh"$' "$claude_acp" || {
	printf 'renv: %s no longer sources its CLI sibling\n' "$claude_acp" >&2
	exit 1
}

# --- fail closed when the wrapper itself is missing --------------------------
# Without this, a PATH without `sandbox` would run the harness unconfined.
rm "$bin/sandbox"
bare="$bin:/usr/bin:/bin"
if env HOME="$home" PATH="$bare" XDG_CONFIG_HOME="$config" \
	RENV_CAPTURE="$capture" "$repo/.local/scripts/renv" pi --version >/dev/null 2>&1; then
	printf 'renv ran pi unconfined with no sandbox on PATH\n' >&2
	exit 1
fi

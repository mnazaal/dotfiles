#!/usr/bin/env bash
# The pi shim is the only thing between typing `pi` and an unconfined agent, so
# assert the wrapper it builds, the key it resolves, and every path that must
# refuse rather than launch bare. Replaces the renv coverage this shim retired.
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
shim="$repo/.local/scripts/pi"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

bin="$tmp/bin" bun="$tmp/bun" capture="$tmp/capture"
mkdir -p "$bin" "$bun/bin"

cat >"$bin/pass" <<'EOF'
#!/usr/bin/env bash
[ "$1" = show ] || exit 1
printf '%s\n' "secret-$2"
EOF
# Stands in for the real launcher: records the environment that crossed and the
# argv it was handed, which is the whole contract under test.
cat >"$bin/sandbox" <<EOF
#!/usr/bin/env bash
printf 'asta=%s\n' "\${ASTA_MCP_API_KEY:-}" >"$capture"
printf '%s\n' "\$@" >>"$capture"
EOF
cat >"$bun/bin/pi" <<'EOF'
#!/usr/bin/env bash
printf 'real-pi-ran %s\n' "$*"
EOF
chmod +x "$bin"/* "$bun/bin/pi"

run_shim() { # args... -> shim stdout; sandbox argv lands in $capture
	rm -f "$capture"
	env -u SANDBOX_ENGINE -u SANDBOX_RUNTIME \
		PATH="$bin:$PATH" BUN_INSTALL="$bun" "$shim" "$@"
}

fail() { # message -> report and stop
	printf 'pi shim: %s\n' "$1" >&2
	exit 1
}

expect() { # label haystack needle
	case "$2" in *"$3"*) ;; *)
		printf 'pi shim %s: expected %s in\n%s\n' "$1" "$3" "$2" >&2
		exit 1
		;;
	esac
}

refuses() { # label -> non-zero exit AND the sandbox never reached
	rm -f "$capture"
	if "$@" >/dev/null 2>&1; then
		printf 'pi shim %s: launched anyway\n' "$1" >&2
		exit 1
	fi
	[ ! -e "$capture" ] || {
		printf 'pi shim %s: reached the sandbox\n' "$1" >&2
		exit 1
	}
}

# --- the wrapper it builds ---------------------------------------------------
# The real binary must be named ABSOLUTELY: this shim shadows `pi` on PATH, so a
# lookup would find the shim and re-exec it forever.
run_shim --version >/dev/null
args=$(<"$capture")
expect 'resolves the key outside the boundary' "$args" 'asta=secret-asta-mcp'
expect 'selects the pi profile' "$args" $'-p\nagent-pi'
expect 'runs the real binary absolutely' "$args" "$bun/bin/pi"
expect 'passes arguments through' "$args" '--version'

# --- fail closed -------------------------------------------------------------
# Each of these leaves "run pi with no boundary" as the only alternative.
mv "$bin/sandbox" "$tmp/sandbox.hidden"
refuses 'without a sandbox on PATH' env -u SANDBOX_ENGINE -u SANDBOX_RUNTIME \
	PATH="$bin:$PATH" BUN_INSTALL="$bun" "$shim" --version
mv "$tmp/sandbox.hidden" "$bin/sandbox"

printf '#!/usr/bin/env bash\nexit 1\n' >"$bin/pass"
chmod +x "$bin/pass"
refuses 'when the key cannot be read' env -u SANDBOX_ENGINE -u SANDBOX_RUNTIME \
	PATH="$bin:$PATH" BUN_INSTALL="$bun" "$shim" --version
cat >"$bin/pass" <<'EOF'
#!/usr/bin/env bash
[ "$1" = show ] || exit 1
printf '%s\n' "secret-$2"
EOF
chmod +x "$bin/pass"

refuses 'when the real binary is missing' env -u SANDBOX_ENGINE -u SANDBOX_RUNTIME \
	PATH="$bin:$PATH" BUN_INSTALL="$tmp/absent" "$shim" --version

# --- already inside a boundary ----------------------------------------------
# Nesting a second bubblewrap fails, and the outer sandbox already confines the
# process, so the shim must step aside rather than wrap again.
rm -f "$capture"
out=$(env -u SANDBOX_RUNTIME SANDBOX_ENGINE=bwrap \
	PATH="$bin:$PATH" BUN_INSTALL="$bun" "$shim" --version)
expect 'runs the real binary directly when sandboxed' "$out" 'real-pi-ran --version'
[ ! -e "$capture" ] || {
	printf 'pi shim: nested a second sandbox inside the first\n' >&2
	exit 1
}

# Deployed under both names, so assert the dispatch: the ACP adapter the editors
# spawn must get the same policy, and the real binary it runs must follow the
# name the shim was invoked as rather than being hardcoded to `pi`.
cat >"$bun/bin/pi-acp" <<'EOF'
#!/usr/bin/env bash
printf 'real-pi-acp-ran %s\n' "$*"
EOF
chmod +x "$bun/bin/pi-acp"
ln -sf pi "$tmp/pi-acp"
cp "$shim" "$tmp/pi"
rm -f "$capture"
env -u SANDBOX_ENGINE -u SANDBOX_RUNTIME \
	PATH="$bin:$PATH" BUN_INSTALL="$bun" "$tmp/pi-acp" --version
args=$(<"$capture")
expect 'the acp name selects the acp binary' "$args" "$bun/bin/pi-acp"
expect 'the acp name still selects the pi profile' "$args" $'-p\nagent-pi'

# --- pi's guardrail adapter: the two properties nothing else covers ----------
# This file is pi's ONLY enforcement layer -- it has no native permission layer
# to fall back on -- and it had no test at all. Both properties below fail
# silently: an unguarded pi looks exactly like a guarded one until something
# destructive is allowed, and an empty branch prefix reads to the shared git
# hooks as a HUMAN committing, which is precisely what they exist to stop.
ext="$repo/.config/pi/agent/extensions/guardrails.ts"
[ -f "$ext" ] || fail "pi guardrails extension missing: $ext"

# The prefix must be set in the agent process itself, since the launcher that
# used to set it is gone and the bash tool spreads process.env per spawn.
grep -q 'process\.env\.AGENT_BRANCH_PREFIX = "pi"' "$ext" ||
	fail "the pi extension must set AGENT_BRANCH_PREFIX=pi in-process"

# Fail-closed launch: createGuardrails runs at import, and loadJson throws on a
# missing or malformed policy, so pi aborts rather than starting unguarded.
# Driven, not grepped -- the claim is about what an import DOES.
probe="$tmp/failclosed"
mkdir -p "$probe/.agents/guardrails"
cp "$repo/.agents/guardrails/core.ts" "$probe/.agents/guardrails/core.ts"
for f in sensitive-paths.json dangerous-commands.json skill-gates.json; do
	cp "$repo/.agents/guardrails/$f" "$probe/.agents/guardrails/$f"
done
cat >"$probe/import.ts" <<'PROBE'
import { createGuardrails } from "./.agents/guardrails/core.ts";
createGuardrails("pi");
console.log("imported");
PROBE
if ! (cd "$probe" && HOME="$probe" bun run import.ts >/dev/null 2>&1); then
	fail "the guardrail factory should import cleanly with a well-formed policy"
fi
printf 'not json {{{' >"$probe/.agents/guardrails/dangerous-commands.json"
if (cd "$probe" && HOME="$probe" bun run import.ts >/dev/null 2>&1); then
	fail "a malformed policy must abort the agent, not start it unguarded"
fi
rm -f "$probe/.agents/guardrails/dangerous-commands.json"
if (cd "$probe" && HOME="$probe" bun run import.ts >/dev/null 2>&1); then
	fail "a missing policy must abort the agent, not start it unguarded"
fi

printf 'pi shim: all behaviors pass\n'

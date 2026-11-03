#!/usr/bin/env bash
# Pi itself runs on the host like Claude; only its Bash tool is sandboxed.
# Assert both launch paths, no ambient MCP key, and fail-closed guardrails.
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
shim="$repo/.local/scripts/pi"
shell="$repo/.local/scripts/pi-bash"
settings="$repo/.config/pi/agent/settings.json"
models_config="$repo/.config/pi/agent/models.json"
mcp_config="$repo/.config/pi/agent/mcp.json"
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

bin="$tmp/bin" bun="$tmp/bun" capture="$tmp/capture" shell_capture="$tmp/shell-capture"
mkdir -p "$bin" "$bun/bin"

cat >"$bin/pass" <<'EOF'
#!/usr/bin/env bash
[ "$1" = show ] || exit 1
printf '%s\n' "secret-$2"
EOF
cat >"$bin/sandbox" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$@" >"$shell_capture"
EOF
cat >"$bun/bin/pi" <<EOF
#!/usr/bin/env bash
printf 'asta=%s\n' "\${ASTA_MCP_API_KEY:-}" >"$capture"
printf 'bun_install=%s\n' "\${BUN_INSTALL:-}" >>"$capture"
printf '%s\n' "\$@" >>"$capture"
printf 'real-pi-ran %s\n' "\$*"
EOF
chmod +x "$bin"/* "$bun/bin/pi"

run_shim() { # args... -> shim stdout; real-pi environment/argv lands in $capture
	rm -f "$capture"
	env -u SANDBOX_ENGINE -u SANDBOX_RUNTIME -u ASTA_MCP_API_KEY \
		PATH="$bin:$PATH" BUN_INSTALL="$bun" "$shim" "$@"
}

fail() {
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

refuses() { # label command...
	local label=$1
	shift
	if "$@" >/dev/null 2>&1; then
		printf 'pi shim %s: launched anyway\n' "$label" >&2
		exit 1
	fi
}

# The top-level Pi process stays on the host, exports Bun's root, and never
# passes the MCP key through its environment; Pi resolves it only on connect.
run_shim --version >/dev/null
[ -s "$capture" ] || fail 'top-level Pi never reached the real binary directly'
args=$(<"$capture")
[ "${args%%$'\n'*}" = 'asta=' ] || fail 'top-level Pi received an ambient MCP key'
expect 'exports the Bun install root' "$args" "bun_install=$bun"
expect 'runs the real binary directly' "$args" '--version'

out=$(env -u SANDBOX_ENGINE -u SANDBOX_RUNTIME ASTA_MCP_API_KEY=fake-ambient \
	PATH="$bin:$PATH" BUN_INSTALL="$bun" "$shim" --version)
args=$(<"$capture")
[ "${args%%$'\n'*}" = 'asta=' ] || fail 'shim passed through a pre-existing MCP key'
expect 'still launches with a pre-existing key' "$out" 'real-pi-ran --version'

# Self-update follows the same host path; there is no updater exception or
# package-specific sandbox profile.
run_shim update pi >/dev/null
args=$(<"$capture")
expect 'self-update reaches the real Pi process' "$args" $'update\npi'
expect 'self-update sees the managed Bun root' "$args" "bun_install=$bun"

# The host process no longer depends on the sandbox launcher existing.
mv "$bin/sandbox" "$tmp/sandbox.hidden"
run_shim --version >/dev/null
mv "$tmp/sandbox.hidden" "$bin/sandbox"

# With no explicit BUN_INSTALL, the executable path and exported manager root
# must resolve to the same XDG data location.
default_home="$tmp/default-home"
default_bun="$default_home/.local/share/bun"
mkdir -p "$default_bun/bin"
cp "$bun/bin/pi" "$default_bun/bin/pi"
rm -f "$capture"
env -u SANDBOX_ENGINE -u SANDBOX_RUNTIME -u ASTA_MCP_API_KEY \
	-u BUN_INSTALL -u XDG_DATA_HOME HOME="$default_home" PATH="$bin:$PATH" \
	"$shim" --version >/dev/null
args=$(<"$capture")
expect 'exports the default Bun root' "$args" "bun_install=$default_bun"

# Starting Pi does not need pass; only the missing real binary blocks launch.
printf '#!/usr/bin/env bash\nexit 1\n' >"$bin/pass"
chmod +x "$bin/pass"
run_shim --version >/dev/null || fail 'launcher still depends on pass'
refuses 'when the real binary is missing' env -u SANDBOX_ENGINE -u SANDBOX_RUNTIME \
	-u ASTA_MCP_API_KEY PATH="$bin:$PATH" BUN_INSTALL="$tmp/absent" "$shim" --version

# A nested Pi launched by a sandboxed Bash command must not try to read the
# masked password store. It inherits the existing boundary and runs directly.
rm -f "$capture"
out=$(env -u SANDBOX_RUNTIME -u ASTA_MCP_API_KEY SANDBOX_ENGINE=bwrap \
	PATH="$bin:$PATH" BUN_INSTALL="$bun" "$shim" --version)
expect 'runs directly when already sandboxed' "$out" 'real-pi-ran --version'
args=$(<"$capture")
[ "${args%%$'\n'*}" = 'asta=' ] || fail 'nested Pi received an ambient MCP key'

# Both deployed names keep the same host-process policy while selecting their
# corresponding real executable.
cat >"$bun/bin/pi-acp" <<EOF
#!/usr/bin/env bash
printf 'asta=%s\n' "\${ASTA_MCP_API_KEY:-}" >"$capture"
printf 'bun_install=%s\n' "\${BUN_INSTALL:-}" >>"$capture"
printf '%s\n' "\$@" >>"$capture"
printf 'real-pi-acp-ran %s\n' "\$*"
EOF
chmod +x "$bun/bin/pi-acp"
ln -sf pi "$tmp/pi-acp"
cp "$shim" "$tmp/pi"
rm -f "$capture"
out=$(env -u SANDBOX_ENGINE -u SANDBOX_RUNTIME -u ASTA_MCP_API_KEY \
	PATH="$bin:$PATH" BUN_INSTALL="$bun" "$tmp/pi-acp" --version)
args=$(<"$capture")
expect 'the acp name selects the acp binary' "$out" 'real-pi-acp-ran --version'
expect 'the acp path still exports the Bun root' "$args" "bun_install=$bun"

# Pi's native shellPath setting sends model Bash and !/!! commands here. The
# adapter preserves Bash argv exactly and selects the shared agent profile.
[ -x "$shell" ] || fail "sandboxed shell missing or not executable: $shell"
rm -f "$shell_capture"
PATH="$bin:$PATH" "$shell" -c 'printf shell-ran' >/dev/null
args=$(<"$shell_capture")
expect 'sandboxed shell selects the agent profile' "$args" $'-p\nagent'
expect 'sandboxed shell invokes Bash after the boundary' "$args" $'--\n/bin/bash'
expect 'sandboxed shell preserves -c and its script' "$args" $'-c\nprintf shell-ran'

# Configuration is part of the public behavior: both Bash entry points must
# use the adapter, and the MCP key must resolve from pass only at connection.
python3 - "$settings" "$models_config" "$mcp_config" <<'PY'
import json
import sys

settings = json.load(open(sys.argv[1], encoding="utf-8"))
assert settings.get("shellPath") == "~/.local/scripts/pi-bash"
assert settings.get("defaultModel") == "gpt-6-sol"
models = settings.get("enabledModels", [])
expected = {
    "openai-codex/gpt-6-sol",
    "openai-codex/gpt-6-astra",
    "openai-codex/gpt-6-luna",
}
assert expected <= set(models)
assert not any("gpt-5.6" in model for model in models)
assert settings["piClaudePermissions"]["planModeAllowedMcpServers"] == ["asta-mcp"]
model_config = json.load(open(sys.argv[2], encoding="utf-8"))
assert "gpt-5.6" not in json.dumps(model_config)
mcp_config = json.load(open(sys.argv[3], encoding="utf-8"))
assert set(mcp_config["mcpServers"]) == {"asta-mcp"}
assert mcp_config["mcpServers"]["asta-mcp"]["headers"]["x-api-key"] == "!pass show asta-mcp"
PY

# A non-zsh caller may lack PI_CODING_AGENT_DIR. The package check must still
# inspect this repo's deployed XDG config, not silently skip ~/.pi/agent.
package_home="$tmp/package-home"
mkdir -p "$package_home/.config/pi/agent/npm"
if env -u PI_CODING_AGENT_DIR HOME="$package_home" \
	XDG_CONFIG_HOME="$package_home/.config" make -s -C "$repo" check-pi-packages >"$tmp/package-check.out" 2>&1; then
	fail 'package check skipped an active XDG Pi install missing every package'
fi
grep -q 'pi-package drift:' "$tmp/package-check.out" ||
	fail 'package check failed for a reason other than missing packages'

# --- pi's guardrail adapter: the two properties nothing else covers ----------
# This file is pi's ONLY enforcement layer for typed file tools. Both properties
# below fail silently: an unguarded pi looks healthy until a protected write is
# allowed, and an empty branch prefix reads to shared hooks as a HUMAN commit.
ext="$repo/.config/pi/agent/extensions/guardrails.ts"
[ -f "$ext" ] || fail "pi guardrails extension missing: $ext"

grep -q 'process\.env\.AGENT_BRANCH_PREFIX = "pi"' "$ext" ||
	fail "the pi extension must set AGENT_BRANCH_PREFIX=pi in-process"
# Setting it on the host process is not enough: pi's Bash runs under the real
# sandbox, which drops every variable not on its allowlist.
got=$(cd "$tmp" && AGENT_BRANCH_PREFIX=pi PATH="$repo/.local/scripts:$PATH" \
	SANDBOX_PROFILE_PATH="$repo/.config/sandbox" \
	"$shell" -c 'printf "%s" "${AGENT_BRANCH_PREFIX-unset}"') ||
	fail "pi-bash could not launch the sandbox"
[ "$got" = pi ] || fail "AGENT_BRANCH_PREFIX does not reach pi's Bash (got: $got)"

# Fail-closed launch: createGuardrails runs at import, and loadJson throws on a
# missing or malformed policy, so a throw stops pi rather than starting it
# unguarded. Driven, not grepped -- the claim is about what an import DOES.
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

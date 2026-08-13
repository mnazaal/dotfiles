#!/usr/bin/env bash
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

bin="$tmp/bin"
home="$tmp/home"
config="$tmp/config"
capture="$tmp/sandbox-ran"
mkdir -p "$bin" "$home" "$config"
ln -s "$repo/.config/renv" "$config/renv"

cat >"$bin/pass" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' test-key
EOF

cat >"$bin/sandbox" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
touch "$RENV_CAPTURE"
EOF

cat >"$bin/codex" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
exit 0
EOF
chmod +x "$bin/pass" "$bin/sandbox" "$bin/codex"

if HOME="$home" PATH="$bin:$PATH" XDG_CONFIG_HOME="$config" RENV_CAPTURE="$capture" \
	"$repo/.local/scripts/renv" codex --version >/dev/null 2>&1; then
	printf 'renv launched Codex without deployed guardrail assets\n' >&2
	exit 1
fi

[ ! -e "$capture" ] || {
	printf 'renv invoked the sandbox before guardrail preflight completed\n' >&2
	exit 1
}

mkdir -p "$home/.agents/guardrails"
touch "$home/.agents/guardrails/core.ts"
printf '{not-json\n' >"$home/.agents/guardrails/sensitive-paths.json"
printf '{"escalators": []}\n' >"$home/.agents/guardrails/dangerous-commands.json"
printf '{"gates": []}\n' >"$home/.agents/guardrails/skill-gates.json"

if HOME="$home" PATH="$bin:$PATH" XDG_CONFIG_HOME="$config" RENV_CAPTURE="$capture" \
	"$repo/.local/scripts/renv" codex --version >/dev/null 2>&1; then
	printf 'renv launched Codex with malformed guardrail policy\n' >&2
	exit 1
fi

[ ! -e "$capture" ] || {
	printf 'renv invoked the sandbox with malformed guardrail policy\n' >&2
	exit 1
}

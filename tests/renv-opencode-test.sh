#!/usr/bin/env bash
set -euo pipefail

repo=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

bin="$tmp/bin"
home="$tmp/home"
config="$tmp/config"
capture="$tmp/capture"
mkdir -p "$bin" "$home" "$config"
ln -s "$repo/.config/renv" "$config/renv"

cat >"$bin/pass" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "$2" in
openrouter-opencode|asta-mcp) printf 'test-key\n' ;;
*) exit 1 ;;
esac
EOF

cat >"$bin/sandbox" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'cache=%s\n' "${XDG_CACHE_HOME:-}" >"$RENV_CAPTURE"
EOF

cat >"$bin/opencode" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$bin/pass" "$bin/sandbox" "$bin/opencode"

mkdir -p "$home/.agents/guardrails"
touch "$home/.agents/guardrails/core.ts"
printf '{"credentials": []}\n' >"$home/.agents/guardrails/sensitive-paths.json"
printf '{"escalators": []}\n' >"$home/.agents/guardrails/dangerous-commands.json"
printf '{"gates": []}\n' >"$home/.agents/guardrails/skill-gates.json"

env -u XDG_CACHE_HOME \
	HOME="$home" PATH="$bin:$PATH" XDG_CONFIG_HOME="$config" RENV_CAPTURE="$capture" \
	"$repo/.local/scripts/renv" opencode -c

expected="cache=$home/.cache/opencode"
actual=$(<"$capture")
[ "$actual" = "$expected" ] || {
	printf 'unexpected OpenCode cache location:\n%s\n' "$actual" >&2
	exit 1
}

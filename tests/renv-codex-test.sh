#!/usr/bin/env bash
set -euo pipefail

repo=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

bin="$tmp/bin"
config="$tmp/config"
capture="$tmp/capture"
mkdir -p "$bin" "$config"
ln -s "$repo/.config/renv" "$config/renv"

cat >"$bin/pass" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[ "$1" = show ] && [ "$2" = asta-mcp ] || exit 1
printf '%s\n' test-asta-key
EOF

cat >"$bin/sandbox" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'prefix=%s\n' "${AGENT_BRANCH_PREFIX:-}" >"$RENV_CAPTURE"
printf 'asta=%s\n' "${ASTA_MCP_API_KEY:-}" >>"$RENV_CAPTURE"
printf 'codex_home=%s\n' "${CODEX_HOME:-}" >>"$RENV_CAPTURE"
printf '%s\n' "$@" >>"$RENV_CAPTURE"
EOF

cat >"$bin/codex" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$bin/pass" "$bin/sandbox" "$bin/codex"

env -u CODEX_HOME \
	PATH="$bin:$PATH" \
	XDG_CONFIG_HOME="$config" \
	RENV_CAPTURE="$capture" \
	"$repo/.local/scripts/renv" codex --version

expected=$(cat <<EOF
prefix=codex
asta=test-asta-key
codex_home=$config/codex
-p
agent-codex
--
$bin/codex
--sandbox
danger-full-access
--ask-for-approval
never
--version
EOF
)

actual=$(<"$capture")
[ "$actual" = "$expected" ] || {
	printf 'unexpected renv codex invocation:\n%s\n' "$actual" >&2
	exit 1
}

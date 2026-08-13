#!/usr/bin/env bash
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

bin="$tmp/bin"
home="$tmp/home"
config="$tmp/config"
capture="$tmp/capture"
mkdir -p "$bin" "$home" "$config"
ln -s "$repo/.config/renv" "$config/renv"

cat >"$bin/sandbox" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'profile=%s\nprefix=%s\ncodex_home=%s\n' \
	"$2" "${AGENT_BRANCH_PREFIX:-}" "${CODEX_HOME:-}" >"$RENV_CAPTURE"
EOF

cat >"$bin/goose" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$bin/sandbox" "$bin/goose"

env -u CODEX_HOME \
	HOME="$home" PATH="$bin:$PATH" XDG_CONFIG_HOME="$config" RENV_CAPTURE="$capture" \
	"$repo/.local/scripts/renv" goose --version

expected="profile=agent-goose
prefix=goose
codex_home=$config/codex"
actual=$(<"$capture")
[ "$actual" = "$expected" ] || {
	printf 'unexpected goose renv wiring:\n%s\n' "$actual" >&2
	exit 1
}

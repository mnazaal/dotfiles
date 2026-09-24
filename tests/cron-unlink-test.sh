#!/usr/bin/env bash
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
home="$tmp/home"
mkdir -p "$tmp/bin" "$home/.local" "$home/.cache"
cat >"$tmp/bin/getent" <<'SH'
#!/bin/sh
printf 'fixture:x:1000:1000:Fixture:%s:/bin/sh\n' "$HOME"
SH
cat >"$tmp/bin/crontab" <<'SH'
#!/bin/sh
set -eu
printf '%s\n' "$1" >>"$MOCK_TRACE"
case "$1" in
-l) cat "$MOCK_LIVE" ;;
-n) ! grep -q INVALID "$2" ;;
*) cp "$1" "$MOCK_LIVE" ;;
esac
SH
chmod +x "$tmp/bin/getent" "$tmp/bin/crontab"
export HOME="$home" PATH="$tmp/bin:$PATH" MOCK_LIVE="$tmp/live" MOCK_TRACE="$tmp/trace"
printf '* * * * * /bin/true\n0 0 * * * /bin/echo owned\n' >"$home/.local/cron"
printf '# personal header\n15 8 * * * /bin/echo personal\n' >"$MOCK_LIVE"
cat "$home/.local/cron" >>"$MOCK_LIVE"

# Cleanup refuses before it can remove links while jobs still run.
if make --no-print-directory -C "$repo" check-clean-cron HOME="$home" >"$tmp/out" 2>"$tmp/err"; then
	printf 'clean accepted an active tracked job\n' >&2
	exit 1
fi
[ ! -s "$MOCK_TRACE" ] || [ "$(cat "$MOCK_TRACE")" = '-l' ]

make --no-print-directory -C "$repo" cron-unlink HOME="$home" >"$tmp/out" 2>"$tmp/err" || {
	cat "$tmp/err" >&2
	exit 1
}
printf '# personal header\n15 8 * * * /bin/echo personal\n' | cmp - "$MOCK_LIVE"
[ ! -e "$home/.cache/dotfiles/cron-before-unlink" ]
make --no-print-directory -C "$repo" check-clean-cron HOME="$home" >"$tmp/out" 2>"$tmp/err"

# A renamed tracked entry must not hide a still-scheduled dotfiles script.
printf '15 8 * * * "$HOME/.local/scripts/old-job"\n' >>"$MOCK_LIVE"
if make --no-print-directory -C "$repo" check-clean-cron HOME="$home" >"$tmp/out" 2>"$tmp/err"; then
	printf 'clean missed a stale dotfiles cron entry\n' >&2
	exit 1
fi

# A partial match is ambiguous; do not alter any live job.
printf '* * * * * /bin/true\n15 8 * * * /bin/echo personal\n' >"$MOCK_LIVE"
if make --no-print-directory -C "$repo" cron-unlink HOME="$home" >"$tmp/out" 2>"$tmp/err"; then
	printf 'cron-unlink accepted a partially installed schedule\n' >&2
	exit 1
fi
printf '* * * * * /bin/true\n15 8 * * * /bin/echo personal\n' | cmp - "$MOCK_LIVE"

printf 'cron unlink: clean guard, owned removal and drift refusal pass\n'

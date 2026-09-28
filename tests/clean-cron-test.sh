#!/usr/bin/env bash
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
home="$tmp/home"
mkdir -p "$tmp/bin" "$home/.cache"
# The fixture home stands in for the login home, so link and clean reach the
# mocked crontab rather than skipping it.
cat >"$tmp/bin/getent" <<'SH'
#!/bin/sh
printf 'fixture:x:1000:1000:Fixture:%s:/bin/sh\n' "$HOME"
SH
cat >"$tmp/bin/crontab" <<'SH'
#!/bin/sh
set -eu
case "$1" in
-l)
	[ -z "${MOCK_READ_ERROR:-}" ] || { echo 'crontab: permission denied' >&2; exit 1; }
	[ -e "$MOCK_LIVE" ] || { echo 'no crontab for fixture' >&2; exit 1; }
	cat "$MOCK_LIVE"
	;;
-n) ;;
-r) [ -e "$MOCK_LIVE" ] || { echo 'no crontab for fixture' >&2; exit 1; }; rm "$MOCK_LIVE" ;;
*) cp "$1" "$MOCK_LIVE" ;;
esac
SH
chmod +x "$tmp/bin/getent" "$tmp/bin/crontab"
export HOME="$home" PATH="$tmp/bin:$PATH" MOCK_LIVE="$tmp/live"
run() { make --no-print-directory -C "$repo" "$@" HOME="$home" >"$tmp/out" 2>"$tmp/err"; }
fail() { printf '%s\n' "$1" >&2; cat "$tmp/err" >&2; exit 1; }

# link installs the tracked file as the whole crontab; clean removes it.
run link || fail 'make link failed'
cmp "$repo/.local/cron" "$MOCK_LIVE"
run clean || fail 'make clean refused the crontab link installed'
[ ! -e "$MOCK_LIVE" ] || fail 'make clean left the crontab installed'
[ ! -L "$home/.local/cron" ] || fail 'make clean left the links behind'

# A second clean finds no crontab and no links, and still succeeds.
run clean || fail 'make clean is not idempotent'

# A hand-added job blocks the whole clean: neither the job nor any link goes.
# The job's text is not echoed, since it may carry a credential.
run link || fail 'make link failed'
printf '15 8 * * * /bin/echo personal-secret\n' >>"$MOCK_LIVE"
cp "$MOCK_LIVE" "$tmp/expected"
if run clean; then fail 'make clean removed a hand-added cron job'; fi
cmp "$tmp/expected" "$MOCK_LIVE"
[ -L "$home/.local/cron" ] || fail 'a refused clean still removed links'
grep -q '1 live job(s) not in .local/cron' "$tmp/err" || fail 'refusal did not count the hand-added job'
! grep -q personal-secret "$tmp/err" || fail 'refusal printed a live job'

# A tracked job missing from the live crontab is drift too, and is named.
first_job=$(grep -v -e '^#' -e '^[[:space:]]*$' "$repo/.local/cron" | head -n 1)
grep -vxF -- "$first_job" "$repo/.local/cron" >"$MOCK_LIVE"
if run clean; then fail 'make clean accepted a partially installed crontab'; fi
grep -qF "tracked but not live: $first_job" "$tmp/err" || fail 'refusal did not name the missing job'

# An unreadable crontab is not the same as no crontab.
cp "$repo/.local/cron" "$MOCK_LIVE"
if MOCK_READ_ERROR=1 run clean; then fail 'make clean ignored an unreadable crontab'; fi
[ -L "$home/.local/cron" ] || fail 'a refused clean still removed links'

printf 'clean cron: removal, idempotence, and drift and read-error refusal pass\n'

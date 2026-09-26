#!/usr/bin/env bash
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/home"

cat >"$tmp/bin/crontab" <<'SH'
#!/bin/sh
set -eu
printf '%s\n' "$1" >>"$MOCK_TRACE"
case "$1" in
-l)
    if [ -f "$MOCK_DENIED" ]; then
        printf 'You (fixture) are not allowed to access to (crontab) because of pam configuration.\n' >&2
        exit 1
    fi
    if [ -f "$MOCK_READ_ERROR" ]; then
        printf 'crontab: permission denied\n' >&2
        exit 1
    fi
    if [ ! -f "$MOCK_LIVE" ]; then
        printf 'no crontab for fixture\n' >&2
        exit 1
    fi
    cat "$MOCK_LIVE"
    ;;
-n)
    if grep -q INVALID "$2"; then
        printf 'bad crontab\n' >&2
        exit 1
    fi
    ;;
*)
    cp "$1" "$MOCK_LIVE"
    ;;
esac
SH
cat >"$tmp/bin/notify-send" <<'SH'
#!/bin/sh
exit 0
SH
chmod +x "$tmp/bin/crontab" "$tmp/bin/notify-send"

export HOME="$tmp/home" PATH="$tmp/bin:$PATH" CRON_FILE="$tmp/cron"
export MOCK_LIVE="$tmp/live" MOCK_TRACE="$tmp/trace" MOCK_READ_ERROR="$tmp/read-error" MOCK_DENIED="$tmp/denied"
printf '* * * * * /bin/true\n' >"$CRON_FILE"

# First deployment has no crontab. It must validate and install the tracked one.
"$repo/.local/scripts/crontab-sync" >"$tmp/out" 2>"$tmp/err" || {
	printf 'crontab-sync failed on an empty account:\n' >&2
	cat "$tmp/err" >&2
	exit 1
}
cmp "$CRON_FILE" "$MOCK_LIVE"
grep -qx -- '-n' "$MOCK_TRACE"

# No change means no validation or install, even if the live copy has comments.
printf '# cron header\n' >"$MOCK_LIVE"
cat "$CRON_FILE" >>"$MOCK_LIVE"
: >"$MOCK_TRACE"
"$repo/.local/scripts/crontab-sync" >"$tmp/out" 2>"$tmp/err"
[ "$(cat "$MOCK_TRACE")" = '-l' ]

# A changed schedule is validated before installation.
printf '0 0 * * * /bin/false\n' >"$MOCK_LIVE"
: >"$MOCK_TRACE"
"$repo/.local/scripts/crontab-sync" >"$tmp/out" 2>"$tmp/err"
cmp "$CRON_FILE" "$MOCK_LIVE"
[ "$(cat "$MOCK_TRACE")" = "$(printf '%s\n' '-l' '-n' "$CRON_FILE")" ]

# A broken tracked file must leave the live schedule untouched.
printf 'INVALID\n' >"$CRON_FILE"
printf '0 0 * * * /bin/false\n' >"$MOCK_LIVE"
if "$repo/.local/scripts/crontab-sync" >"$tmp/out" 2>"$tmp/err"; then
	printf 'invalid tracked crontab was installed\n' >&2
	exit 1
fi
printf '0 0 * * * /bin/false\n' | cmp - "$MOCK_LIVE"

# A read failure is not the same as an account without a crontab.
rm "$MOCK_LIVE"
touch "$MOCK_READ_ERROR"
printf '* * * * * /bin/true\n' >"$CRON_FILE"
: >"$MOCK_TRACE"
if "$repo/.local/scripts/crontab-sync" >"$tmp/out" 2>"$tmp/err"; then
	printf 'crontab read failure was mistaken for an empty schedule\n' >&2
	exit 1
fi
[ "$(cat "$MOCK_TRACE")" = '-l' ]
[ ! -e "$MOCK_LIVE" ]

# A host that bars this user from cron (cron.allow, PAM) has no schedule to keep
# in step, like a host without crontab: skip with a note, install nothing.
rm "$MOCK_READ_ERROR"
touch "$MOCK_DENIED"
: >"$MOCK_TRACE"
"$repo/.local/scripts/crontab-sync" >"$tmp/out" 2>"$tmp/err" || {
	printf 'crontab-sync failed where cron is not permitted:\n' >&2
	cat "$tmp/err" >&2
	exit 1
}
grep -q 'skipped' "$tmp/err"
[ "$(cat "$MOCK_TRACE")" = '-l' ]
[ ! -e "$MOCK_LIVE" ]

printf 'crontab sync: first install, idempotence, validation, read errors and denied access pass\n'

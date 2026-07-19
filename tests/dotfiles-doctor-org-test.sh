#!/usr/bin/env bash
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

home="$tmp/home"
mkdir -p "$home"
make --no-print-directory -C "$repo" link HOME="$home" >/dev/null

run_doctor() {
	local status=0
	DOCTOR_OUTPUT=$(HOME="$home" "$repo/.local/scripts/dotfiles-doctor" "$@" 2>&1) || status=$?
	return "$status"
}

if ! run_doctor "$repo"; then
	printf 'default doctor should not require an untracked Org agenda:\n%s\n' "$DOCTOR_OUTPUT" >&2
	exit 1
fi
case "$DOCTOR_OUTPUT" in
*"warn: $home/org/agenda missing or not writable"*) ;;
*)
	printf 'default doctor did not report the missing Org agenda as a warning\n' >&2
	exit 1
	;;
esac

if run_doctor --strict "$repo"; then
	printf 'strict doctor accepted a missing Org agenda\n' >&2
	exit 1
fi
case "$DOCTOR_OUTPUT" in
*"fail: $home/org/agenda missing or not writable"*) ;;
*)
	printf 'strict doctor did not report the missing Org agenda as a failure\n' >&2
	exit 1
	;;
esac

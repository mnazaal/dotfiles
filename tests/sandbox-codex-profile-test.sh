#!/usr/bin/env bash
set -euo pipefail

repo=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
home="$tmp/home"
mkdir -p "$home/.agents" "$home/.config/codex" "$home/.local/state/codex"
touch "$home/.config/codex/config.toml"

output=$(HOME="$home" SANDBOX_PROFILE_PATH="$repo/.config/sandbox" \
	"$repo/.local/scripts/sandbox" --dry-run -p agent-codex -- /bin/true)

case "$output" in
*"$home/.config/codex:$home/.config/codex:ro"*) ;;
*) printf 'Codex home is not read-only in the profile\n' >&2; exit 1 ;;
esac
case "$output" in
*"$home/.config/codex/config.toml:$home/.config/codex/config.toml"*) ;;
*) printf 'Codex config.toml is not a writable file mount\n' >&2; exit 1 ;;
esac
case "$output" in
*"$home/.local/state/codex:$home/.local/state/codex"*) ;;
*) printf 'Codex hook state is not writable in the profile\n' >&2; exit 1 ;;
esac
case "$output" in
*"$home/.config:$home/.config:ro"*)
	printf 'profile exposes the full config directory\n' >&2
	exit 1
	;;
esac

ancestor=$(dirname "$home")
if HOME="$home" SANDBOX_PROFILE_PATH="$repo/.config/sandbox" \
	"$repo/.local/scripts/sandbox" --dry-run --ro "$ancestor" -- /bin/true \
	>"$tmp/stdout" 2>"$tmp/stderr"; then
	printf 'sandbox accepted an ancestor of HOME\n' >&2
	exit 1
fi

if ! grep -q 're-exposes all of \$HOME or /' "$tmp/stderr"; then
	printf 'sandbox rejected the ancestor for an unexpected reason\n' >&2
	exit 1
fi

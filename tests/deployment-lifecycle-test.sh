#!/usr/bin/env bash
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

home="$tmp/home"
outside="$tmp/unrelated-target"
mkdir -p "$home" "$outside"
ln -s "$outside" "$home/unrelated"

make --no-print-directory -C "$repo" link HOME="$home" >/dev/null

for path in \
	".zshenv" \
	".zprofile" \
	".zshrc" \
	".claude/hooks/guardrails.ts" \
	".agents/guardrails/core.ts" \
	".config/codex/skills/dev-scout"; do
	[ -L "$home/$path" ] || {
		printf 'make link did not create expected link: %s\n' "$path" >&2
		exit 1
	}
done

clean_output=$(make --no-print-directory -C "$repo" clean HOME="$home")
[ -z "$clean_output" ] || {
	printf 'make clean printed normal cleanup output:\n%s\n' "$clean_output" >&2
	exit 1
}

for path in \
	".zshenv" \
	".zprofile" \
	".zshrc" \
	".claude/hooks/guardrails.ts" \
	".agents/guardrails/core.ts" \
	".config/codex/skills/dev-scout"; do
	[ ! -L "$home/$path" ] || {
		printf 'make clean left repository link behind: %s\n' "$path" >&2
		exit 1
	}
done

[ -L "$home/unrelated" ] || {
	printf 'make clean removed an unrelated symlink\n' >&2
	exit 1
}

# The checkout commonly lives beneath $HOME.  Cleanup must not mistake its
# internal links for deployed links merely because they point back into it.
nested_home="$tmp/nested-home"
source="$nested_home/dotfiles"
mkdir -p "$nested_home"
cp -a "$repo" "$source"

make --no-print-directory -C "$source" link HOME="$nested_home" >/dev/null
make --no-print-directory -C "$source" clean HOME="$nested_home" >/dev/null

[ -L "$source/.claude/skills" ] || {
	printf 'make clean removed an internal source symlink\n' >&2
	exit 1
}

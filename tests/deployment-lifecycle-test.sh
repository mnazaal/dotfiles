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
	".claude/hooks/guardrails.ts" \
	".agents/guardrails/core.ts"; do
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
	".claude/hooks/guardrails.ts" \
	".agents/guardrails/core.ts"; do
	[ ! -L "$home/$path" ] || {
		printf 'make clean left repository link behind: %s\n' "$path" >&2
		exit 1
	}
done

[ -L "$home/unrelated" ] || {
	printf 'make clean removed an unrelated symlink\n' >&2
	exit 1
}

# --no-folding deploys real directories, so unstowing alone leaves them behind;
# an emptied skill directory reads as a skill with no SKILL.md to anything
# enumerating that tree.
[ ! -d "$home/.agents/skills/dev-git" ] || {
	printf 'make clean left an emptied deployed directory behind\n' >&2
	exit 1
}

# Renaming repository content strands the links deployed under the old name:
# stow no longer knows about them, so only the DEEP sweep can see them.
renamed_home="$tmp/renamed-home"
renamed_repo="$tmp/renamed-repo"
mkdir -p "$renamed_home"
cp -a "$repo" "$renamed_repo"

make --no-print-directory -C "$renamed_repo" link HOME="$renamed_home" >/dev/null
mv "$renamed_repo/.agents/skills/dev-scout" "$renamed_repo/.agents/skills/dev-scout-renamed"

make --no-print-directory -C "$renamed_repo" clean HOME="$renamed_home" >/dev/null
[ -L "$renamed_home/.agents/skills/dev-scout/SKILL.md" ] || {
	printf 'expected the stale link to survive plain clean (test premise is wrong)\n' >&2
	exit 1
}

make --no-print-directory -C "$renamed_repo" clean DEEP=1 HOME="$renamed_home" >/dev/null
[ ! -L "$renamed_home/.agents/skills/dev-scout/SKILL.md" ] || {
	printf 'make clean DEEP=1 left a stale link behind\n' >&2
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

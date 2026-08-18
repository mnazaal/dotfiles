#!/usr/bin/env bash
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

home="$tmp/home"
skills_dir="$home/.config/codex/skills"
mkdir -p "$skills_dir"

# Codex writes its own bundled skills into this directory; the linker must
# deploy alongside them, never over them.
mkdir -p "$skills_dir/.system/example"
touch "$skills_dir/.system/example/keep"

make -C "$repo" link HOME="$home" >/dev/null

for source in "$repo"/.agents/skills/*; do
	name=$(basename "$source")
	target="$skills_dir/$name"
	[ -L "$target" ] || {
		printf 'expected symlink: %s\n' "$target" >&2
		exit 1
	}
	[ "$(readlink -f "$target")" = "$source" ] || {
		printf 'unexpected target for: %s\n' "$target" >&2
		exit 1
	}
	# Codex skips a skill whose SKILL.md is itself a symlink (openai/codex#17344),
	# so the link must resolve to a directory holding a real file.
	[ -f "$target/SKILL.md" ] && [ ! -L "$target/SKILL.md" ] || {
		printf 'SKILL.md is not a real file through: %s\n' "$target" >&2
		exit 1
	}
done

[ -f "$skills_dir/.system/example/keep" ] || {
	printf 'linker disturbed Codex-owned .system skills\n' >&2
	exit 1
}

# A real directory occupying a skill's slot must keep its contents: stow folds
# into it rather than replacing it.
protected="$skills_dir/dev-scout"
rm "$protected"
mkdir "$protected"
touch "$protected/keep"

make -C "$repo" link HOME="$home" >/dev/null 2>&1 || true

[ -f "$protected/keep" ] || {
	printf 'linker deleted a real directory\n' >&2
	exit 1
}

make -C "$repo" clean HOME="$home" >/dev/null

[ -d "$protected" ] || {
	printf 'cleaner removed a real directory\n' >&2
	exit 1
}

[ -f "$skills_dir/.system/example/keep" ] || {
	printf 'cleaner removed Codex-owned .system skills\n' >&2
	exit 1
}

if find "$skills_dir" -maxdepth 1 -type l -print -quit | grep -q .; then
	printf 'cleaner left repository skill links behind\n' >&2
	exit 1
fi

#!/usr/bin/env bash
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

home="$tmp/home"
skills_dir="$home/.config/codex/skills"
mkdir -p "$skills_dir"

make -C "$repo" _link-codex-skills HOME="$home" >/dev/null

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
done

protected="$skills_dir/dev-scout"
rm "$protected"
mkdir "$protected"
touch "$protected/keep"

if make -C "$repo" _link-codex-skills HOME="$home" >/dev/null 2>&1; then
	printf 'linker replaced a real directory\n' >&2
	exit 1
fi

[ -f "$protected/keep" ] || {
	printf 'linker deleted a real directory\n' >&2
	exit 1
}

make -C "$repo" _clean-codex-skills HOME="$home" >/dev/null

[ -d "$protected" ] || {
	printf 'cleaner removed a real directory\n' >&2
	exit 1
}

if find "$skills_dir" -maxdepth 1 -type l -print -quit | grep -q .; then
	printf 'cleaner left repository skill links behind\n' >&2
	exit 1
fi

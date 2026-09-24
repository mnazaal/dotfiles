#!/usr/bin/env bash
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/bin" "$tmp/data"
cat >"$tmp/bin/git" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >>"$GIT_TRACE"
[ "$1" = clone ] || exit 1
for arg do dest=$arg; done
name=${dest##*/}
mkdir -p "$dest"
printf 'export ZPLUGIN_TEST_LOADED=1\n' >"$dest/$name.plugin.zsh"
SH
chmod +x "$tmp/bin/git"
export GIT_TRACE="$tmp/git-trace" XDG_DATA_HOME="$tmp/data" REPO="$repo"

# Sourcing shell startup on a fresh, offline machine must never fetch code.
if ! PATH="$tmp/bin:$PATH" zsh -f -c 'source "${PLUGIN_SOURCE:-$REPO/.config/zsh/plugins.zsh}"' >"$tmp/out" 2>"$tmp/err"; then
	printf 'offline zsh plugin startup failed:\n' >&2
	cat "$tmp/err" >&2
	exit 1
fi
if [ -s "$GIT_TRACE" ]; then
	printf 'zsh plugin startup ran git:\n' >&2
	cat "$GIT_TRACE" >&2
	exit 1
fi

# Already-installed plugins still load; startup must not run git for them.
plugin_dir="$tmp/data/zsh/plugins/fzf-tab"
mkdir -p "$plugin_dir"
printf 'export ZPLUGIN_TEST_LOADED=1\n' >"$plugin_dir/fzf-tab.plugin.zsh"
PATH="$tmp/bin:$PATH" zsh -f -c 'source "${PLUGIN_SOURCE:-$REPO/.config/zsh/plugins.zsh}"; [[ $ZPLUGIN_TEST_LOADED == 1 ]]'
[ ! -s "$GIT_TRACE" ]

# Fetching is possible only via the explicit install function.
PATH="$tmp/bin:$PATH" zsh -f -c 'source "${PLUGIN_SOURCE:-$REPO/.config/zsh/plugins.zsh}"; zplugin-install; [[ $ZPLUGIN_TEST_LOADED == 1 ]]' >"$tmp/out" 2>"$tmp/err" || {
	cat "$tmp/err" >&2
	exit 1
}
[ "$(wc -l <"$GIT_TRACE")" -eq 2 ]
for name in zsh-vi-mode zsh-syntax-highlighting; do
	[ -r "$tmp/data/zsh/plugins/$name/$name.plugin.zsh" ]
done
printf 'zsh plugins: offline startup, installed loading and explicit install pass\n'

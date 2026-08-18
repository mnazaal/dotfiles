#!/usr/bin/env bash
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
home="$tmp/home"
mkdir -p "$home/.agents" "$home/.config/codex" "$home/.local/state/codex"
touch "$home/.config/codex/config.toml"

# RO_LAST pins the repository copies, and the sandbox drops binds whose source
# does not exist, so the checkout has to be present under this fake HOME for
# those pins to appear at all.
mkdir -p \
	"$home/dotfiles/.config/codex/hooks" \
	"$home/dotfiles/.agents/guardrails" \
	"$home/dotfiles/.agents/skills"
touch \
	"$home/dotfiles/.config/codex/hooks.json" \
	"$home/dotfiles/.config/codex/config.toml.template"

output=$(HOME="$home" SANDBOX_PROFILE_PATH="$repo/.config/sandbox" \
	"$repo/.local/scripts/sandbox" --dry-run -p agent-codex -- /bin/true)

# Codex writes its state DB (state_5.sqlite and the sqlite -wal/-shm files it
# creates beside it) directly into CODEX_HOME, so that directory is writable.
# The machinery inside it is protected at its repository source by RO_LAST
# instead — asserted below.
case "$output" in
*"$home/.config/codex:$home/.config/codex:ro"*)
	printf 'Codex home is read-only; Codex cannot create its state DB\n' >&2
	exit 1
	;;
esac
case "$output" in
*"$home/.config/codex:$home/.config/codex"*) ;;
*)
	printf 'Codex home is not mounted writable in the profile\n' >&2
	exit 1
	;;
esac

# Machinery must stay immutable even though CODEX_HOME is writable: every path
# below is reached through a stow symlink into the repository, so the pin has
# to land on the repository target, not on the deployed link.
for machinery in \
	"$home/dotfiles/.config/codex/hooks" \
	"$home/dotfiles/.config/codex/hooks.json" \
	"$home/dotfiles/.config/codex/config.toml.template" \
	"$home/dotfiles/.agents/guardrails"; do
	case "$output" in
	*"$machinery:$machinery:ro"*) ;;
	*)
		printf 'machinery is not pinned read-only: %s\n' "$machinery" >&2
		exit 1
		;;
	esac
done

# Skills are deliberately NOT machinery-pinned (unpinned 2026-08-18, reversing
# 4de2847): the user chose skill iteration speed over the self-modification
# pin; review happens at commit time instead. Assert the unpin holds so a
# future profile edit cannot silently re-pin them.
case "$output" in
*"$home/dotfiles/.agents/skills:$home/dotfiles/.agents/skills:ro"*)
	printf 'skills are pinned read-only; sessions must be able to edit them\n' >&2
	exit 1
	;;
esac
case "$output" in
*"$home/.config/codex/config.toml:$home/.config/codex/config.toml"*) ;;
*)
	printf 'Codex config.toml is not a writable file mount\n' >&2
	exit 1
	;;
esac
case "$output" in
*"$home/.local/state/codex:$home/.local/state/codex"*) ;;
*)
	printf 'Codex hook state is not writable in the profile\n' >&2
	exit 1
	;;
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

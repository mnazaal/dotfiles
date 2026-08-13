#!/usr/bin/env bash
# The agent profile confines writes to the project you launched in: ~/projects
# and ~/dotfiles are readable but not writable, and only the auto-bound cwd is
# read-write.
# shellcheck disable=SC2088  # error messages name paths as ~/... prose, not for expansion
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
home="$tmp/home"
mkdir -p \
	"$home/.agents" "$home/.config" "$home/.cache" \
	"$home/.local/share" "$home/.local/state/nvim" "$home/.local/state/headroom" \
	"$home/org/roam" "$home/org/agenda" "$home/org/agents" \
	"$home/dotfiles" "$home/projects/demo"

run() { # cwd [extra sandbox args...] -> dry-run argv
	local cwd=$1
	shift
	(
		cd "$cwd" || exit 1
		HOME="$home" SANDBOX_BACKEND=podman SANDBOX_PROFILE_PATH="$repo/.config/sandbox" \
			"$repo/.local/scripts/sandbox" --dry-run -p agent "$@" -- /bin/true
	)
}

output=$(run "$home/projects/demo")

# Each bind is one shell-quoted argv token, so a writable bind is
# ' src:dst ' and a read-only one is ' src:dst:ro '.
case "$output" in
*" $home/projects:$home/projects:ro "*) ;;
*)
	printf '~/projects is not bound read-only\n' >&2
	exit 1
	;;
esac
case "$output" in
*" $home/projects:$home/projects "*)
	printf '~/projects is still writable — an agent could write a sibling project\n' >&2
	exit 1
	;;
esac
case "$output" in
*" $home/dotfiles:$home/dotfiles:ro "*) ;;
*)
	printf '~/dotfiles is not bound read-only\n' >&2
	exit 1
	;;
esac
case "$output" in
*" $home/projects/demo:$home/projects/demo "*) ;;
*)
	printf 'the launch directory is not writable\n' >&2
	exit 1
	;;
esac
case "$output" in
*" $home/org/agents:$home/org/agents "*) ;;
*)
	printf 'the shared agent wiki is no longer writable\n' >&2
	exit 1
	;;
esac

# Launching from ~/dotfiles itself must still get a writable checkout: the cwd
# auto-bind is deduped into RW before the profile's read-only entry is seen.
output=$(run "$home/dotfiles")
case "$output" in
*" $home/dotfiles:$home/dotfiles "*) ;;
*)
	printf 'launching from ~/dotfiles did not make it writable\n' >&2
	exit 1
	;;
esac

# A bare subdirectory launch leaves the rest of the repo — crucially .git —
# under the read-only ~/projects bind. That is why renv passes --rw <toplevel>.
# Assert both halves: the hazard is real, and --rw is what resolves it.
mkdir -p "$home/projects/demo/src"
output=$(run "$home/projects/demo/src")
case "$output" in
*" $home/projects/demo:$home/projects/demo "*)
	printf 'a bare subdirectory launch unexpectedly made the whole repo writable\n' >&2
	exit 1
	;;
esac

output=$(run "$home/projects/demo/src" --rw "$home/projects/demo")
case "$output" in
*" $home/projects/demo:$home/projects/demo "*) ;;
*)
	printf -- '--rw <toplevel> did not make the repository writable\n' >&2
	exit 1
	;;
esac

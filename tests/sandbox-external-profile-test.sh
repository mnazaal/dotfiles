#!/usr/bin/env bash
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

home="$tmp/home"
project="$tmp/project"
mkdir -p \
	"$home/.agents" \
	"$home/.config/opencode" \
	"$home/.config/pi" \
	"$home/.cache/opencode" \
	"$home/.local/share/opencode" \
	"$home/.local/state/opencode" \
	"$home/.local/share/pi" \
	"$home/.local/state/pi" \
	"$home/dotfiles/.agents/guardrails" \
	"$project"

assert_profile() { # profile required mounts... -- forbidden mount fragments...
	local profile=$1
	shift
	local required=() forbidden=() value seen_separator=0
	for value in "$@"; do
		if [ "$value" = -- ]; then
			seen_separator=1
			continue
		fi
		if [ "$seen_separator" -eq 0 ]; then required+=("$value"); else forbidden+=("$value"); fi
	done

	local output
	output=$(cd "$project" && HOME="$home" SANDBOX_PROFILE_PATH="$repo/.config/sandbox" \
		"$repo/.local/scripts/sandbox" --dry-run -p "$profile" -- /bin/true)
	for value in "${required[@]}"; do
		case "$output" in *"$value"*) ;; *)
			printf '%s profile missing mount: %s\n' "$profile" "$value" >&2
			exit 1
			;;
		esac
	done
	for value in "${forbidden[@]}"; do
		case "$output" in *"$value"*)
			printf '%s profile exposes forbidden mount: %s\n' "$profile" "$value" >&2
			exit 1
			;;
		esac
	done
}

# A forbidden entry is matched as a substring, so "DIR:DIR" also matches the
# read-only mount "DIR:DIR:ro". Forbidding the read-write form therefore needs
# the trailing space that separates it from the next argument.
assert_profile agent-opencode \
	"$home/.agents:$home/.agents:ro" \
	"$home/dotfiles:$home/dotfiles:ro" \
	"$home/.config/opencode:$home/.config/opencode:ro" \
	"$home/.local/share/opencode:$home/.local/share/opencode" \
	"$home/.local/state/opencode:$home/.local/state/opencode" \
	"$home/.cache/opencode:$home/.cache/opencode" \
	-- \
	"$home/.config:$home/.config:ro" \
	"$home/dotfiles:$home/dotfiles " \
	"$home/projects:$home/projects"

assert_profile agent-pi \
	"$home/.agents:$home/.agents:ro" \
	"$home/dotfiles:$home/dotfiles:ro" \
	"$home/.config/pi:$home/.config/pi:ro" \
	"$home/.local/share/pi:$home/.local/share/pi" \
	"$home/.local/state/pi:$home/.local/state/pi" \
	-- \
	"$home/.config:$home/.config:ro" \
	"$home/dotfiles:$home/dotfiles " \
	"$home/projects:$home/projects"

assert_mount_order() { # cwd profile earlier-mount later-mount
	local dir=$1 profile=$2 earlier=$3 later=$4 output rest
	output=$(cd "$dir" && HOME="$home" SANDBOX_PROFILE_PATH="$repo/.config/sandbox" \
		"$repo/.local/scripts/sandbox" --dry-run -p "$profile" -- /bin/true)
	case "$output" in *"$earlier"*) ;; *)
		printf '%s profile missing mount: %s\n' "$profile" "$earlier" >&2
		exit 1
		;;
	esac
	rest=${output#*"$earlier"}
	case "$rest" in *"$later"*) ;; *)
		printf '%s profile binds %s before %s; the writable bind would win\n' \
			"$profile" "$later" "$earlier" >&2
		exit 1
		;;
	esac
}

# The guardrail source must be read-only AND bound after the writable dotfiles
# bind that contains it. $HOME/.agents is stow symlinks into $HOME/dotfiles, so
# the read-only bind there does not protect the targets.
assert_mount_order "$project" agent-claude \
	"$home/dotfiles:$home/dotfiles" \
	"$home/dotfiles/.agents/guardrails:$home/dotfiles/.agents/guardrails:ro"

# Launching with cwd inside ~/dotfiles auto-binds the repo read-write; the
# machinery-ro fragment must still pin the guardrail sources read-only
# afterwards — for EVERY harness profile, not just the ones composing `agent`.
for profile in agent-claude agent-codex agent-goose agent-opencode agent-pi; do
	assert_mount_order "$home/dotfiles" "$profile" \
		"$home/dotfiles:$home/dotfiles" \
		"$home/dotfiles/.agents/guardrails:$home/dotfiles/.agents/guardrails:ro"
done

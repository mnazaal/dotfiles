#!/usr/bin/env bash
set -euo pipefail

repo=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
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
			;; esac
	done
	for value in "${forbidden[@]}"; do
		case "$output" in *"$value"*)
			printf '%s profile exposes forbidden mount: %s\n' "$profile" "$value" >&2
			exit 1
			;; esac
	done
}

assert_profile agent-opencode \
	"$home/.agents:$home/.agents:ro" \
	"$home/.config/opencode:$home/.config/opencode:ro" \
	"$home/.local/share/opencode:$home/.local/share/opencode" \
	"$home/.local/state/opencode:$home/.local/state/opencode" \
	"$home/.cache/opencode:$home/.cache/opencode" \
	-- \
	"$home/.config:$home/.config:ro" \
	"$home/dotfiles:$home/dotfiles" \
	"$home/projects:$home/projects"

assert_profile agent-pi \
	"$home/.agents:$home/.agents:ro" \
	"$home/.config/pi:$home/.config/pi:ro" \
	"$home/.local/share/pi:$home/.local/share/pi" \
	"$home/.local/state/pi:$home/.local/state/pi" \
	-- \
	"$home/.config:$home/.config:ro" \
	"$home/dotfiles:$home/dotfiles" \
	"$home/projects:$home/projects"

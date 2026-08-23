#!/usr/bin/env bash
# Sandbox profile mount policy: what each harness profile may write, what stays
# read-only, and that the machinery pins are emitted after the writable binds.
# Asserts the mount strings of `sandbox --dry-run`; environment forwarding is
# covered separately by tests/sandbox-env-test.sh.
# shellcheck disable=SC2088  # messages name paths as ~/... prose, not for expansion
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
home="$tmp/home"
project="$tmp/project"

# Union fixture for every profile below. The sandbox silently drops a bind whose
# source does not exist at launch, so every path an assertion names — required OR
# forbidden — must be created here, or that assertion can never fire.
mkdir -p \
	"$home/.agents" "$home/.cache/opencode" \
	"$home/.config/codex" "$home/.config/opencode" "$home/.config/pi" \
	"$home/.config/pi/agent/sessions" "$home/.config/pi/agent/npm" \
	"$home/.local/share/opencode" \
	"$home/.local/state/codex" "$home/.local/state/headroom" \
	"$home/.local/state/nvim" "$home/.local/state/opencode" \
	"$home/org/roam" "$home/org/agenda" "$home/org/agents" \
	"$home/dotfiles/.agents/guardrails" "$home/dotfiles/.agents/skills" \
	"$home/dotfiles/.config/codex/hooks" \
	"$home/projects/demo/src" "$project"
touch "$home/.config/codex/config.toml" \
	"$home/.config/pi/agent/mcp-cache.json" \
	"$home/.config/pi/agent/run-history.jsonl" \
	"$home/dotfiles/.config/codex/hooks.json" \
	"$home/dotfiles/.config/codex/config.toml.template"

run() { # cwd [sandbox args...] -> dry-run argv
	local cwd=$1
	shift
	(
		cd "$cwd" || exit 1
		HOME="$home" SANDBOX_BACKEND=podman SANDBOX_PROFILE_PATH="$repo/.config/sandbox" \
			"$repo/.local/scripts/sandbox" --dry-run "$@" -- /bin/true
	)
}

# Each bind is one shell-quoted argv token, so a writable bind is ' src:dst ' and
# a read-only one is ' src:dst:ro '. A forbidden entry is matched as a substring,
# so "DIR:DIR" also matches the read-only mount "DIR:DIR:ro": forbidding the
# read-write form needs the trailing space that separates argv tokens.
assert_mounts() { # label output required mounts... -- forbidden mount fragments...
	local label=$1 output=$2
	shift 2
	local required=() forbidden=() value seen_separator=0
	for value in "$@"; do
		if [ "$value" = -- ]; then
			seen_separator=1
			continue
		fi
		if [ "$seen_separator" -eq 0 ]; then required+=("$value"); else forbidden+=("$value"); fi
	done
	for value in "${required[@]}"; do
		case "$output" in *"$value"*) ;; *)
			printf '%s: missing mount: %s\n' "$label" "$value" >&2
			exit 1
			;;
		esac
	done
	for value in "${forbidden[@]}"; do
		case "$output" in *"$value"*)
			printf '%s: exposes forbidden mount: %s\n' "$label" "$value" >&2
			exit 1
			;;
		esac
	done
}

assert_mount_order() { # cwd profile earlier-mount later-mount
	local dir=$1 profile=$2 earlier=$3 later=$4 output rest
	output=$(run "$dir" -p "$profile")
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

# The agent profile confines writes to the project you launched in: ~/projects
# and ~/dotfiles are readable but not writable (a writable ~/projects would let
# an agent write a sibling project), only the auto-bound cwd is read-write, and
# the shared agent wiki stays writable.
output=$(run "$home/projects/demo" -p agent)
assert_mounts 'agent in ~/projects/demo' "$output" \
	" $home/projects:$home/projects:ro " \
	" $home/dotfiles:$home/dotfiles:ro " \
	" $home/projects/demo:$home/projects/demo " \
	" $home/org/agents:$home/org/agents " \
	-- \
	" $home/projects:$home/projects "

# Launching from ~/dotfiles itself must still get a writable checkout: the cwd
# auto-bind is deduped into RW before the profile's read-only entry is seen.
output=$(run "$home/dotfiles" -p agent)
assert_mounts 'agent in ~/dotfiles' "$output" " $home/dotfiles:$home/dotfiles "

# A bare subdirectory launch leaves the rest of the repo — crucially .git —
# under the read-only ~/projects bind. That is why renv passes --rw <toplevel>.
# Assert both halves: the hazard is real, and --rw is what resolves it.
output=$(run "$home/projects/demo/src" -p agent)
assert_mounts 'agent in a bare subdirectory' "$output" \
	-- " $home/projects/demo:$home/projects/demo "
output=$(run "$home/projects/demo/src" -p agent --rw "$home/projects/demo")
assert_mounts 'agent with --rw <toplevel>' "$output" \
	" $home/projects/demo:$home/projects/demo "

# Codex writes its state DB (state_5.sqlite and the sqlite -wal/-shm files it
# creates beside it) straight into CODEX_HOME, so that directory is writable; the
# machinery inside it is pinned at its repository source instead, since every
# pinned path is reached through a stow symlink into the repository. Skills are
# deliberately NOT pinned (unpinned 2026-08-18, reversing 4de2847): the user
# chose skill iteration speed over the self-modification pin, and review happens
# at commit time. Assert the unpin holds so a future edit cannot silently re-pin.
output=$(run "$project" -p agent-codex)
assert_mounts agent-codex "$output" \
	"$home/.config/codex:$home/.config/codex" \
	"$home/.config/codex/config.toml:$home/.config/codex/config.toml" \
	"$home/.local/state/codex:$home/.local/state/codex" \
	"$home/dotfiles/.config/codex/hooks:$home/dotfiles/.config/codex/hooks:ro" \
	"$home/dotfiles/.config/codex/hooks.json:$home/dotfiles/.config/codex/hooks.json:ro" \
	"$home/dotfiles/.config/codex/config.toml.template:$home/dotfiles/.config/codex/config.toml.template:ro" \
	"$home/dotfiles/.agents/guardrails:$home/dotfiles/.agents/guardrails:ro" \
	-- \
	"$home/.config/codex:$home/.config/codex:ro" \
	"$home/dotfiles/.agents/skills:$home/dotfiles/.agents/skills:ro" \
	"$home/.config:$home/.config:ro"

output=$(run "$project" -p agent-opencode)
assert_mounts agent-opencode "$output" \
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

output=$(run "$project" -p agent-pi)
assert_mounts agent-pi "$output" \
	"$home/.agents:$home/.agents:ro" \
	"$home/dotfiles:$home/dotfiles:ro" \
	"$home/.config/pi:$home/.config/pi:ro" \
	"$home/.config/pi/agent/sessions:$home/.config/pi/agent/sessions" \
	"$home/.config/pi/agent/npm:$home/.config/pi/agent/npm" \
	"$home/.config/pi/agent/mcp-cache.json:$home/.config/pi/agent/mcp-cache.json" \
	"$home/.config/pi/agent/run-history.jsonl:$home/.config/pi/agent/run-history.jsonl" \
	-- \
	"$home/.config:$home/.config:ro" \
	"$home/dotfiles:$home/dotfiles " \
	"$home/projects:$home/projects"

# The guardrail source must be read-only AND bound after the writable dotfiles
# bind that contains it: $HOME/.agents is stow symlinks into $HOME/dotfiles, so
# the read-only bind there does not protect the targets. Launching with cwd
# inside ~/dotfiles auto-binds the repo read-write, which is the harder case —
# the machinery-ro fragment must still pin the sources read-only afterwards, for
# EVERY harness profile, not just the ones composing `agent`.
for profile in agent-claude agent-codex agent-goose agent-opencode agent-pi; do
	assert_mount_order "$home/dotfiles" "$profile" \
		"$home/dotfiles:$home/dotfiles" \
		"$home/dotfiles/.agents/guardrails:$home/dotfiles/.agents/guardrails:ro"
done

# A bind re-exposing an ancestor of $HOME defeats the allowlist as completely as
# binding $HOME itself, so the sandbox must refuse it.
ancestor=$(dirname "$home")
if run "$project" --ro "$ancestor" >"$tmp/stdout" 2>"$tmp/stderr"; then
	printf 'sandbox accepted an ancestor of HOME\n' >&2
	exit 1
fi
if ! grep -q 're-exposes all of \$HOME or /' "$tmp/stderr"; then
	printf 'sandbox rejected the ancestor for an unexpected reason\n' >&2
	exit 1
fi

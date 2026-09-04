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
	"$home/.agents" "$home/.config/pi" \
	"$home/.config/pi/agent/sessions" "$home/.config/pi/agent/npm" \
	"$home/.local/share/gnupg" "$home/.local/share/pass" \
	"$home/.local/share/password-store" "$home/.local/share/keyrings" \
	"$home/.local/share/mail" "$home/.local/share/zsh" \
	"$home/.local/state/headroom" "$home/.local/state/nvim" \
	"$home/org/roam" "$home/org/agenda" "$home/org/agents" \
	"$home/dotfiles/.agents/guardrails" "$home/dotfiles/.agents/skills" \
	"$home/projects/demo/src" "$project"
touch "$home/.config/pi/agent/mcp-cache.json" \
	"$home/.config/pi/agent/run-history.jsonl"

run() { # cwd [sandbox args...] -> dry-run argv
	local cwd=$1
	shift
	(
		cd "$cwd" || exit 1
		HOME="$home" SANDBOX_PROFILE_PATH="$repo/.config/sandbox" \
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

# An agent that rewrites a config file atomically — temp file beside it, then
# rename over the target — must not have that file bound individually: a file
# bind makes the target its own mount point, the rename fails with EXDEV against
# the parent's mount, and the agent reports a persistence error on every config
# write. Bind the containing directory instead, and pin any machinery inside it
# at its repository source, since every pinned path is reached through a stow
# symlink into the repository.
#
# ~/.agents is stow symlinks into ~/dotfiles/.agents, so binding only the former
# leaves AGENTS.md and every skill dangling whenever cwd is not ~/dotfiles — the
# cwd auto-bind was the sole reason the targets ever resolved. Skills stay
# writable in the case that matters (cwd ~/dotfiles, where the read-write cwd
# bind wins over this read-only one), and are merely readable elsewhere, where
# they were previously invisible. They are still deliberately NOT pinned
# (unpinned 2026-08-18, reversing 4de2847): the user chose skill iteration speed
# over the self-modification pin, and review happens at commit time. Assert the
# unpin holds so a future edit cannot silently re-pin.
# pi composes the shared `agent` base, so it reaches what claude reaches: the
# read-only breadth below arrives from that base, not from this profile. Only
# the writable paths are pi's own, and each must survive the enclosing
# read-only ~/.config bind by being emitted after it.
output=$(run "$project" -p agent-pi)
assert_mounts agent-pi "$output" \
	"$home/.agents:$home/.agents:ro" \
	"$home/dotfiles:$home/dotfiles:ro" \
	"$home/.config:$home/.config:ro" \
	"$home/projects:$home/projects:ro" \
	"$home/.config/pi/agent/sessions:$home/.config/pi/agent/sessions" \
	"$home/.config/pi/agent/npm:$home/.config/pi/agent/npm" \
	"$home/.config/pi/agent/mcp-cache.json:$home/.config/pi/agent/mcp-cache.json" \
	"$home/.config/pi/agent/run-history.jsonl:$home/.config/pi/agent/run-history.jsonl" \
	-- \
	"$home/dotfiles:$home/dotfiles "

# The guardrail source must be read-only AND bound after the writable dotfiles
# bind that contains it: $HOME/.agents is stow symlinks into $HOME/dotfiles, so
# the read-only bind there does not protect the targets. Launching with cwd
# inside ~/dotfiles auto-binds the repo read-write, which is the harder case —
# the machinery-ro fragment must still pin the sources read-only afterwards, for
# EVERY harness profile, not just the ones composing `agent`.
for profile in agent-claude agent-pi; do
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

# Emitting a read-only bind is a REQUEST; the kernel's answer is only visible in
# the mount namespace. A file bind is orphaned when its inode is replaced (git
# checkout, stow, any temp-then-rename write), which silently disarms the pin
# while both the profile and this argv still look correct — so comparing those
# two (make check-machinery-ro-sync) cannot detect it. The launcher therefore
# asserts each pin inside the container before the command runs.
out=$(run "$home/dotfiles" -p agent-claude)
case "$out" in
*sandbox-preflight*) ;;
*)
	printf 'sandbox no longer runs the pin preflight before the command\n' >&2
	exit 1
	;;
esac

# The preflight is a shell snippet passed to `sh -c`, so exercise it directly
# with the real one extracted from the launcher — a copy here would drift.
preflight=$(awk "/^\tlocal preflight='/{f=1; sub(/^\tlocal preflight='/,\"\")} f{print} /^exec \"\\\$@\"'\$/{exit}" \
	"$repo/.local/scripts/sandbox" | sed "s/'$//")
[ -n "$preflight" ] || {
	printf 'could not extract the preflight snippet from the launcher\n' >&2
	exit 1
}

ro_pin="$tmp/readonly-pin"
rw_pin="$tmp/writable-pin"
: >"$ro_pin"
: >"$rw_pin"
chmod a-w "$ro_pin"

expect_preflight() { # label expected_exit expected_stdout args...
	local label=$1 want=$2 wantout=$3
	shift 3
	local got rc
	got=$(/bin/sh -c "$preflight" sandbox-preflight "$@" 2>/dev/null) && rc=0 || rc=$?
	if [ "$rc" -ne "$want" ] || [ "$got" != "$wantout" ]; then
		printf 'preflight %s: exit %s (want %s), stdout %s (want %s)\n' \
			"$label" "$rc" "$want" "$got" "$wantout" >&2
		exit 1
	fi
}

# Arguments are: declared-count surviving-count pins... command...
expect_preflight 'runs the command when every pin holds' 0 ran 1 1 "$ro_pin" /bin/echo ran
expect_preflight 'refuses when any pin is writable' 78 '' 2 2 "$ro_pin" "$rw_pin" /bin/echo ran
expect_preflight 'refuses on the first writable pin' 78 '' 1 1 "$rw_pin" /bin/echo ran
expect_preflight 'passes command arguments through' 0 'a b' 1 1 "$ro_pin" /bin/echo a b
expect_preflight 'runs when no pin is declared' 0 ran 0 0 /bin/echo ran

# A pin that vanished must not shrink the denominator into a silent pass: the
# command still runs (a declared-but-absent path cannot be enforced, and
# refusing would brick the launcher when an optional tool is uninstalled) but
# the count mismatch has to be reported.
expect_preflight 'reports a missing pin and continues' 0 ran 2 1 "$ro_pin" /bin/echo ran
missing_report=$(/bin/sh -c "$preflight" sandbox-preflight 2 1 "$ro_pin" /bin/echo ran 2>&1 >/dev/null)
case "$missing_report" in
*"1 of 2 machinery pins are missing"*) ;;
*)
	printf 'the preflight did not report the missing pin: %s\n' "$missing_report" >&2
	exit 1
	;;
esac

chmod u+w "$ro_pin"

# Host credential/mail stores are masked with an empty tmpfs so they are ABSENT,
# not merely unwritable. The masks live in machinery-ro, which EVERY agent-*
# profile composes, so assert all four rather than just the one profile whose
# blanket ~/.local/share bind exposes them today — a harness that later grows a
# broad bind must inherit the protection without a second edit.
# The option separators arrive backslash-escaped: --dry-run prints every argv
# token through printf %q. Assert notmpcopyup, not merely the path: podman defaults
# tmpcopyup ON, which copies the shadowed store into the tmpfs and turns the
# mask into a RAM replica that also stalls container creation past podman's
# 240s timeout. A path-only assertion passes in exactly that broken state.
for profile in agent-claude agent-pi; do
	output=$(run "$project" -p "$profile")
	assert_mounts "$profile masks credential and mail stores" "$output" \
		"--tmpfs $home/.local/share/gnupg:ro\,nosuid\,nodev\,mode=0000\,notmpcopyup" \
		"--tmpfs $home/.local/share/pass:ro\,nosuid\,nodev\,mode=0000\,notmpcopyup" \
		"--tmpfs $home/.local/share/password-store:ro\,nosuid\,nodev\,mode=0000\,notmpcopyup" \
		"--tmpfs $home/.local/share/keyrings:ro\,nosuid\,nodev\,mode=0000\,notmpcopyup" \
		"--tmpfs $home/.local/share/mail:ro\,nosuid\,nodev\,mode=0000\,notmpcopyup" \
		"--tmpfs $home/.local/share/zsh:ro\,nosuid\,nodev\,mode=0000\,notmpcopyup"
done

# The masks must shadow a bind that is still there: if the blanket read-write
# bind were narrowed away instead, these assertions would pass for the wrong
# reason and stop testing the mask at all.
output=$(run "$project" -p agent-claude)
assert_mounts 'agent-claude still binds ~/.local/share read-write' "$output" \
	"$home/.local/share:$home/.local/share "
printf 'sandbox profiles: credential and mail masks pass\n'

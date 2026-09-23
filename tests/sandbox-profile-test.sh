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
	"$home/.local/share/claude" "$home/.local/share/bun/bin" \
	"$home/.local/share/gnupg" "$home/.local/share/pass" \
	"$home/.local/share/password-store" "$home/.local/share/keyrings" \
	"$home/.local/share/mail" "$home/.local/share/zsh" \
	"$home/.local/state/headroom" "$home/.local/state/nvim" \
	"$home/org/roam" "$home/org/agenda" "$home/org/agents" \
	"$home/dotfiles/.agents/guardrails" "$home/dotfiles/.agents/skills" \
	"$home/projects/demo/src" "$project"
touch "$home/.config/pi/agent/mcp-cache.json" \
	"$home/.config/pi/agent/run-history.jsonl"

# ~/dotfiles and the demo project are REPOSITORIES; ~/projects is the container
# holding them. The auto-bind rule keys on exactly that difference, so a fixture
# of plain directories would exercise the wrong branch of it.
for r in "$home/dotfiles" "$home/projects/demo"; do
	git -c init.defaultBranch=main init -q "$r"
done

# A linked worktree of the demo repo, for the common-dir assertion below. It
# needs a commit to attach to, and the shared git hooks must stay out of the
# fixture's way.
linked="$home/projects/demo-wt"
(
	cd "$home/projects/demo" || exit 1
	git config core.hooksPath "$tmp/nohooks"
	git config user.email t@example.invalid
	git config user.name fixture
	mkdir -p "$tmp/nohooks"
	git commit -q --allow-empty -m init
	git worktree add -q --detach "$linked" HEAD
) >/dev/null 2>&1 || {
	printf 'sandbox profiles: could not build the linked-worktree fixture\n' >&2
	exit 1
}

run() { # cwd [sandbox args...] -> dry-run argv
	local cwd=$1
	shift
	(
		cd "$cwd" || exit 1
		HOME="$home" SANDBOX_PROFILE_PATH="$repo/.config/sandbox" \
			"$repo/.local/scripts/sandbox" --dry-run "$@" -- /bin/true
	)
}

# bwrap names a bind as two argv tokens after its flag, so the read-write form is
# '--bind SRC DST' and the read-only one '--ro-bind SRC DST'. Forbidding the
# writable form is unambiguous: '--ro-bind X X' does not contain '--bind X X'.
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

# A PATH directory is protected when it, OR ANY ANCESTOR, is bound read-only
# AFTER the writable bind -- that is the property; pinning the leaf is only one
# way to satisfy it. Asserting the leaf literally is wrong twice over: a pin
# whose path crosses a symlink cannot be emitted at all (bwrap mkdirs the
# mountpoint first), and the fixture below materialises every entry as a real
# directory, so the literal form passes on a shape the host does not have.
# Found 2026-09-09: $H/.local/share/fnm/aliases/default/bin is a symlinked path;
# pinning it passed this suite and aborted every real launch.
assert_path_entry_pinned() { # cwd profile writable-bind entry
	local dir=$1 profile=$2 earlier=$3 entry=$4 output rest cand tried=""
	output=$(run "$dir" -p "$profile")
	case "$output" in *"$earlier"*) ;; *)
		printf '%s profile missing mount: %s\n' "$profile" "$earlier" >&2
		exit 1
		;;
	esac
	rest=${output#*"$earlier"}
	cand=$entry
	while [ -n "$cand" ] && [ "$cand" != "/" ]; do
		tried="$tried $cand"
		case "$rest" in *"--ro-bind $cand $cand"*) return 0 ;; esac
		cand=${cand%/*}
	done
	printf '%s profile leaves %s writable: no read-only pin after the writable bind on it or any ancestor (tried:%s)\n' \
		"$profile" "$entry" "$tried" >&2
	exit 1
}

assert_mount_order() { # cwd profile earlier-mount later-mount
	local dir=$1 profile=$2 earlier=$3 later=$4 output rest
	output=$(run "$dir" -p "$profile")
	case "$output" in *"$earlier"*) ;; *)
		printf '%s profile missing mount: %s\n' "$profile" "$earlier" >&2
		exit 1
		;;
	esac
	# An absent pin and an early pin both leave the path unprotected, but they
	# are different faults with different repairs: the sandbox drops a bind whose
	# source does not exist, and without this case that reads as a mis-ordering.
	case "$output" in *"$later"*) ;; *)
		printf '%s profile never binds %s (pin removed, or its source is missing)\n' \
			"$profile" "$later" >&2
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
	"--ro-bind $home/projects $home/projects" \
	"--ro-bind $home/dotfiles $home/dotfiles" \
	"--bind $home/projects/demo $home/projects/demo" \
	"--bind $home/org/agents $home/org/agents" \
	-- \
	"--bind $home/projects $home/projects"

# Launching from ~/dotfiles itself must still get a writable checkout, even
# though the profile binds it read-only: it is a repository, so it is the unit
# of work rather than a container of them.
output=$(run "$home/dotfiles" -p agent)
assert_mounts 'agent in ~/dotfiles' "$output" "--bind $home/dotfiles $home/dotfiles"

# From a SUBDIRECTORY the writable unit is still the repository: binding only
# $PWD leaves .git under the read-only ~/projects bind, so an agent edits files
# it can never commit.
output=$(run "$home/projects/demo/src" -p agent)
assert_mounts 'a subdirectory launch binds the repository root' "$output" \
	"--bind $home/projects/demo $home/projects/demo"

# A LINKED WORKTREE needs the main repository's git directory bound read-write
# too, or nothing commits: its own .git is a file pointing at
# <main>/.git/worktrees/<name>, and the objects and refs a commit writes live
# under the main repo. Binding only the worktree gives an agent files it can
# edit and never commit -- allow-all with no recovery, since the checkpoint
# writes refs there as well. The launcher resolves --git-common-dir for exactly
# this; without an assertion the resolution was free to rot.
output=$(run "$linked" -p agent)
assert_mounts 'a linked worktree binds its own directory' "$output" \
	"--bind $linked $linked"
# Only the common GIT DIR, not the main worktree: committing needs the objects
# and refs, and binding the whole main checkout would hand over a second working
# tree nobody asked for.
assert_mounts 'a linked worktree binds the main git dir, not the main worktree' \
	"$output" "--bind $home/projects/demo/.git $home/projects/demo/.git" \
	-- "--bind $home/projects/demo $home/projects/demo "

# ...and from the directory that CONTAINS repositories, nothing is auto-bound.
# The read-write bind is emitted after the profile's read-only one and would
# win, so `cd ~/projects` would otherwise hand over every sibling project at
# once. Measured 2026-09-07 with a real launch: the write reached the host.
output=$(run "$home/projects" -p agent)
assert_mounts 'the projects container stays read-only' "$output" \
	"--ro-bind $home/projects $home/projects" \
	-- \
	"--bind $home/projects $home/projects"

# ~/.agents is stow symlinks into ~/dotfiles/.agents, so binding only the former
# leaves AGENTS.md and every skill dangling whenever cwd is not ~/dotfiles — the
# cwd auto-bind was the sole reason the targets ever resolved. Skills stay
# writable in the case that matters (cwd ~/dotfiles, where the read-write cwd
# bind wins over this read-only one), and are merely readable elsewhere. They
# remain deliberately unpinned: the user chose skill iteration speed over a
# self-modification pin, and review happens at commit time.

# The guardrail source must be read-only AND bound after the writable dotfiles
# bind that contains it: $HOME/.agents is stow symlinks into $HOME/dotfiles, so
# the read-only bind there does not protect the targets. Launching with cwd
# inside ~/dotfiles auto-binds the repo read-write, which is the harder case —
# the shared agent profile must still pin the sources read-only afterwards.
assert_mount_order "$home/dotfiles" agent \
	"--bind $home/dotfiles $home/dotfiles" \
	"--ro-bind $home/dotfiles/.agents/guardrails $home/dotfiles/.agents/guardrails"

# A harness binary sits under agent.profile's blanket read-write ~/.local/share,
# so a plain read-only bind for it is emitted BEFORE that parent and shadowed by
# it — protection that reads real and is not. The pin has to land after. Both
# harness binaries stay pinned because Pi Bash could otherwise rewrite either
# executable and persist outside the sandbox.
assert_mount_order "$project" agent \
	"--bind $home/.local/share $home/.local/share" \
	"--ro-bind $home/.local/share/claude $home/.local/share/claude"
assert_mount_order "$project" agent \
	"--bind $home/.local/share $home/.local/share" \
	"--ro-bind $home/.local/share/bun/bin $home/.local/share/bun/bin"

# A bind re-exposing an ancestor of $HOME defeats the allowlist as completely as
# binding $HOME itself, so the sandbox must refuse it. A PROFILE is the only
# thing that can ask for one now that the bind flags are gone, which is also the
# realistic source: profiles are hand-written, and this guard is what stops one
# typo from dissolving the boundary.
ancestor=$(dirname "$home")
badprof="$home/.config/sandbox"
mkdir -p "$badprof"
printf 'RO+=( "%s" )\n' "$ancestor" >"$badprof/badbind.profile"
if (
	cd "$project" || exit 1
	HOME="$home" SANDBOX_PROFILE_PATH="$badprof" \
		"$repo/.local/scripts/sandbox" --dry-run -p badbind -- /bin/true
) >"$tmp/stdout" 2>"$tmp/stderr"; then
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
out=$(run "$home/dotfiles" -p agent)
case "$out" in
*sandbox-preflight*) ;;
*)
	printf 'sandbox no longer runs the pin preflight before the command\n' >&2
	exit 1
	;;
esac

# The preflight is a shell snippet passed to `sh -c`, so exercise it directly
# with the real one extracted from the launcher — a copy here would drift.
preflight=$(awk "/^PREFLIGHT='/{f=1; sub(/^PREFLIGHT='/,\"\")} f{print} /^exec \"\\\$@\"'\$/{exit}" \
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

# The masks must shadow a bind that is still there: if the blanket read-write
# bind were narrowed away instead, these assertions would pass for the wrong
# reason and stop testing the mask at all.
output=$(run "$project" -p agent)
assert_mounts 'agent still binds ~/.local/share read-write' "$output" \
	"--bind $home/.local/share $home/.local/share"
printf 'sandbox profiles: credential and mail masks pass\n'

# Order is the whole mechanism here: bwrap applies binds in argv order and lets
# a repeated destination's LAST bind win, which is why the emitter carries no
# dedupe. A pin emitted before the writable bind that contains it would be
# silently undone, and the argv would still look correct.
output=$(run "$home/dotfiles" -p agent)
rest=${output#*"--bind $home/dotfiles $home/dotfiles"}
case "$rest" in
*"--ro-bind $home/dotfiles/.agents/guardrails $home/dotfiles/.agents/guardrails"*) ;;
*)
	printf 'bwrap: the guardrails pin is not emitted after the writable dotfiles bind\n' >&2
	exit 1
	;;
esac

# $HOME is tmpfs'd before the allowlist is bound back, so an unlisted path under
# it is absent rather than merely unwritable.
case "$output" in
*"--tmpfs $home "*) ;;
*)
	printf 'bwrap: the home directory is not shadowed with a tmpfs\n' >&2
	exit 1
	;;
esac

# Masks need --perms 0000 to be masks at all; a bare --tmpfs leaves a writable
# empty directory, which passes any path-only assertion.
output=$(run "$project" -p agent)
for store in gnupg pass password-store keyrings mail zsh; do
	case "$output" in
	*"--perms 0000 --tmpfs $home/.local/share/$store"*) ;;
	*)
		printf 'bwrap: %s is not masked with mode 0000\n' "$store" >&2
		exit 1
		;;
	esac
done

# The environment allowlist must never travel in argv. bwrap's own --setenv would
# put every allowlisted secret where `ps` can read it, so the emitter strips the
# environment in the launcher instead and passes only this one non-secret marker.
case "$output" in
*"--setenv SANDBOX_ENGINE bwrap"*) ;;
*)
	printf 'bwrap: the boundary marker the pi shim looks for is missing\n' >&2
	exit 1
	;;
esac
setenv_count=$(printf '%s\n' "$output" | grep -o -- '--setenv' | wc -l)
if [ "$setenv_count" -ne 1 ]; then
	printf 'bwrap: %s --setenv tokens; values in argv are world-readable via ps\n' \
		"$setenv_count" >&2
	exit 1
fi

printf 'sandbox profiles: the emitter enforces mask, order and env policy\n'

# The bwrap root is hand-built, so two things podman's image supplied have to be
# reconstructed. Both checks are conditional on the host having the shape that
# makes them necessary: a machine whose /etc/resolv.conf is a real file, or whose
# users are in /etc/passwd, needs neither, and asserting them there would fail for
# being correct.
output=$(run "$project" -p agent)

resolv=$(readlink -f /etc/resolv.conf 2>/dev/null || true)
case "$resolv" in
"" | /etc/*) ;;
*)
	# Materialized at its real path, not /etc/resolv.conf: the latter is a symlink
	# into /run. ro-bind-data creates the destination file after its directory
	# chain, unlike a file bind whose missing destination aborts bwrap.
	case "$output" in
	*"--ro-bind-data RESOLV_FD $resolv"*) ;;
	*)
		printf 'bwrap: %s is not bound, so /etc/resolv.conf dangles and DNS dies inside\n' \
			"$resolv" >&2
		exit 1
		;;
	esac
	;;
esac

if ! awk -F: -v u="$(id -u)" '$3 == u { found = 1 } END { exit !found }' /etc/passwd 2>/dev/null &&
	getent passwd "$(id -u)" >/dev/null 2>&1; then
	# An unresolvable uid makes Node's os.userInfo() throw, inside an agent
	# written in that runtime. podman's --userns=keep-id synthesized the entry.
	case "$output" in
	*--ro-bind-data*/etc/passwd*)
		# /etc/group only when the gid actually resolves. It is a SEPARATE lookup
		# that fails separately -- on this host the primary gid resolves through no
		# source at all -- and requiring both is what once suppressed the passwd
		# entry entirely.
		if getent group "$(id -g)" >/dev/null 2>&1; then
			case "$output" in
			*--ro-bind-data*/etc/group*) ;;
			*)
				printf 'bwrap: the gid resolves but /etc/group is not reconstructed\n' >&2
				exit 1
				;;
			esac
		fi
		;;
	*)
		printf 'bwrap: this uid is not in /etc/passwd and no entry is supplied; os.userInfo() throws\n' >&2
		exit 1
		;;
	esac
fi

printf 'sandbox profiles: bwrap root reconstructs resolv.conf and passwd\n'

# --- the environment allowlist, exercised for real ----------------------------
# Every assertion above uses --dry-run, which returns before the environment is
# ever touched. That is exactly why a leak here went unnoticed: the allowlist is
# applied on the launch path only, so only a real launch can test it.
if bwrap --dev-bind / / /bin/true 2>/dev/null; then
	envprof="$home/.config/sandbox"
	mkdir -p "$envprof"
	printf 'RO+=( "$H/.config" )\n' >"$envprof/envprobe.profile"
	# This counts matching lines in the probe's output, so a launcher that dies
	# prints no matches and reads exactly like a clean run. Prove it launched
	# first — it passed vacuously for one commit when `--engine` was deleted
	# from under it.
	set +e
	ran=$(
		cd "$project" || exit 1
		HOME="$home" XDG_CONFIG_HOME="$home/.config" SANDBOX_PROFILE_PATH="$envprof" \
			"$repo/.local/scripts/sandbox" -p envprobe -- /bin/echo launched \
			2>"$tmp/envprobe-stderr"
	)
	ran_rc=$?
	set -e
	if [ "$ran_rc" -ne 0 ] || [ "$ran" != launched ]; then
		printf 'bwrap: the env probe never launched, so its silence proves nothing (exit %s)\n' \
			"$ran_rc" >&2
		cat "$tmp/envprobe-stderr" >&2
		exit 1
	fi
	leaked=$(
		cd "$project" || exit 1
		export keep=LEAK_keep allowed=LEAK_allowed name=LEAK_name d=LEAK_d \
			SECRET_CANARY=LEAK_secret
		HOME="$home" XDG_CONFIG_HOME="$home/.config" SANDBOX_PROFILE_PATH="$envprof" \
			"$repo/.local/scripts/sandbox" -p envprobe -- /usr/bin/env 2>&1 |
			grep -cE '^(keep|allowed|name|d|SECRET_CANARY)=' || true
	)
	if [ "$leaked" != 0 ]; then
		printf 'bwrap: %s non-allowlisted variable(s) crossed the boundary\n' "$leaked" >&2
		exit 1
	fi
	# The same names must not break the launch either: a name colliding with one
	# of the launcher's own variables must not corrupt the command it builds.
	if ! (
		cd "$project" || exit 1
		export p=HOSTILE d=HOSTILE resolv=HOSTILE pins=HOSTILE cmd=HOSTILE
		HOME="$home" XDG_CONFIG_HOME="$home/.config" SANDBOX_PROFILE_PATH="$envprof" \
			"$repo/.local/scripts/sandbox" -p envprobe -- /bin/true
	) 2>/dev/null; then
		printf 'bwrap: an exported name collided with the launcher and broke the launch\n' >&2
		exit 1
	fi
	printf 'sandbox profiles: the environment allowlist holds on a real launch\n'

else
	printf 'sandbox profiles: SKIPPED the real-launch environment test (bwrap unavailable)\n'
fi

# --- every directory on the sandbox PATH must be a pin, not merely read-only ---
# A writable directory on the sandbox's own PATH is a cross-session persistence
# route: whatever is dropped there runs OUTSIDE the sandbox in every later
# session. The sandbox PATH is dev.profile's SANDBOX_PATH_PREPEND plus the host
# PATH (PATH is in the default SANDBOX_ENV), and agent.profile's blanket
# read-write ~/.local/share contains several of its entries, so a plain read-only
# bind there is shadowed. The observable form of "is a pin" is "emitted after
# the writable bind", which assert_mount_order checks.
#
# Walk BOTH sources rather than naming directories: the bun bin dir, the node
# bin dir, and (2026-09-07) cargo/bin, go/bin and the kitty launcher were each
# found writable one at a time, and a name-by-name list is exactly how the next
# one hides. Every real PATH entry under $HOME/.local/share is mapped into the
# fixture home and created there so the bind can be emitted; an entry the
# profiles do not pin then fails with "never binds", which is the report wanted.
pathdirs=()
if node_bin=$(command -v node 2>/dev/null); then
	pathdirs+=("$(dirname "$(readlink -f "$node_bin")")")
fi
IFS=: read -r -a host_path <<<"$PATH"
for entry in "${host_path[@]}"; do
	case "$entry" in
	"$HOME"/.local/share/*)
		fixture="$home/${entry#"$HOME"/}"
		mkdir -p "$fixture"
		pathdirs+=("$fixture")
		;;
	esac
done
for dir in "${pathdirs[@]}"; do
	assert_path_entry_pinned "$project" agent \
		"--bind $home/.local/share $home/.local/share" \
		"$dir"
done
printf 'sandbox profiles: all %s PATH directories under a writable bind are pinned\n' "${#pathdirs[@]}"

#!/usr/bin/env bash
# Contract for `agent-checkpoint`: snapshot the working tree into a git ref so
# that emptying the guardrail `ask` tier does not make destructive commands
# unrecoverable. Allow-all rests on "git makes writes recoverable", but git only
# protects COMMITTED work; this is what makes the premise true for uncommitted
# and untracked work.
#
# Harness-agnostic by design, like the rest of ~/.agents: one script, invoked by
# whatever per-turn hook each harness provides. Refs are namespaced by
# AGENT_BRANCH_PREFIX — the same convention the shared git hooks already use —
# so checkpoints from different agents never collide.
#
# The mechanism is a temporary index (GIT_INDEX_FILE + add -A + write-tree +
# commit-tree), NOT `git stash create`, which silently omits untracked files:
# precisely the agent-authored work most at risk.
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
script="$repo/.local/scripts/agent-checkpoint"
tmp=$(mktemp -d)
trap 'chmod -R u+w "$tmp" 2>/dev/null || true; rm -r "$tmp" 2>/dev/null || true' EXIT

fail() {
	printf 'agent-checkpoint: %s\n' "$1" >&2
	exit 1
}

# A fresh fixture repo per behavior, so one test cannot mask another.
new_repo() { # name -> path
	local r="$tmp/$1"
	mkdir -p "$r" "$tmp/nohooks"
	git init -q "$r"
	git -C "$r" config core.hooksPath "$tmp/nohooks"
	git -C "$r" config user.email t@example.invalid
	git -C "$r" config user.name fixture
	printf 'original\n' >"$r/tracked.txt"
	printf 'junk.log\n' >"$r/.gitignore"
	git -C "$r" add tracked.txt .gitignore
	git -C "$r" commit -q -m init
	printf '%s' "$r"
}

refs_of() { git -C "$1" for-each-ref --format='%(refname)' refs/agent-checkpoint; }

run_in() { # repo [env assignments...] -> run the script there
	local r=$1
	shift
	(cd "$r" && env "$@" "$script" >/dev/null)
}

[ -x "$script" ] || fail "not executable (or missing): $script"

# --- 1. Outside a repo it is a silent no-op, never an error ------------------
mkdir -p "$tmp/norepo"
out=$(cd "$tmp/norepo" && GIT_CEILING_DIRECTORIES="$tmp" "$script" 2>&1) ||
	fail "non-zero exit outside a git repo"
[ -z "$out" ] || fail "expected silence outside a git repo, got: $out"

# --- 2. A clean tree records nothing -----------------------------------------
r=$(new_repo clean)
run_in "$r" || fail "non-zero exit on a clean tree"
[ -z "$(refs_of "$r")" ] || fail "a clean tree should not create a checkpoint ref"

# --- 3. Tracked modifications are captured -----------------------------------
r=$(new_repo tracked)
printf 'MODIFIED\n' >"$r/tracked.txt"
run_in "$r" || fail "non-zero exit on a dirty tree"
ref=$(refs_of "$r")
[ -n "$ref" ] || fail "a dirty tree should create exactly one checkpoint ref"
[ "$(git -C "$r" show "$ref:tracked.txt")" = "MODIFIED" ] ||
	fail "checkpoint did not capture the modified content"

# --- 4. Untracked files are captured (what `git stash create` misses) --------
r=$(new_repo untracked)
printf 'brand new\n' >"$r/untracked.txt"
run_in "$r" || fail "non-zero exit with an untracked file"
ref=$(refs_of "$r")
[ -n "$ref" ] || fail "an untracked-only change should still create a checkpoint"
git -C "$r" ls-tree -r --name-only "$ref" | grep -qx 'untracked.txt' ||
	fail "checkpoint omitted an untracked file — the stash-create bug"

# --- 5. Ignored files stay out of the snapshot -------------------------------
r=$(new_repo ignored)
printf 'MODIFIED\n' >"$r/tracked.txt"
printf 'noise\n' >"$r/junk.log"
run_in "$r" || fail "non-zero exit with an ignored file"
if git -C "$r" ls-tree -r --name-only "$(refs_of "$r")" | grep -qx 'junk.log'; then
	fail "checkpoint captured a gitignored file"
fi

# --- 6. Refs are namespaced per agent, and default when unset ----------------
# Nothing here is claude-specific; two harnesses checkpointing the same repo
# must not collide.
r=$(new_repo namespaced)
printf 'MODIFIED\n' >"$r/tracked.txt"
run_in "$r" AGENT_BRANCH_PREFIX=pi || fail "non-zero exit with a prefix set"
refs_of "$r" | grep -q '^refs/agent-checkpoint/pi/' ||
	fail "checkpoint ref was not namespaced under the agent prefix"

r=$(new_repo unprefixed)
printf 'MODIFIED\n' >"$r/tracked.txt"
run_in "$r" -u AGENT_BRANCH_PREFIX || fail "non-zero exit with no prefix set"
refs_of "$r" | grep -q '^refs/agent-checkpoint/agent/' ||
	fail "checkpoint ref did not fall back to the 'agent' namespace"

# --- 7. Snapshotting leaves the working state untouched ----------------------
r=$(new_repo sideeffects)
printf 'MODIFIED\n' >"$r/tracked.txt"
printf 'brand new\n' >"$r/untracked.txt"
before_status=$(git -C "$r" status --porcelain)
before_head=$(git -C "$r" rev-parse HEAD)
run_in "$r" || fail "non-zero exit in side-effect check"
[ "$(git -C "$r" status --porcelain)" = "$before_status" ] ||
	fail "checkpoint changed the index or working tree"
[ "$(git -C "$r" rev-parse HEAD)" = "$before_head" ] || fail "checkpoint moved HEAD"
[ "$(git -C "$r" stash list | wc -l)" -eq 0 ] || fail "checkpoint pushed onto the stash stack"
[ "$(cat "$r/tracked.txt")" = "MODIFIED" ] || fail "checkpoint altered a working file"
[ -f "$r/untracked.txt" ] || fail "checkpoint removed an untracked file"

# --- 8. Exit status separates "captured nothing" from "captured, filed oddly" -
# This is what the per-Bash hook gates on, so the two cases must not share an
# exit code. An unwritable .git captures NOTHING; allow-all rests on a snapshot
# existing, so that turn must stop. The converse -- a snapshot that exists but
# whose ref could not be written -- is case 17 and exits 0, because wedging the
# session buys nothing when the work is already recoverable.
r=$(new_repo unwritable)
printf 'MODIFIED\n' >"$r/tracked.txt"
chmod -R a-w "$r/.git"
rc=0
out=$( (cd "$r" && "$script" 2>&1 >/dev/null)) || rc=$?
chmod -R u+w "$r/.git"
[ "$rc" -ne 0 ] || fail "a checkpoint that captured nothing must exit non-zero"
printf '%s' "$out" | grep -q 'NOT recoverable' ||
	fail "a fatal checkpoint must say the work is not recoverable, got: $out"

# --- 9. A repo with no commits still gets a checkpoint -----------------------
# An unborn HEAD is where work is LEAST recoverable: there is no history to fall
# back on, so a silent no-op here loses everything the agent has written.
r="$tmp/unborn"
mkdir -p "$r"
git init -q "$r"
git -C "$r" config core.hooksPath "$tmp/nohooks"
git -C "$r" config user.email t@example.invalid
git -C "$r" config user.name fixture
printf 'precious\n' >"$r/new.txt"
run_in "$r" || fail "non-zero exit in a repo with no commits"
ref=$(refs_of "$r")
[ -n "$ref" ] || fail "an unborn HEAD should still create a checkpoint"
git -C "$r" ls-tree -r --name-only "$ref" | grep -qx 'new.txt' ||
	fail "checkpoint omitted the only file in a repo with no commits"
[ "$(git -C "$r" rev-list --count "$ref")" = "1" ] ||
	fail "checkpoint on an unborn HEAD should be parentless"

# --- 10. A failed snapshot says so on stderr ---------------------------------
# Exit 0 is required (behavior 8) but must not mean silence: the guardrail
# `allow` tier for world-writable and recursive-force-rm is earned by this
# script working. A checkpoint that silently stops leaves that premise false
# with no signal, so the failure has to reach the transcript.
r=$(new_repo loudfail)
printf 'MODIFIED\n' >"$r/tracked.txt"
chmod -R a-w "$r/.git"
err=$(cd "$r" && "$script" 2>&1 >/dev/null) || true
chmod -R u+w "$r/.git"
case $err in
*'NOT recoverable'*) ;;
*) fail "a failed checkpoint must warn on stderr; got: ${err:-<silence>}" ;;
esac

# --- 11. The legitimate no-ops stay silent -----------------------------------
# Only failure is loud. A clean tree is not a failure, and warning on every
# turn would train the user to ignore the one message that matters.
r=$(new_repo quietnoop)
out=$(cd "$r" && "$script" 2>&1) || fail "non-zero exit on a clean tree"
[ -z "$out" ] || fail "expected silence on a clean tree, got: $out"

# --- 12. Two snapshots in the same second both survive -----------------------
# The ref name is a timestamp. At second resolution two checkpoints inside one
# second collided and the later silently OVERWROTE the earlier — destroying the
# very state a recovery would want. Reproduced before this was fixed.
# Name the namespace instead of inheriting it: the assertions below query one
# explicitly, so leaving the prefix ambient made the block pass or fail on
# whether the caller's shell happened to export the same value. It passed under
# a launcher and failed from a plain shell, where the script falls back to
# its default namespace and the query below then matches nothing.
r=$(new_repo collision)
printf 'FIRST\n' >"$r/tracked.txt"
run_in "$r" AGENT_BRANCH_PREFIX=claude || fail "non-zero exit on first same-second snapshot"
printf 'SECOND\n' >"$r/tracked.txt"
run_in "$r" AGENT_BRANCH_PREFIX=claude || fail "non-zero exit on second same-second snapshot"
[ "$(refs_of "$r" | wc -l)" -eq 2 ] ||
	fail "two snapshots in one second collapsed into one ref (timestamp collision)"
# Do not trust the two runs to have landed in the same wall-clock second — that
# would pass by accident whenever they straddle a boundary. Assert the property
# that makes a collision impossible instead: nanosecond names, fixed width.
for n in $(refs_of "$r" | sed 's|.*/||'); do
	case $n in
	*[!0-9]*) fail "checkpoint ref name is not numeric: $n" ;;
	esac
	[ "${#n}" -eq 19 ] ||
		fail "checkpoint ref name is ${#n} digits, expected 19 (seconds+nanoseconds): $n"
done
# The newest ref by the script's OWN selector must be the newest snapshot: this
# is the ordering the dedup guard and every reader depend on.
newest=$(git -C "$r" for-each-ref --sort=-refname --count=1 \
	--format='%(objectname)' 'refs/agent-checkpoint/claude/')
[ "$(git -C "$r" show "$newest:tracked.txt")" = "SECOND" ] ||
	fail "for-each-ref --sort=-refname did not return the newest snapshot"

# A second-resolution name left over from before the nanosecond change must
# still lose to a nanosecond one, or the first checkpoint after the upgrade
# would dedup against a stale ref.
git -C "$r" update-ref "refs/agent-checkpoint/claude/1700000000" "$newest"
newest_after=$(git -C "$r" for-each-ref --sort=-refname --count=1 \
	--format='%(refname)' 'refs/agent-checkpoint/claude/')
case $newest_after in
*/1700000000) fail "a legacy second-resolution ref outranked a nanosecond one" ;;
esac

# --- 13. An unchanged tree does not create a second ref ----------------------
# Measured on the real repo before this guard: 241 refs over 114 distinct trees.
# Most turns (and every turn that only reads) leave the tree identical, so
# without this the ref count tracks turns rather than states.
r=$(new_repo dedup)
printf 'MODIFIED\n' >"$r/tracked.txt"
run_in "$r" || fail "non-zero exit on first snapshot"
first=$(refs_of "$r" | wc -l)
[ "$first" -eq 1 ] || fail "expected exactly one ref after the first snapshot"
run_in "$r" || fail "non-zero exit on repeat snapshot"
[ "$(refs_of "$r" | wc -l)" -eq 1 ] ||
	fail "an unchanged tree created a second checkpoint ref"

# --- 14. A changed tree still creates a new ref ------------------------------
# The dedup guard must compare trees, not just "have we ever checkpointed".
printf 'MODIFIED AGAIN\n' >"$r/tracked.txt"
run_in "$r" || fail "non-zero exit after a real change"
[ "$(refs_of "$r" | wc -l)" -eq 2 ] ||
	fail "a changed tree should create a second checkpoint ref"

# --- 15. Dedup is per agent, not global --------------------------------------
# Two harnesses in one repo must each keep their own recovery trail, even when
# they observe the same tree.
run_in "$r" AGENT_BRANCH_PREFIX=pi || fail "non-zero exit for a second agent"
refs_of "$r" | grep -q '^refs/agent-checkpoint/pi/' ||
	fail "a second agent was deduped against another agent's checkpoint"

# --- 16. A path git cannot index costs that path, not the whole snapshot -----
# The harness masks its own denied paths as /dev/null character devices at the
# root of EVERY project it opens. A masked path that is ALSO tracked makes
# `git add -A` fail outright ("can only add regular files, symbolic links or
# git-directories"), which took the snapshot down with it in every repo. A FIFO
# at a tracked path reproduces that refusal exactly and needs no privileges.
r=$(new_repo unindexable)
printf 'REAL EDIT\n' >>"$r/other.txt"
git -C "$r" add other.txt
git -C "$r" commit -q -m other
rm "$r/tracked.txt"
mkfifo "$r/tracked.txt"
printf 'MUST SURVIVE\n' >>"$r/other.txt"
run_in "$r" || fail "an unindexable path aborted the whole snapshot"
[ "$(refs_of "$r" | wc -l)" -eq 1 ] ||
	fail "no checkpoint ref written when a tracked path was unindexable"
snap=$(refs_of "$r")
git -C "$r" show "$snap:other.txt" | grep -q 'MUST SURVIVE' ||
	fail "the real edit was lost from a snapshot taken beside an unindexable path"
# The masked path keeps its committed content rather than vanishing from the
# tree, because read-tree seeds the index from HEAD before add runs.
git -C "$r" show "$snap:tracked.txt" | grep -q 'original' ||
	fail "the unindexable path should keep its HEAD content in the snapshot"

# --- 17. A snapshot that exists but files oddly is a note, not a failure -----
# The commit object is written before the ref is. If only the ref update fails
# the work IS recoverable (git fsck --lost-found finds it), so the script must
# say so and still exit 0 -- otherwise the hook blocks every Bash call in a
# session over a snapshot that succeeded.
r=$(new_repo danglingref)
printf 'MODIFIED\n' >"$r/tracked.txt"
chmod -R a-w "$r/.git/refs"
rc=0
out=$( (cd "$r" && "$script" 2>&1 >/dev/null)) || rc=$?
chmod -R u+w "$r/.git/refs"
[ "$rc" -eq 0 ] ||
	fail "a snapshot that exists must exit 0 even when its ref could not be written"
printf '%s' "$out" | grep -q 'dangling at' ||
	fail "expected the dangling snapshot to be named, got: $out"
printf '%s' "$out" | grep -q 'NOT recoverable' &&
	fail "a dangling but existing snapshot must not claim the work is unrecoverable"

printf 'agent-checkpoint: all behaviors pass\n'

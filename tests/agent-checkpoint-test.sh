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

repo=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
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
run_in "$r" AGENT_BRANCH_PREFIX=codex || fail "non-zero exit with a prefix set"
refs_of "$r" | grep -q '^refs/agent-checkpoint/codex/' ||
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

# --- 8. A failure must never wedge the session -------------------------------
# This runs on every turn; if it can exit non-zero it is worse than the prompts
# it replaces. An unwritable .git is the realistic failure mode.
r=$(new_repo unwritable)
printf 'MODIFIED\n' >"$r/tracked.txt"
chmod -R a-w "$r/.git"
rc=0
(cd "$r" && "$script" >/dev/null 2>&1) || rc=$?
chmod -R u+w "$r/.git"
[ "$rc" -eq 0 ] || fail "exited $rc when .git was unwritable; must always exit 0"

printf 'agent-checkpoint: all behaviors pass\n'

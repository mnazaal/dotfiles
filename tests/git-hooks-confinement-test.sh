#!/bin/bash
# Does the branch guard survive a cleared environment?
#
# Before: `env -i git commit` left AGENT_BRANCH_PREFIX empty, the hook exited 0,
# and the agent could commit to any branch. The guard is now driven by a marker
# that is read-only under confinement, so clearing the variable refuses every
# branch write instead of lifting the restriction.
#
# Each case states the environment, whether the marker is writable, and the
# branch -- then asserts what the hook should do.
set -uo pipefail

HOOKS="${1:-$(cd "$(dirname "$0")/../.config/git/hooks" && pwd)}"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

pass=0; fail=0
check() { # name expected actual
	if [ "$2" = "$3" ]; then pass=$((pass+1)); printf '  ok   %-58s %s\n' "$1" "$2"
	else fail=$((fail+1)); printf '  FAIL %-58s want=%s got=%s\n' "$1" "$2" "$3"; fi
}

# A marker we control: writable = "outside", chmod 444 = "confined".
MARKER_HOME="$WORK/home"
mkdir -p "$MARKER_HOME/.claude"
printf '{}' > "$MARKER_HOME/.claude/settings.json"

run_ref_txn() { # env_prefix marker_mode branch -> "allow"|"refuse"
	local prefix="$1" mode="$2" branch="$3"
	chmod "$mode" "$MARKER_HOME/.claude/settings.json"
	local out
	# Always pass the variable, empty when "unset". The session running this
	# test exports AGENT_BRANCH_PREFIX itself, so a conditional assignment let
	# every case inherit it and the harness tested nothing.
	out=$(cd "$WORK" && HOME="$MARKER_HOME" AGENT_BRANCH_PREFIX="$prefix" \
		bash "$HOOKS/reference-transaction" prepared \
		<<< "0000 1111 refs/heads/$branch" 2>&1)
	local rc=$?
	chmod 644 "$MARKER_HOME/.claude/settings.json"
	[ $rc -eq 0 ] && echo allow || echo refuse
}

echo "== human: marker writable, no prefix =="
check "commit to main"            allow  "$(run_ref_txn ""       644 main)"
check "commit to feature/x"       allow  "$(run_ref_txn ""       644 feature/x)"

echo "== agent, prefix set (today's behaviour, must not regress) =="
check "claude/topic allowed"      allow  "$(run_ref_txn "claude" 644 claude/topic)"
check "main refused"              refuse "$(run_ref_txn "claude" 644 main)"
check "worktree-claude-x allowed" allow  "$(run_ref_txn "claude" 644 worktree-claude-x)"

echo "== THE FIX: confined, environment cleared =="
check "main refused"              refuse "$(run_ref_txn ""       444 main)"
check "any branch refused"        refuse "$(run_ref_txn ""       444 claude/topic)"

echo "== confined AND prefix set: ordinary agent work still flows =="
check "claude/topic allowed"      allow  "$(run_ref_txn "claude" 444 claude/topic)"
check "main refused"              refuse "$(run_ref_txn "claude" 444 main)"

echo "== portability: no marker at all => variable alone, as before =="
rm -f "$MARKER_HOME/.claude/settings.json"
out=$(cd "$WORK" && HOME="$MARKER_HOME" AGENT_BRANCH_PREFIX= \
	bash "$HOOKS/reference-transaction" prepared \
	<<< "0000 1111 refs/heads/main" 2>&1); rc=$?
check "no marker, no prefix: allowed" allow "$([ $rc -eq 0 ] && echo allow || echo refuse)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

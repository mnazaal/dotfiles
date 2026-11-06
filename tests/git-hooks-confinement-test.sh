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

# The hook lists the commits an update adds, so it needs a repository and real
# object names. Setup commits run with no hooks at all.
git -C "$WORK" -c init.defaultBranch=main init -q
GIT_CONFIG_GLOBAL=/dev/null git -C "$WORK" -c core.hooksPath=/dev/null -c user.name=t -c user.email=t@t \
	commit -q --allow-empty -m base
BASE=$(git -C "$WORK" rev-parse HEAD)
ZERO=0000000000000000000000000000000000000000

pass=0
fail=0
check() { # name expected actual
	if [ "$2" = "$3" ]; then
		pass=$((pass + 1))
		printf '  ok   %-58s %s\n' "$1" "$2"
	else
		fail=$((fail + 1))
		printf '  FAIL %-58s want=%s got=%s\n' "$1" "$2" "$3"
	fi
}

# A marker we control: writable = "outside", chmod 444 = "confined".
MARKER_HOME="$WORK/home"
mkdir -p "$MARKER_HOME/dotfiles/.claude"
printf '{}' >"$MARKER_HOME/dotfiles/.claude/settings.json"

run_ref_txn() { # env_prefix marker_mode branch -> "allow"|"refuse"
	local prefix="$1" mode="$2" branch="$3"
	chmod "$mode" "$MARKER_HOME/dotfiles/.claude/settings.json"
	local _out
	# Always pass the variable, empty when "unset". The session running this
	# test exports AGENT_BRANCH_PREFIX itself, so a conditional assignment let
	# every case inherit it and the harness tested nothing.
	_out=$(cd "$WORK" && HOME="$MARKER_HOME" AGENT_BRANCH_PREFIX="$prefix" \
		bash "$HOOKS/reference-transaction" prepared \
		<<<"$ZERO $BASE refs/heads/$branch" 2>&1)
	local rc=$?
	chmod 644 "$MARKER_HOME/dotfiles/.claude/settings.json"
	[ $rc -eq 0 ] && echo allow || echo refuse
}

echo "== human: marker writable, no prefix =="
check "commit to main" allow "$(run_ref_txn "" 644 main)"
check "commit to feature/x" allow "$(run_ref_txn "" 644 feature/x)"

echo "== agent, prefix set (today's behaviour, must not regress) =="
check "claude/topic allowed" allow "$(run_ref_txn "claude" 644 claude/topic)"
check "main refused" refuse "$(run_ref_txn "claude" 644 main)"
check "worktree-claude-x allowed" allow "$(run_ref_txn "claude" 644 worktree-claude-x)"

echo "== THE FIX: confined, environment cleared =="
check "main refused" refuse "$(run_ref_txn "" 444 main)"
check "any branch refused" refuse "$(run_ref_txn "" 444 claude/topic)"

echo "== confined AND prefix set: ordinary agent work still flows =="
check "claude/topic allowed" allow "$(run_ref_txn "claude" 444 claude/topic)"
check "main refused" refuse "$(run_ref_txn "claude" 444 main)"

echo "== human: a read-only deployed copy is not confinement =="
mkdir -p "$MARKER_HOME/.claude"
printf '{}' >"$MARKER_HOME/.claude/settings.json"
chmod 444 "$MARKER_HOME/.claude/settings.json"
check "read-only ~/.claude/settings.json: main allowed" allow "$(run_ref_txn "" 644 main)"

echo "== portability: no marker at all => variable alone, as before =="
rm -f "$MARKER_HOME/dotfiles/.claude/settings.json"
# Output is captured only to keep it off the test's stdout; the verdict is rc.
_out=$(cd "$WORK" && HOME="$MARKER_HOME" AGENT_BRANCH_PREFIX='' \
	bash "$HOOKS/reference-transaction" prepared \
	<<<"$ZERO $BASE refs/heads/main" 2>&1)
rc=$?
check "no marker, no prefix: allowed" allow "$([ $rc -eq 0 ] && echo allow || echo refuse)"

echo "== hand-written .tex: agents may not commit it, by any route =="
# Real git operations with every hook installed. The marker stays writable, so
# the prefix alone marks a session as an agent's, and an empty one as the user's.
REPO="$WORK/tex"
git -c init.defaultBranch=main init -q "$REPO"
printf '{}' >"$MARKER_HOME/dotfiles/.claude/settings.json"
g() { # prefix git-args... -> "allow"|"refuse"|"error"
	# A refusal counts only when a hook printed one; any other failure (nothing
	# to commit, a patch that does not apply) would pass a refuse case for the
	# wrong reason.
	local prefix=$1
	shift
	if (cd "$REPO" && HOME="$MARKER_HOME" AGENT_BRANCH_PREFIX="$prefix" \
		GIT_CONFIG_GLOBAL=/dev/null git -c core.hooksPath="$HOOKS" \
		-c user.name=t -c user.email=t@t "$@") >"$WORK/g.log" 2>&1; then
		echo allow
	elif grep -q 'HOOK ERROR' "$WORK/g.log"; then
		echo refuse
	else
		echo error
	fi
}
put() { mkdir -p "$REPO/$(dirname "$1")" && printf '%s\n' "$2" >"$REPO/$1"; }
put paper/main.tex v1
put notes.md v1
g "" add -A >/dev/null
check "user commits main.tex on main" allow "$(g "" commit -q -m base)"

g claude switch -q -c claude/a >/dev/null
put paper/main.tex agent
g claude add paper/main.tex >/dev/null
check "agent commits main.tex" refuse "$(g claude commit -q -m tex)"
g claude reset -q --hard >/dev/null
put paper/tables/generated/t.tex row
g claude add paper/tables/generated/t.tex >/dev/null
check "agent commits a generated table" allow "$(g claude commit -q -m table)"
g claude switch -q main >/dev/null
check "agent deletes its branch" allow "$(g claude branch -q -D claude/a)"

# The user's own .tex commit on main must not block an agent branch built on it.
put paper/main.tex v2
g "" add paper/main.tex >/dev/null
check "user commits main.tex v2" allow "$(g "" commit -q -m v2)"
USER_TEX=$(git -C "$REPO" rev-parse HEAD)
check "agent branches from main" allow "$(g claude branch claude/b main)"
# Move main back, so only claude/b still reaches the user's commit.
g "" reset -q --hard HEAD~1 >/dev/null
g claude switch -q -c claude/c main >/dev/null
put notes.md agent
g claude add notes.md >/dev/null
check "agent commits a non-.tex file" allow "$(g claude commit -q -m notes)"
# On a different parent, so the pick is a new commit rather than the user's
# own one recreated byte for byte.
check "agent cherry-picks the user's .tex commit" refuse "$(g claude cherry-pick "$USER_TEX")"
g claude cherry-pick --abort >/dev/null
g claude reset -q --hard >/dev/null
g "" switch -q main >/dev/null
check "user moves main to the .tex commit" allow "$(g "" merge -q --ff-only "$USER_TEX")"
g claude switch -q claude/c >/dev/null
check "agent rebases onto main holding user .tex" allow "$(g claude rebase -q main)"
g "" switch -q main >/dev/null
put paper/main.tex v3
g "" add paper/main.tex >/dev/null
check "user commits main.tex v3" allow "$(g "" commit -q -m v3)"
g claude switch -q claude/c >/dev/null
check "agent merges main with a merge commit" refuse \
	"$(ALLOW_MERGE_COMMIT=1 g claude merge -q --no-ff -m m main)"
g claude merge --abort >/dev/null
tree=$(cd "$REPO" && printf 'x\n' | git hash-object -w --stdin)
tree=$(cd "$REPO" && printf '100644 blob %s\tmain.tex\n' "$tree" | git mktree)
plumb=$(cd "$REPO" && GIT_CONFIG_GLOBAL=/dev/null git -c user.name=t -c user.email=t@t commit-tree -m p -p HEAD "$tree")
check "agent update-ref to a plumbing .tex commit" refuse "$(g claude update-ref refs/heads/claude/d "$plumb")"
check "user may land that same commit" allow "$(g "" update-ref refs/heads/user-d "$plumb")"

# Settings an agent can pass on its own command line or environment, each of
# which hid a change from an earlier version of the listing.
put paper/main.tex literal
g claude add paper/main.tex >/dev/null
check "agent commit under GIT_LITERAL_PATHSPECS" refuse "$(GIT_LITERAL_PATHSPECS=1 g claude commit -q -m lit)"
check "agent commit under GIT_GLOB_PATHSPECS" refuse "$(GIT_GLOB_PATHSPECS=1 g claude commit -q -m glob)"
g claude reset -q --hard >/dev/null
put paper/ch.TEX upper
g claude add paper/ch.TEX >/dev/null
check "agent commits an upper-case .TEX" refuse "$(g claude commit -q -m upper)"
g claude reset -q --hard >/dev/null
rm -f "$REPO/paper/ch.TEX"
# A commit no branch reaches yet, hidden behind a twin that changes nothing.
hidden=$(cd "$REPO" && GIT_CONFIG_GLOBAL=/dev/null git -c user.name=t -c user.email=t@t commit-tree -m hidden -p HEAD "$tree")
twin=$(cd "$REPO" && GIT_CONFIG_GLOBAL=/dev/null git -c user.name=t -c user.email=t@t commit-tree -m twin -p HEAD "HEAD^{tree}")
check "agent writes a replace ref" refuse "$(g claude replace "$hidden" "$twin")"
g "" replace "$hidden" "$twin" >/dev/null
check "agent update-ref behind a replace ref" refuse "$(g claude update-ref refs/heads/claude/r "$hidden")"
g "" replace -d "$hidden" >/dev/null
# The graft gives main the hidden commit as a parent, so a walk that honoured
# it would count the hidden commit as already on a branch.
printf '%s %s\n' "$(git -C "$REPO" rev-parse main)" "$hidden" >"$WORK/grafts"
check "agent update-ref under a graft file" refuse \
	"$(GIT_GRAFT_FILE="$WORK/grafts" g claude update-ref refs/heads/claude/graft "$hidden")"
(cd "$REPO" && git format-patch -q -1 --stdout main >"$WORK/v3.patch")
check "agent applies the user's .tex patch with am" refuse "$(g claude am -q "$WORK/v3.patch")"
g claude am --abort >/dev/null
g claude reset -q --hard >/dev/null
g claude switch -q --orphan claude/o >/dev/null
put paper/main.tex root
g claude add paper/main.tex >/dev/null
check "agent root commit with log.showRoot off" refuse "$(g claude -c log.showRoot=false commit -q -m root)"

printf '\n%d passed, %d failed\n' "$pass" "$fail"
[ "$fail" -eq 0 ]

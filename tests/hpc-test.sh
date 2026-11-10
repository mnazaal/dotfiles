#!/usr/bin/env bash
# Contract for `hpc`'s live-run guard: a launch must never move the cluster
# working copy off the commit a live run is using, not even for a moment, and a
# refused launch leaves branch and commit where that run left them. ssh is
# stubbed to run the remote script locally, against a fixture home that stands
# in for the cluster's. A post-checkout hook records every tree the cluster
# copy passes through.
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
hpc="$repo/.local/scripts/hpc"
tmp=$(mktemp -d)
live=""
trap '[ -z "$live" ] || kill "$live" 2>/dev/null || true; rm -rf "$tmp"' EXIT

fail() {
	printf 'hpc: %s\n' "$1" >&2
	[ ! -s "$tmp/err" ] || cat "$tmp/err" >&2
	exit 1
}

export HOME="$tmp/home"
mkdir -p "$tmp/bin" "$tmp/hooks" "$HOME/projects"
# The remote half arrives as one string after the host, exactly as ssh hands it
# to the remote login shell.
cat >"$tmp/bin/ssh" <<'SH'
#!/bin/sh
shift
exec bash -c "$*"
SH
# The remote script waits 45 s before showing the queue.
printf '#!/bin/sh\nexit 0\n' >"$tmp/bin/sleep"
cat >"$tmp/hooks/post-checkout" <<SH
#!/bin/sh
[ "\$(pwd)" = "$HOME/projects/proj" ] && cat f >>"$tmp/trees"
exit 0
SH
chmod +x "$tmp/bin/ssh" "$tmp/bin/sleep" "$tmp/hooks/post-checkout"

g() { git -c core.hooksPath="$tmp/hooks" -c user.email=t@example.invalid -c user.name=fixture "$@"; }
commit() { # repo content -> new commit on the current branch
	echo "$2" >"$1/f"
	g -C "$1" commit -q -am "$2"
}

origin="$tmp/origin.git"
laptop="$tmp/proj"
cluster="$HOME/projects/proj"
runs="$cluster/results/hpc"
g init -q --bare -b main "$origin"
g init -q -b main "$laptop"
g -C "$laptop" remote add origin "$origin"
echo a >"$laptop/f"
g -C "$laptop" add f
g -C "$laptop" commit -q -m a
g -C "$laptop" checkout -q -b probe
commit "$laptop" b
g -C "$laptop" push -q origin main probe
a_sha=$(g -C "$laptop" rev-parse main)
b_sha=$(g -C "$laptop" rev-parse probe)

# The cluster copy runs a probe launched from the probe branch, still alive,
# and holds a local main left behind at a.
g clone -q -b probe "$origin" "$cluster"
g -C "$cluster" config core.hooksPath "$tmp/hooks"
g -C "$cluster" branch -q main origin/main
mkdir -p "$runs"
sleep 300 &
live=$!
echo "$live" >"$runs/probe-run.pid"

launch() { # laptop branch, run name -> exit status of an hpc launch
	: >"$tmp/trees"
	g -C "$laptop" checkout -q "$1"
	(cd "$laptop" && PATH="$tmp/bin:$PATH" bash "$hpc" --host fixture --name "$2" true) >"$tmp/out" 2>"$tmp/err"
}
# A launched run counts as live until it writes its exit file.
settle() {
	for _ in $(seq 100); do
		[ ! -e "$runs/$1.exit" ] || return 0
		sleep 0.1
	done
	fail "run $1 never wrote its exit file"
}
on() { # sha branch -> whether the cluster copy is there, with nothing in between
	[ "$(git -C "$cluster" rev-parse HEAD)" = "$1" ] && [ "$(git -C "$cluster" branch --show-current)" = "$2" ]
}

# Relaunching the live run's own commit is the common case and goes through.
launch probe same-commit || fail 'refused a relaunch of the live run commit'
settle same-commit
on "$b_sha" probe || fail 'same-commit relaunch moved the working copy'

# A launch from another branch refuses, before touching the working copy.
if launch main blocked; then fail 'launched from main while the probe run was live'; fi
grep -q "run 'probe-run' is still running here" "$tmp/err" || fail 'refused for some other reason'
grep -q "from $b_sha to $a_sha" "$tmp/err" || fail 'refusal does not name the live run commit as the source'
on "$b_sha" probe || fail 'refused launch still moved the working copy'
[ ! -s "$tmp/trees" ] || fail 'refused launch checked out a tree'

# The laptop's main catches up with the live commit; the cluster's main gains a
# commit origin never had. Refused for that commit, and the tree never moves.
g -C "$laptop" merge -q --ff-only probe
g -C "$laptop" push -q origin main
g -C "$cluster" update-ref refs/heads/main "$(g -C "$cluster" commit-tree -p "$a_sha" -m stale "$a_sha^{tree}")"
if launch main unpushed; then fail 'launched over unpushed cluster commits'; fi
grep -q 'not in origin/main' "$tmp/err" || fail 'refused unpushed commits for some other reason'
on "$b_sha" probe || fail 'refused unpushed launch moved the working copy'
[ ! -s "$tmp/trees" ] || fail 'refused unpushed launch checked out a tree'

# With the cluster's main merely behind, the launch goes through and passes
# straight to the live commit, never through main's old tree.
g -C "$cluster" update-ref refs/heads/main "$a_sha"
launch main behind || fail 'refused a launch of the live commit from a stale local branch'
settle behind
on "$b_sha" main || fail 'launch from a stale local branch did not land on the pushed commit'
[ "$(cat "$tmp/trees")" = b ] || fail "the working copy passed through other trees: $(tr '\n' ' ' <"$tmp/trees")"

# Once the run ends, a launch of new code goes through and lands on it.
kill "$live"
wait "$live" 2>/dev/null || true
live=""
g -C "$laptop" checkout -q main
commit "$laptop" c
c_sha=$(g -C "$laptop" rev-parse main)
launch main allowed || fail 'launch refused after the live run ended'
settle allowed
on "$c_sha" main || fail 'launch did not land on the laptop commit'

echo 'hpc: ok'

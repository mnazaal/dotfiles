#!/usr/bin/env bash
# Local test harness for the frozen-code mode of hpc. No network, no
# cluster: a bare repo stands in for GitHub, a clone of it for the cluster working copy,
# and HPC_SSH runs the "remote" half with local bash.
#   bash tests/hpc-frozen-code-test.sh [path/to/hpc]   (default: .local/scripts/hpc)
# The uv cases (venv per commit) run offline and are skipped when uv is not installed.
# Fixture requirement, learned by running it on 2026-11-17:
#   - the branch is <prefix>/test for the session's $AGENT_BRANCH_PREFIX (pi when unset), because
#     shared git hooks refuse commits outside $AGENT_BRANCH_PREFIX/*.
# Runtime ~1-2 min: the 45 s "your queue" hint the remote half ends with is stubbed
# below, since no case asserts on it and 13 launches x 45 s would cost ten minutes.
# shellcheck disable=SC2034  # sha_*, n_before, rc are read inside check()'s eval strings
set -uo pipefail
HPC=$(realpath "${1:-$(dirname "$0")/../.local/scripts/hpc}")
T=$(mktemp -d "${TMPDIR:-/tmp}/hpc-test.XXXXXX")
[[ -n "${KEEP:-}" ]] && echo "kept: $T" || trap 'rm -rf "$T"' EXIT
pass=0
fail=0
ok() {
	echo "PASS  $1"
	pass=$((pass + 1))
}
bad() {
	echo "FAIL  $1"
	fail=$((fail + 1))
}
check() { if eval "$2"; then ok "$1"; else bad "$1"; fi; }

cat >"$T/fake-ssh" <<'EOF'
#!/usr/bin/env bash
shift            # drop the host; ssh joins the rest into one remote command string
exec bash -c "$*"
EOF
chmod +x "$T/fake-ssh"
# Stub only the remote half's ~45 s squeue hint; every other sleep passes through,
# because the A/B race cases depend on real ones.
mkdir -p "$T/bin"
printf '#!/usr/bin/env bash\n[ "$1" = 45 ] && exit 0\nexec /bin/sleep "$@"\n' >"$T/bin/sleep"
chmod +x "$T/bin/sleep"
export PATH="$T/bin:$PATH"
export HPC_SSH="$T/fake-ssh" HPC_HOST=local HPC_DIR="$T/cluster"
BR="${AGENT_BRANCH_PREFIX:-pi}/test"
unset VIRTUAL_ENV UV_PROJECT UV_PROJECT_ENVIRONMENT
G() { git -c user.email=t@t -c user.name=t "$@"; }

wait_exit() { # wait_exit <name> [runs dir]: wait (max 30 s) for a run's .exit file; print its code
	local f="${2:-$T/cluster/results/hpc}/$1.exit"
	for _ in $(seq 300); do
		[[ -s "$f" ]] && {
			cat "$f"
			return
		}
		sleep 0.1
	done
	echo "timeout"
}
launch() { # launch <name> <shell script>; run from the laptop repo
	(cd "$T/laptop" && "$HPC" --name "$1" -- sh -c "$2") >"$T/$1.launch" 2>&1
}

# origin (bare), laptop repo, cluster working copy -------------------------------------
git init -q --bare "$T/origin.git"
git -C "$T/origin.git" symbolic-ref HEAD refs/heads/"$BR"
G init -q -b "$BR" "$T/laptop"
cd "$T/laptop" || exit 1
printf 'results/\n.venv*/\n' >.gitignore
echo "version A" >code.txt
G add . && G commit -qm A && G remote add origin "$T/origin.git" && G push -q -u origin "$BR"
git clone -q "$T/origin.git" "$T/cluster" 2>/dev/null
sha_A=$(git rev-parse HEAD)

# 1. default mode (no marker) keeps today's behaviour -----------------------------------
launch def1 'mkdir -p results; cat code.txt > results/def1.txt; echo "$HPC_CODE" > results/def1.code'
check "default mode: launch runs" '[[ $(wait_exit def1) == 0 ]]'
check "default mode: reads the reset working copy" '[[ $(cat "$T/cluster/results/def1.txt") == "version A" ]]'
check "default mode: HPC_CODE is the working copy" '[[ $(cat "$T/cluster/results/def1.code") == "$T/cluster" ]]'

# enable frozen-code mode, exactly as the script header says ----------------------------
(cd "$T/cluster" && mkdir -p .hpc && touch .hpc/frozen-code && git sparse-checkout set --no-cone '/.hpc-no-tracked-files')
check "enable: shared copy holds no committed files" '[[ ! -e "$T/cluster/code.txt" ]]'
check "enable: outputs survive" '[[ -e "$T/cluster/results/def1.txt" ]]'

# 2. A runs slowly, B is launched while A waits; each reads its own commit --------------
launch A 'sleep 3; mkdir -p results; cat "$HPC_CODE/code.txt" > results/A.txt; echo "$HPC_CODE" > results/A.code'
cd "$T/laptop" || exit 1
echo "version B" >code.txt
G commit -qam B
sha_B=$(git rev-parse HEAD)
launch B 'mkdir -p results; cat "$HPC_CODE/code.txt" > results/B.txt'
check "B launches while A is still running" '[[ $(wait_exit B) == 0 ]]'
check "A still running when B finished" '[[ ! -e "$T/cluster/results/hpc/A.exit" ]]'
check "A finishes" '[[ $(wait_exit A) == 0 ]]'
check "A read commit A although B launched first" '[[ $(cat "$T/cluster/results/A.txt") == "version A" ]]'
check "B read commit B" '[[ $(cat "$T/cluster/results/B.txt") == "version B" ]]'
check "A ran from its own worktree" '[[ $(cat "$T/cluster/results/A.code") == "$T/cluster/.hpc/wt/$sha_A" ]]'
check "outputs of both land in the shared results/" '[[ -e "$T/cluster/results/A.txt" && -e "$T/cluster/results/B.txt" ]]'
check "run records its commit" '[[ $(cat "$T/cluster/results/hpc/B.sha") == "$sha_B" ]]'
check "shared copy still holds no committed files" '[[ ! -e "$T/cluster/code.txt" ]]'

# 3. relaunching a commit reuses its worktree ---------------------------------------------
n_before=$(git -C "$T/cluster" worktree list | wc -l)
launch B2 'mkdir -p results; cat "$HPC_CODE/code.txt" > results/B2.txt'
check "relaunch same commit runs" '[[ $(wait_exit B2) == 0 ]]'
check "relaunch reuses the worktree" '[[ $(git -C "$T/cluster" worktree list | wc -l) == "$n_before" ]]'

# 4. a cwd-relative read of a committed file fails loudly ---------------------------------
launch rel 'LC_ALL=C cat code.txt'
# cat's own failure, not wait_exit's "timeout": a hung run must not pass.
rc=$(wait_exit rel)
check "cwd-relative read of a committed file fails" '[[ $rc == 1 ]] && grep -q "code.txt: No such file" "$T/cluster/results/hpc/rel.log"'

# 5. .env can map HPC_CODE onto tooling ---------------------------------------------------
echo 'UV_PROJECT=$HPC_CODE' >"$T/cluster/.env"
launch env 'mkdir -p results; echo "$UV_PROJECT" > results/env.txt'
check ".env sees HPC_CODE" '[[ $(wait_exit env) == 0 && $(cat "$T/cluster/results/env.txt") == "$T/cluster/.hpc/wt/$sha_B" ]]'

# .env imports UPPERCASE keys other than HPC_CODE; it cannot rebind hpc's own variables
# (here `name`, which names the run's .sha file) and names what it skipped.
printf 'name=clobbered\nlower_key=x\nHPC_CODE=/elsewhere\nUP_KEY=y\n' >"$T/cluster/.env"
launch envkeys 'mkdir -p results; printf "%s|%s|%s\n" "$HPC_CODE" "${lower_key-unset}" "$UP_KEY" > results/envkeys.txt'
check ".env: a lowercase key cannot rebind hpc's variables" '[[ $(wait_exit envkeys) == 0 && $(cat "$T/cluster/results/hpc/envkeys.sha") == "$sha_B" && ! -e "$T/cluster/results/hpc/clobbered.sha" ]]'
check ".env: lowercase keys stay out of the run, UPPERCASE ones arrive" '[[ $(cut -d"|" -f2,3 "$T/cluster/results/envkeys.txt") == "unset|y" ]]'
check ".env: HPC_CODE stays the run's worktree" '[[ $(cut -d"|" -f1 "$T/cluster/results/envkeys.txt") == "$T/cluster/.hpc/wt/$sha_B" ]]'
check ".env: skipped keys are named" 'w=$(grep "not imported" "$T/envkeys.launch") && [[ $w == *HPC_CODE* && $w == *lower_key* && $w == *name* ]]'
rm "$T/cluster/.env"

# 6. two simultaneous launches of a new commit share one worktree -------------------------
cd "$T/laptop" || exit 1
echo "version C" >code.txt

G commit -qam C
sha_C=$(git rev-parse HEAD)
G push -q origin "$BR"
launch C1 'mkdir -p results; cat "$HPC_CODE/code.txt" > results/C1.txt' &
launch C2 'mkdir -p results; cat "$HPC_CODE/code.txt" > results/C2.txt' &
wait
check "concurrent launches both run" '[[ $(wait_exit C1) == 0 && $(wait_exit C2) == 0 ]]'
check "concurrent launches read commit C" '[[ $(cat "$T/cluster/results/C1.txt") == "version C" && $(cat "$T/cluster/results/C2.txt") == "version C" ]]'
check "one worktree for commit C" '[[ $(git -C "$T/cluster" worktree list | grep -c "$sha_C") == 1 ]]'

# 7. committed files reappearing in the shared copy block launches ------------------------
git -C "$T/cluster" sparse-checkout disable >/dev/null 2>&1
launch blocked 'true'
rc=$?
check "launch refused when committed files reappear" '[[ $rc != 0 && ! -e "$T/cluster/results/hpc/blocked.pid" ]]'
check "refusal says how to restore" 'grep -q "sparse-checkout set" "$T/blocked.launch"'
git -C "$T/cluster" sparse-checkout set --no-cone '/.hpc-no-tracked-files'

# 8. a dirty laptop tree is still refused (unchanged check) -------------------------------
cd "$T/laptop" || exit 1
echo "dirty" >>code.txt
launch dirty 'true'
rc=$?
check "dirty laptop tree refused" '[[ $rc != 0 ]]'
git checkout -q code.txt

# 9. uv: one venv per commit inside its worktree, none in the shared copy ------------------
if command -v uv >/dev/null; then
	cd "$T/laptop" || exit 1
	printf '[project]\nname = "p"\nversion = "0"\nrequires-python = ">=3.8"\ndependencies = []\n[tool.uv]\npackage = false\n' >pyproject.toml
	UV_OFFLINE=1 uv lock -q && G add pyproject.toml uv.lock && G commit -qm D && G push -q origin "$BR"
	sha_D=$(git rev-parse HEAD)
	printf 'UV_PROJECT=$HPC_CODE\nUV_PROJECT_ENVIRONMENT=.venv-arch\nUV_FROZEN=1\nUV_OFFLINE=1\n' >"$T/cluster/.env"
	py='import sys, os; print(sys.prefix); print(os.getcwd())'
	launch uvD "sleep 2; mkdir -p results; uv run -q python -c '$py' > results/uvD.txt"
	echo "# E" >>pyproject.toml
	G commit -qam E
	sha_E=$(git rev-parse HEAD)
	launch uvE "mkdir -p results; uv run -q python -c '$py' > results/uvE.txt"
	check "uv: commit E launches while D runs" '[[ $(wait_exit uvE) == 0 ]]'
	check "uv: D finishes" '[[ $(wait_exit uvD) == 0 ]]'
	check "uv: D uses the venv in its own worktree" '[[ $(sed -n 1p "$T/cluster/results/uvD.txt") == "$T/cluster/.hpc/wt/$sha_D/.venv-arch" ]]'
	check "uv: E uses the venv in its own worktree" '[[ $(sed -n 1p "$T/cluster/results/uvE.txt") == "$T/cluster/.hpc/wt/$sha_E/.venv-arch" ]]'
	check "uv: cwd is the shared copy" '[[ $(sed -n 2p "$T/cluster/results/uvE.txt") == "$T/cluster" ]]'
	check "uv: no venv in the shared copy" '! compgen -G "$T/cluster/.venv*" >/dev/null'
	check "uv: worktrees stay unmodified" '[[ -z $(git -C "$T/cluster/.hpc/wt/$sha_D" status --porcelain) && -z $(git -C "$T/cluster/.hpc/wt/$sha_E" status --porcelain) ]]'

	# 10. an absolute UV_PROJECT_ENVIRONMENT would share one venv across commits: refused
	echo 'UV_PROJECT_ENVIRONMENT=/shared/venv' >>"$T/cluster/.env"
	launch absenv 'true'
	rc=$?
	check "uv: absolute UV_PROJECT_ENVIRONMENT refused" '[[ $rc != 0 && ! -e "$T/cluster/results/hpc/absenv.pid" ]] && grep -q "Make it relative" "$T/absenv.launch"'
	rm "$T/cluster/.env"
else
	echo "SKIP  uv cases (uv not installed)"
fi

# 11. a clone whose remote HEAD names a missing branch has no HEAD; it still launches --
git -C "$T/origin.git" symbolic-ref HEAD refs/heads/missing
git clone -q "$T/origin.git" "$T/cluster2" 2>/dev/null
git -C "$T/origin.git" symbolic-ref HEAD refs/heads/"$BR"
cd "$T/laptop" || exit 1
want=$(git rev-parse HEAD)
(HPC_DIR="$T/cluster2" "$HPC" --name unborn -- sh -c 'cat code.txt > /dev/null') >"$T/unborn.launch" 2>&1
check "unborn HEAD: launch runs" '[[ $(cat "$T/cluster2/results/hpc/unborn.exit" 2>/dev/null || { sleep 2; cat "$T/cluster2/results/hpc/unborn.exit"; }) == 0 ]]'
check "unborn HEAD: copy is on the pushed commit" '[[ $(git -C "$T/cluster2" rev-parse HEAD) == "$want" ]]'

# 12. the launch lock stays held until the run's pidfile exists ----------------------------
# Otherwise a second launch can take the lock, find no pidfile, and move the tree under a run
# that has already started. Made deterministic without timing: .env (sourced after hpc's
# name check) turns the pidfile into a FIFO, so the launch blocks writing it until the run
# reads it, and the run first records whether a launch lock -- at the runs-dir path or the
# git-dir path -- can be taken. It then hands the pid back for the launch's own read.
printf '[ "$name" != lockprobe ] || mkfifo "%s"\n' "$T/cluster/results/hpc/lockprobe.pid" >"$T/cluster/.env"
cat >"$T/lockprobe.sh" <<'EOF'
r=$PWD/results/hpc
held=no
for l in "$r/.launch.lock" "$PWD/.git/hpc-launch.lock"; do flock -n "$l" true || held=yes; done
echo "$held" >"$r/lockprobe.held"
p=$(cat "$r/lockprobe.pid")
echo "$p" >"$r/lockprobe.pid"
EOF
(cd "$T/laptop" && timeout 60 "$HPC" --name lockprobe -- sh "$T/lockprobe.sh") >"$T/lockprobe.launch" 2>&1
check "launch lock held until the pidfile is written" '[[ $(wait_exit lockprobe) == 0 && $(cat "$T/cluster/results/hpc/lockprobe.held") == yes ]]'
rm "$T/cluster/.env"

# 13. lock and live-run guard belong to the working copy, not to the runs dir ---------------
# Default-mode copies: cluster3 (also reached through a symlink), cluster4 and cluster5.
# Long runs wait for a release file, bounded, instead of sleeping a guessed time.
cd "$T/laptop" || exit 1
echo "version F" >code.txt
G commit -qam F && G push -q origin "$BR"
for c in cluster3 cluster4 cluster5; do git clone -q "$T/origin.git" "$T/$c" 2>/dev/null; done
ln -s "$T/cluster3" "$T/cluster3-link"
shared="$T/shared-runs"
hold() { # shell snippet: wait (max 60 s) for release file $1
	printf 'timeout 60 sh -c '\''while [ ! -e "$0" ]; do sleep 0.1; done'\'' %s' "$T/release-$1"
}

# A launch into cluster4, held inside its lock (in .env), must not stall a launch into
# cluster5 that merely shares the runs dir.
printf 'touch "%s"; %s\n' "$T/s3-in-lock" "$(hold s3)" >"$T/cluster4/.env"
HPC_DIR="$T/cluster4" HPC_RUNS_DIR="$shared" launch S3 'true' &
s3=$!
for _ in $(seq 300); do
	[[ -e "$T/s3-in-lock" ]] && break
	sleep 0.1
done
(cd "$T/laptop" && HPC_DIR="$T/cluster5" HPC_RUNS_DIR="$shared" timeout 20 "$HPC" --name S4 -- true) >"$T/S4.launch" 2>&1
rc=$?
check "copies sharing a runs dir do not wait on each other's lock" '[[ -e "$T/s3-in-lock" && $rc == 0 ]]'
touch "$T/release-s3"
wait "$s3"
rm "$T/cluster4/.env"

# A live run of cluster4 in the shared runs dir does not block moving cluster5.
HPC_DIR="$T/cluster4" HPC_RUNS_DIR="$shared" launch S1 "$(hold s1)"
echo "version G" >code.txt
G commit -qam G
sha_G=$(git rev-parse HEAD)
HPC_DIR="$T/cluster5" HPC_RUNS_DIR="$shared" launch S2 'true'
rc=$?
check "a live run of another copy sharing the runs dir does not block" '[[ $rc == 0 && $(git -C "$T/cluster5" rev-parse HEAD) == "$sha_G" ]]'
touch "$T/release-s1"

# A live run of cluster3 blocks moving cluster3, however the copy and the runs dir are named.
HPC_DIR="$T/cluster3" HPC_RUNS_DIR=results/a launch R1 "$(hold r1); cat code.txt > results/R1.txt"
echo "version H" >code.txt
G commit -qam H
HPC_DIR="$T/cluster3-link" HPC_RUNS_DIR=results/b launch R2 'true'
rc=$?
check "a live run blocks moving its copy reached by another path and runs dir" '[[ $rc != 0 ]] && grep -q "still running here" "$T/R2.launch"'
check "the refused launch left the copy on the live run's commit" '[[ $(git -C "$T/cluster3" rev-parse HEAD) == "$sha_G" ]]'
touch "$T/release-r1"
check "the live run read its own commit" '[[ $(wait_exit R1 "$T/cluster3/results/a") == 0 && $(cat "$T/cluster3/results/R1.txt") == "version G" ]]'

echo "---- $pass passed, $fail failed"
[[ $fail == 0 ]]

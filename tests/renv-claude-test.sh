#!/usr/bin/env bash
# Allow-all is gated on git, and the writable unit is everything git needs to
# write. `renv claude` hands Claude Code --permission-mode bypassPermissions only
# when the launch directory is a git worktree, and binds read-write both the repo
# toplevel and — for a linked worktree, where they differ — the common git dir in
# the main repo. Without either, the agent edits unprompted while git itself is
# read-only, which destroys the recoverability the bypass depends on.
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

bin="$tmp/bin"
config="$tmp/config"
mkdir -p "$bin" "$config" "$tmp/nohooks" "$tmp/untracked"
ln -s "$repo/.config/renv" "$config/renv"

# Fixture repo. Point it at an empty hooks dir so the shared agent-branch guard
# in ~/.config/git/hooks does not reject the fixture commit when this suite runs
# inside an agent session.
git init -q "$tmp/tracked"
git -C "$tmp/tracked" config core.hooksPath "$tmp/nohooks"
git -C "$tmp/tracked" -c user.email=t@example.invalid -c user.name=fixture \
	commit -q --allow-empty -m fixture
git -C "$tmp/tracked" worktree add -q "$tmp/linked"
mkdir -p "$tmp/tracked/sub"

# Resolve the way git will report them, so a symlinked TMPDIR can't skew this.
toplevel=$(git -C "$tmp/tracked" rev-parse --show-toplevel)
linked=$(git -C "$tmp/linked" rev-parse --show-toplevel)
common=$(cd "$(git -C "$tmp/linked" rev-parse --git-common-dir)" && pwd)

cat >"$bin/pass" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
[ "$1" = show ] && [ "$2" = asta-mcp ] || exit 1
printf '%s\n' test-asta-key
EOF

# Report the Headroom proxy as already up so the env file skips launching one.
cat >"$bin/curl" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF

cat >"$bin/sandbox" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf 'prefix=%s\n' "${AGENT_BRANCH_PREFIX:-}" >"$RENV_CAPTURE"
printf '%s\n' "$@" >>"$RENV_CAPTURE"
EOF

cat >"$bin/claude" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$bin/pass" "$bin/curl" "$bin/sandbox" "$bin/claude"

run() { # cwd -> captured invocation
	local capture="$tmp/capture"
	(
		cd "$1" || exit 1
		PATH="$bin:$PATH" \
			XDG_CONFIG_HOME="$config" \
			GIT_CEILING_DIRECTORIES="$tmp" \
			RENV_CAPTURE="$capture" \
			"$repo/.local/scripts/renv" claude --version
	)
	cat "$capture"
}

expect() { # label, actual, expected
	[ "$2" = "$3" ] || {
		printf 'unexpected renv claude invocation (%s):\n%s\n\nexpected:\n%s\n' \
			"$1" "$2" "$3" >&2
		exit 1
	}
}

confined() { # rw-paths... -> expected capture
	printf 'prefix=claude\n-p\nagent-claude\n'
	for path in "$@"; do printf -- '--rw\n%s\n' "$path"; done
	printf -- '--\n%s\n--permission-mode\nbypassPermissions\n--version\n' "$bin/claude"
}

# Repo root and subdirectory must bind the same toplevel, and only it: in a
# normal checkout the common git dir is already inside the toplevel.
expect 'repo root' "$(run "$toplevel")" "$(confined "$toplevel")"
expect 'repo subdirectory' "$(run "$toplevel/sub")" "$(confined "$toplevel")"

# A linked worktree needs the main repo's git dir bound too, or nothing commits.
expect 'linked worktree' "$(run "$linked")" "$(confined "$linked" "$common")"

expect 'non-git directory' "$(run "$tmp/untracked")" "$(
	printf 'prefix=claude\n-p\nagent-claude\n--\n%s\n--version\n' "$bin/claude"
)"

# A proxy that cannot start must stop the launch with its log named, not leave
# the harness pointed at a dead base URL to retry "Connection refused" ten times
# with nothing saying why. Worst case here is the whole readiness budget (~15s),
# if bash has not yet reaped the exited stub; a prompt failure is the liveness
# check working.
dead="$tmp/deadbin"
mkdir -p "$dead" "$tmp/hrstate"

cat >"$dead/curl" <<'EOF'
#!/usr/bin/env bash
exit 7
EOF

cat >"$dead/headroom" <<'EOF'
#!/usr/bin/env bash
printf 'error: --a-flag is not available in the current rollout channel\n' >&2
exit 2
EOF
chmod +x "$dead/curl" "$dead/headroom"

capture="$tmp/capture"
rm -f "$capture"
status=0
stderr=$(
	cd "$tmp/untracked" || exit 1
	PATH="$dead:$bin:$PATH" \
		XDG_CONFIG_HOME="$config" \
		GIT_CEILING_DIRECTORIES="$tmp" \
		RENV_CAPTURE="$capture" \
		HEADROOM_PORT=1 \
		HEADROOM_WORKSPACE_DIR="$tmp/hrstate" \
		"$repo/.local/scripts/renv" claude --version 2>&1 >/dev/null
) || status=$?

[ "$status" -ne 0 ] || {
	printf 'a proxy that failed to start did not stop the launch\n' >&2
	exit 1
}

case "$stderr" in
*"$tmp/hrstate/proxy-1.log"*) ;;
*)
	printf 'launch failure did not name the proxy log:\n%s\n' "$stderr" >&2
	exit 1
	;;
esac

[ ! -e "$capture" ] || {
	printf 'claude was launched despite a proxy that never came up\n' >&2
	exit 1
}

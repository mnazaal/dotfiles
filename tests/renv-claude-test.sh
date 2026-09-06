#!/usr/bin/env bash
# The writable unit is everything git needs to write. `renv claude` binds
# read-write both the repo toplevel and — for a linked worktree, where they
# differ — the common git dir in the main repo. Without both, the agent edits
# files while git itself is read-only, so nothing it did can be reverted.
#
# The permission mode used to be decided here too, gated on being inside a
# worktree. It is settings.json's flat defaultMode now, so no argv carries it.
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


cat >"$bin/sandbox" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >"$RENV_CAPTURE"
EOF

cat >"$bin/claude" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
cp "$bin/claude" "$bin/claude-agent-acp"
chmod +x "$bin/pass" "$bin/sandbox" "$bin/claude" "$bin/claude-agent-acp"

run() { # cwd [harness] -> captured invocation
	local capture="$tmp/capture"
	(
		cd "$1" || exit 1
		PATH="$bin:$PATH" \
			XDG_CONFIG_HOME="$config" \
			GIT_CEILING_DIRECTORIES="$tmp" \
			RENV_CAPTURE="$capture" \
			"$repo/.local/scripts/renv" "${2:-claude}" --version
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
	printf -- '-p\nagent-claude\n'
	for path in "$@"; do printf -- '--rw\n%s\n' "$path"; done
	printf -- '--\n%s\n--settings\n{\"sandbox\":{\"enabled\":false}}\n--version\n' "$bin/claude"
}

# Repo root and subdirectory must bind the same toplevel, and only it: in a
# normal checkout the common git dir is already inside the toplevel.
expect 'repo root' "$(run "$toplevel")" "$(confined "$toplevel")"
expect 'repo subdirectory' "$(run "$toplevel/sub")" "$(confined "$toplevel")"

# A linked worktree needs the main repo's git dir bound too, or nothing commits.
expect 'linked worktree' "$(run "$linked")" "$(confined "$linked" "$common")"

# The editor path drops --permission-mode (the adapter rejects it) but must KEEP
# the native-sandbox override: podman is its boundary too, and bwrap cannot nest
# inside podman. When both flags shared one array, a blanket `unset` took the
# override with it and every Bash call in an agent-shell session failed. The
# suite could not see that, because it only ever drove `renv claude`.
expect 'acp keeps the native-sandbox override' "$(run "$toplevel" claude-agent-acp)" "$(
	printf -- '-p\nagent-claude\n--rw\n%s\n--\n%s\n--settings\n{\"sandbox\":{\"enabled\":false}}\n--version\n' \
		"$toplevel" "$bin/claude-agent-acp"
)"

expect 'non-git directory' "$(run "$tmp/untracked")" "$(
	printf -- '-p\nagent-claude\n--\n%s\n--settings\n{\"sandbox\":{\"enabled\":false}}\n--version\n' "$bin/claude"
)"


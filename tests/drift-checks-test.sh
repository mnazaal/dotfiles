#!/usr/bin/env bash
# Each drift check must fail on a fixture drifted in exactly the way it guards,
# and pass on an undrifted copy. Every case below once passed while drifted:
# the machinery check grepped the whole profile instead of RO_LAST, the role
# renderer carried a hard-coded role list, and the pi-package check compared
# names but not pinned versions.
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

failed=0
fail() { # report and keep going, so one run lists every check that missed
	printf 'drift-checks: FAIL %s\n' "$1" >&2
	failed=1
}

fixture() { # name -> fresh copy of the files the drift checks read
	local dir="$tmp/$1" path
	mkdir -p "$dir"
	for path in Makefile .agents/render-agent-roles.py .agents/roles .agents/role-headers \
		.claude/agents .config/pi/agent/agents .agents/guardrails/sensitive-paths.json \
		.claude/settings.json .config/sandbox; do
		mkdir -p "$dir/$(dirname "$path")"
		cp -R "$repo/$path" "$dir/$path"
	done
	printf '%s\n' "$dir"
}

passes() { # label command...
	local label=$1
	shift
	"$@" >"$tmp/out" 2>&1 || {
		cat "$tmp/out" >&2
		fail "$label: failed on an undrifted fixture"
	}
	return 0
}

catches() { # label needle command... -> must fail and name the drift
	local label=$1 needle=$2
	shift 2
	if "$@" >"$tmp/out" 2>&1; then
		fail "$label: passed although drifted"
	elif ! grep -qF -- "$needle" "$tmp/out"; then
		cat "$tmp/out" >&2
		fail "$label: failed without naming $needle"
	fi
}

# --- machinery pins: only RO_LAST counts -----------------------------------
# shellcheck disable=SC2016 # the profile's own spelling, expanded only when sourced
pin='"$H/dotfiles/.config/systemd"'
# shellcheck disable=SC2088 # policy spelling the check prints, not for expansion
want='~/dotfiles/.config/systemd'
unpin() { # dir -> the pin is gone from RO_LAST
	grep -vxF "	$pin" "$1/.config/sandbox/machinery-ro.profile" >"$tmp/profile"
	cp "$tmp/profile" "$1/.config/sandbox/machinery-ro.profile"
}

dir=$(fixture ro-clean)
passes 'machinery-ro clean' make -s -C "$dir" check-machinery-ro-sync

dir=$(fixture ro-rw)
unpin "$dir"
printf 'RW+=(%s)\n' "$pin" >>"$dir/.config/sandbox/machinery-ro.profile"
catches 'machinery-ro pin moved to RW' "$want" \
	make -s -C "$dir" check-machinery-ro-sync

dir=$(fixture ro-comment)
unpin "$dir"
sed -i "s|^	\"\$H/dotfiles/.local/cron\"\$|& # was $pin|" "$dir/.config/sandbox/machinery-ro.profile"
grep -qF "# was $pin" "$dir/.config/sandbox/machinery-ro.profile" || fail 'ro-comment fixture not built'
catches 'machinery-ro pin left only in a comment' "$want" \
	make -s -C "$dir" check-machinery-ro-sync

dir=$(fixture ro-no-policy)
python3 -c 'import json, sys
p = json.load(open(sys.argv[1]))
p["machinery"] = [m for m in p["machinery"] if not m.startswith("~/dotfiles/")]
json.dump(p, open(sys.argv[1], "w"))' "$dir/.agents/guardrails/sensitive-paths.json"
catches 'machinery-ro policy lists no ~/dotfiles paths' 'lists no ~/dotfiles machinery paths' \
	make -s -C "$dir" check-machinery-ro-sync

# --- agent roles: the role set comes from the source tree ------------------
roles() { python3 "$1/.agents/render-agent-roles.py" "${@:2}"; }

dir=$(fixture roles-clean)
passes 'roles clean' roles "$dir" --check

dir=$(fixture roles-new)
printf 'New role body.\n' >"$dir/.agents/roles/new-role.md"
printf -- '---\nname: new-role\n---\n' >"$dir/.agents/role-headers/claude/new-role.md"
catches 'roles: new role never rendered' 'agent file drift: .claude/agents/new-role.md' roles "$dir" --check
roles "$dir" >/dev/null
[ -f "$dir/.claude/agents/new-role.md" ] || fail 'roles: render skipped the new role'
[ ! -e "$dir/.config/pi/agent/agents/new-role.md" ] || fail 'roles: rendered pi without a pi header'
passes 'roles: new role after render' roles "$dir" --check

dir=$(fixture roles-stale)
cp "$dir/.claude/agents/build.md" "$dir/.claude/agents/old-role.md"
catches 'roles: stale rendered file' '.claude/agents/old-role.md' roles "$dir" --check

dir=$(fixture roles-orphan-header)
printf -- '---\nname: orphan\n---\n' >"$dir/.agents/role-headers/pi/orphan.md"
catches 'roles: header without a body' 'orphan' roles "$dir" --check

dir=$(fixture roles-orphan-body)
printf 'Body nobody renders.\n' >"$dir/.agents/roles/orphan.md"
catches 'roles: body without a header' 'orphan' roles "$dir" --check

# --- pi packages: a pinned version must be the installed one ---------------
pkgs() { # dir packages-json -> runs the check against a fixture deployment
	local dir=$1
	mkdir -p "$dir/.config/pi/agent"
	printf '{"packages": %s}\n' "$2" >"$dir/.config/pi/agent/settings.json"
	PI_CODING_AGENT_DIR="$tmp/agent" make -s -C "$dir" check-pi-packages
}
for spec in plain:0.17.2 @scope/scoped:1.0.6; do
	mkdir -p "$tmp/agent/npm/node_modules/${spec%%:*}"
	printf '{"name": "%s", "version": "%s"}\n' "${spec%%:*}" "${spec#*:}" \
		>"$tmp/agent/npm/node_modules/${spec%%:*}/package.json"
done

dir=$(fixture pi-clean)
passes 'pi-packages clean' pkgs "$dir" '["npm:plain@0.17.2", "npm:@scope/scoped@1.0.6", "npm:plain", "npm:plain@^0.17.0"]'
dir=$(fixture pi-drift)
catches 'pi-packages pinned version drift' 'npm:plain@0.17.1 (installed: 0.17.2)' pkgs "$dir" '["npm:plain@0.17.1"]'
catches 'pi-packages scoped version drift' 'npm:@scope/scoped@1.0.5' \
	pkgs "$dir" '["npm:@scope/scoped@1.0.5"]'
# `make pi-packages` installs what the resolver lists, so drift must be listed.
# shellcheck disable=SC2016 # $$ is make's escape, expanded by make
missing=$(REPO="$dir" PI_CODING_AGENT_DIR="$tmp/agent" make -s -C "$dir" --eval 'list:
	@python3 -c "$$PI_PACKAGES_PY" missing' list)
[ "$missing" = 'npm:@scope/scoped@1.0.5' ] || fail "pi-packages: missing mode printed '$missing'"

[ "$failed" -eq 0 ] || exit 1
printf 'drift-checks: ok\n'

#!/usr/bin/env bash
# Skill receipts must survive across hook processes, at an exact path and JSON
# shape. Claude keys by sha256 of the transcript path and spawns a fresh hook
# process per tool call, so without persistence no gate would ever see a
# receipt.
#
# The failure this guards is silent and stricter, not looser: receipts that stop
# persisting do not open the guards, they turn every skill gate into a deny
# loop. Nothing else in the suite covers it.
set -euo pipefail

repo=$(CDPATH='' cd -- "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

state="$tmp/state"
transcript="$tmp/session.jsonl"

emit() { # harness-hook payload...
	printf '%s\n' "$2" | XDG_STATE_HOME="$state" bun "$repo/$1" >/dev/null
}

has_skill() { # file skill label
	grep -q "\"$2\"" "$1" || {
		printf '%s: receipt does not carry %s\n%s\n' "$3" "$2" "$(cat "$1")" >&2
		exit 1
	}
}

# --- claude: keyed by sha256 of the transcript path --------------------------
emit ".claude/hooks/guardrails.ts" \
	"$(printf '{"tool_name":"Skill","tool_input":{"name":"dev-git"},"cwd":"%s","transcript_path":"%s"}' "$repo" "$transcript")"

digest=$(printf '%s' "$transcript" | sha256sum | cut -d' ' -f1)
claude_file="$state/claude/guardrails/$digest.json"
[ -f "$claude_file" ] || {
	printf 'claude: no receipt at the transcript-keyed path %s\n' "$claude_file" >&2
	exit 1
}
has_skill "$claude_file" dev-git claude

# A later call in the same session accumulates rather than replacing.
emit ".claude/hooks/guardrails.ts" \
	"$(printf '{"tool_name":"Skill","tool_input":{"name":"dev-python"},"cwd":"%s","transcript_path":"%s"}' "$repo" "$transcript")"
has_skill "$claude_file" dev-git "claude after second call"
has_skill "$claude_file" dev-python "claude after second call"

# A different transcript is a different session and must not inherit receipts.
emit ".claude/hooks/guardrails.ts" \
	"$(printf '{"tool_name":"Skill","tool_input":{"name":"dev-viz"},"cwd":"%s","transcript_path":"%s"}' "$repo" "$tmp/other.jsonl")"
grep -q '"dev-viz"' "$claude_file" && {
	printf 'claude: a second session wrote into the first session receipt\n' >&2
	exit 1
}

# No transcript path means no persistence, and must not crash the hook.
emit ".claude/hooks/guardrails.ts" \
	"$(printf '{"tool_name":"Skill","tool_input":{"name":"dev-git"},"cwd":"%s"}' "$repo")"

printf 'guardrails skill state: all behaviors pass\n'

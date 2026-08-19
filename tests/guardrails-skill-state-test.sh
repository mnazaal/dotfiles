#!/usr/bin/env bash
# Skill receipts must survive across hook processes, at an exact path and JSON
# shape, for both harnesses that persist them. Claude keys by sha256 of the
# transcript path, Codex by the raw session id; Codex is a fresh process per
# tool call, so without persistence no gate would ever see a receipt.
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
session="test-session-1234"

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

# --- codex: keyed by the raw session id --------------------------------------
emit ".config/codex/hooks/guardrails.ts" \
	"$(printf '{"session_id":"%s","hook_event_name":"PreToolUse","tool_name":"Skill","tool_input":{"name":"dev-git"},"cwd":"%s"}' "$session" "$repo")"

codex_file="$state/codex/guardrails/$session.json"
[ -f "$codex_file" ] || {
	printf 'codex: no receipt at the session-keyed path %s\n' "$codex_file" >&2
	exit 1
}
has_skill "$codex_file" dev-git codex

emit ".config/codex/hooks/guardrails.ts" \
	"$(printf '{"session_id":"%s","hook_event_name":"PreToolUse","tool_name":"Skill","tool_input":{"name":"dev-hpc"},"cwd":"%s"}' "$session" "$repo")"
has_skill "$codex_file" dev-git "codex after second call"
has_skill "$codex_file" dev-hpc "codex after second call"

printf 'guardrails skill state: all behaviors pass\n'

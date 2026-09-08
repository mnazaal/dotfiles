#!/usr/bin/env bash
# Firing audit for personal agent skills. See SKILL.md "Firing Audit" for how to
# read the output — this script only produces the numbers.
#
# Lives in a file rather than in SKILL.md prose because skill text can reach the
# agent compressed, and compression drops command names and pipes: the original
# inline version of the counts query lost `grep`, `sed`, `sort`, `uniq` and every
# pipe, leaving something unrunnable that still looked plausible.
#
# Usage:
#   ./audit.sh [transcript-dir] [skills-dir]
#   ./audit.sh                      # defaults below
#   ./audit.sh ~/.config/foo/logs   # another harness's transcripts
#
# Assumes one session per transcript file, and that each skill load appears in
# the text as "skill":"<name>". Adjust MARKER if the harness records it
# differently — that is the only harness-specific assumption here.
#
# Sections 1-5 are grep/awk over the raw text and need nothing installed.
# Sections 6-8 read per-record JSON, so they need python3; without it they say
# so and are skipped, rather than reporting zero as though it were a result.

set -uo pipefail

# Where a harness keeps its session transcripts. Add yours here; this list is the
# only place a harness is named, and the first existing entry wins. Override with
# argument 1 or AGENT_TRANSCRIPT_DIR to avoid touching this file at all.
CANDIDATE_DIRS=(
	"$HOME/.claude/projects"
	"$HOME/.config/agent/sessions"
)

# Default is the deployed Claude skills path. If the skills dir is missing,
# sections 2 and 3 emit `ls: cannot access` and report every skill as "fired
# but no directory" — a broken audit that still prints plausibly (observed
# 2026-08-18 when the previous ~/.agents/skills default was transiently absent;
# both paths resolve to the repo tree when deployed).
SKILLS="${2:-$HOME/.claude/skills}"
MARKER='"skill":"[a-zA-Z0-9_-]*"'

TRANSCRIPTS="${1:-${AGENT_TRANSCRIPT_DIR:-}}"
if [ -z "$TRANSCRIPTS" ]; then
	for d in "${CANDIDATE_DIRS[@]}"; do
		[ -d "$d" ] && {
			TRANSCRIPTS="$d"
			break
		}
	done
fi

if [ -z "$TRANSCRIPTS" ] || [ ! -d "$TRANSCRIPTS" ]; then
	echo "no transcript directory found${TRANSCRIPTS:+ at $TRANSCRIPTS}" >&2
	echo "tried: ${CANDIDATE_DIRS[*]}" >&2
	echo "pass one explicitly: ./audit.sh <transcript-dir> [skills-dir]" >&2
	exit 1
fi

echo "transcripts: $TRANSCRIPTS"
echo "skills:      $SKILLS"

echo
echo "=== 1. counts per skill (how often each fired) ==="
grep -rho "$MARKER" --include="*.jsonl" "$TRANSCRIPTS" |
	sed 's/.*://;s/"//g' | sort | uniq -c | sort -rn

echo
echo "=== 2. never fired (exists but zero loads) ==="
# Weight by age before concluding: a skill added last week cannot have fired yet.
comm -23 \
	<(ls -1 "$SKILLS" | sort) \
	<(grep -rho "$MARKER" --include="*.jsonl" "$TRANSCRIPTS" | sed 's/.*://;s/"//g' | sort -u)

echo
echo "=== 3. fired but no skill directory (built-ins, or renamed/removed) ==="
comm -13 \
	<(ls -1 "$SKILLS" | sort) \
	<(grep -rho "$MARKER" --include="*.jsonl" "$TRANSCRIPTS" | sed 's/.*://;s/"//g' | sort -u)

echo
echo "=== 4. gate compliance ==="
echo "sessions where an event actually occurred vs. those that also loaded the"
echo "gating skill. edit the pairs below to match the gates you want to check."
# Anchor each pattern to the tool call that PERFORMED the event ("command":"…git
# commit, "url":"…arxiv.org), never a bare string. Every skill description sits
# in the system prompt, so a bare match counts every session that merely mentions
# the event: 'git worktree' matches 557 of 588 sessions as text and 10 as a real
# command. An unanchored denominator does not understate compliance, it reports
# a number with no meaning.
# A subagent transcript is not a session. A delegate legitimately does not load
# the parent's gating skills, so counting subagents/*.jsonl inflates every
# denominator: measured 2026-08-23, session-handoff read 57% with them and 77%
# without, and the difference was 53 delegate transcripts.
gate_sessions() {
	grep -rlE "$1" --include="*.jsonl" "$TRANSCRIPTS" 2>/dev/null | grep -v '/subagents/'
}

check_gate() {
	local label="$1" pattern="$2" skill="$3" total with files
	files=$(gate_sessions "$pattern")
	total=$(printf '%s' "$files" | grep -c .)
	if [ "$total" -eq 0 ]; then
		printf "  %-22s %-24s no sessions with this event\n" "$label" "$skill"
		return
	fi
	with=$(printf '%s\n' "$files" | xargs grep -l "\"skill\":\"$skill\"" 2>/dev/null | wc -l)
	printf "  %-22s %-24s %4d/%-4d  %3d%%\n" "$label" "$skill" "$with" "$total" \
		"$((100 * with / total))"
}
printf "  %-22s %-24s %-10s %s\n" "EVENT" "GATING SKILL" "LOADED" "RATE"
check_gate 'git commit' '"command":"[^"]*git commit' dev-git
check_gate 'git push' '"command":"[^"]*git push' dev-git
check_gate 'git rebase' '"command":"[^"]*git rebase' dev-git-rescue
# `git worktree add` creates one; `git worktree list` is a read-only probe and
# is not the event dev-worktree exists for. Anchoring on the bare subcommand
# reported 2/9 = 22% for a skill sitting at 54 recorded loads — a number with no
# meaning. Anchor on the tool call that PERFORMS the event, not the topic.
check_gate 'git worktree add' '"command":"[^"]*git worktree add' dev-worktree
check_gate 'arxiv fetch' '"name":"WebFetch","input":\{"url":"[^"]*arxiv\.org' research-protocol
check_gate 'handoff written' 'session-handoff:begin' session-handoff
check_gate 'structured question' '"name":"AskUserQuestion"' plan-interview
check_gate 'subagent spawn' '"name":"(Task|Agent)","input"' agent-orchestration
# Approximates the gate: `capabilitiesOf` fires when a whitespace-delimited
# token's BASENAME equals a runner, so the anchor needs the same boundaries or
# it counts `cat pytest.log` and `rm -rf .pytest_cache` as test runs. Measured
# 2026-08-23: the unbounded form selected 124 sessions against 118 here, a
# one-way inflation that understates compliance. Still an approximation — the
# gate tokenizes, this greps — so read it as a floor. Gated 2026-08-23;
# sessions before that date measure the ungated baseline.
check_gate 'test run' '"command":"([^"]*[ /])?(pytest|unittest|vitest|jest|mocha|rspec)([ \\"]|$)' dev-verification

echo
echo "=== 5. where in the session each skill fires ==="
echo "median position, and the early/late split. Early is resume-shaped, late is"
echo "write-shaped; a two-directional skill working in only one direction shows"
echo "up here and nowhere else."
for skill in $(grep -rho "$MARKER" --include="*.jsonl" "$TRANSCRIPTS" |
	sed 's/.*://;s/"//g' | sort -u); do
	grep -rl "\"skill\":\"$skill\"" --include="*.jsonl" "$TRANSCRIPTS" 2>/dev/null |
		while read -r f; do
			tot=$(wc -l <"$f")
			[ "$tot" -gt 0 ] || continue
			ln=$(grep -n "\"skill\":\"$skill\"" "$f" | head -1 | cut -d: -f1)
			echo $((100 * ln / tot))
		done |
		sort -n |
		awk -v s="$skill" 'NR>0{a[NR]=$1}
        END {
          if (NR == 0) exit
          early = late = 0
          for (i = 1; i <= NR; i++) { if (a[i] < 30) early++; if (a[i] > 70) late++ }
          printf "  %-30s n=%-4d median=%3d%%  early=%3d%%  late=%3d%%\n",
                 s, NR, a[int((NR+1)/2)], 100*early/NR, 100*late/NR
        }'
done

if ! command -v python3 >/dev/null 2>&1; then
	echo
	echo "sections 6-8 skipped: python3 not installed (they parse per-record JSON)"
	exit 0
fi

echo
python3 - "$TRANSCRIPTS" <<'PYCOST'
import json, os, sys, collections

root = sys.argv[1]
files = [os.path.join(d, f) for d, _, fs in os.walk(root)
         for f in fs if f.endswith(".jsonl")]

# The harness writes a cost-state record REPEATEDLY within one session (up to 19
# observed in a single file), each a running total. Summing them multiplies the
# spend; the last one per file is the session's figure.
total = 0.0
by_project = collections.Counter()
by_model = collections.Counter()
per_file = []
covered = 0
for f in files:
    last = None
    for line in open(f, encoding="utf-8", errors="replace"):
        if '"cost-state"' not in line:
            continue
        try:
            r = json.loads(line)
        except ValueError:
            continue
        if r.get("type") == "cost-state":
            last = r
    if last is None:
        continue
    covered += 1
    usd = last.get("totalCostUSD") or 0.0
    total += usd
    by_project[os.path.basename(os.path.dirname(f))] += usd
    for model, u in (last.get("modelUsage") or {}).items():
        by_model[model] += u.get("costUSD") or 0.0
    per_file.append((usd, f))

print("=== 6. cost ===")
print("Read from the harness's own cost-state record, so no price table is kept")
print("here and none can go stale. Coverage is partial by version: a transcript")
print("written before the harness emitted the record contributes nothing, and")
print("that is a gap in the series, not a cheap session.")
if not files:
    print("  no transcripts found")
elif not covered:
    print("  no cost-state records found in %d transcripts" % len(files))
else:
    print("  coverage: %d of %d transcripts carry the record" % (covered, len(files)))
    print("  total (sum of per-session last records): $%.2f" % total)
    print("  by model:")
    for m, v in by_model.most_common():
        print("    %-40s $%.2f" % (m, v))
    print("  top projects:")
    for pr, v in by_project.most_common(10):
        print("    %-40s $%.2f" % (pr, v))
    print("  most expensive sessions (open the path to see what happened):")
    for usd, f in sorted(per_file, reverse=True)[:10]:
        print("    $%-9.2f %s" % (usd, f))
PYCOST

echo
python3 - "$TRANSCRIPTS" <<'PYPROMPT'
import json, os, sys

root = sys.argv[1]
# A subagent transcript's "user" message is the PARENT agent's task description,
# not the user's -- counting those measures how this agent writes briefs to
# itself. Section 4 excludes them for the same reason.
files = [os.path.join(d, f) for d, _, fs in os.walk(root)
         for f in fs if f.endswith(".jsonl") and "/subagents/" not in os.path.join(d, f)]

# A "user" row is only a real prompt when it carries no tool result. Even then
# the harness injects its own text through the same channel -- slash-command
# envelopes, skill bodies, system reminders -- so without these filters the
# corpus is mostly machine writing and the themes read as the agent's, not the
# user's. Long entries are pasted context rather than prompting, and they
# dominate any frequency reading, so they are dropped too.
#
# The shell-prompt glyph earns its place in this list the hard way: a `!`-run
# command pastes its own OUTPUT back as a user message, under the length cap and
# carrying no marker. Before this filter the forty most recent "prompts" were
# almost entirely command output, which reads as a corpus and is not one.
INJECTED = ("<command-message>", "<command-name>", "<system-reminder>",
            "<local-command-stdout>", "Base directory for this skill:",
            "Caveat: The messages below were generated")
PASTED_OUTPUT_PREFIXES = ("\u276f", "$ ", "# ")
MAXLEN = 2000

rows = []
for f in files:
    try:
        mtime = os.path.getmtime(f)
    except OSError:
        continue
    for line in open(f, encoding="utf-8", errors="replace"):
        if '"user"' not in line:
            continue
        try:
            r = json.loads(line)
        except ValueError:
            continue
        if r.get("type") != "user" or "toolUseResult" in r:
            continue
        content = (r.get("message") or {}).get("content")
        texts = []
        if isinstance(content, str):
            texts = [content]
        elif isinstance(content, list):
            texts = [b.get("text", "") for b in content
                     if isinstance(b, dict) and b.get("type") == "text"]
        for t in texts:
            t = t.strip()
            if not t or len(t) > MAXLEN:
                continue
            if any(m in t for m in INJECTED):
                continue
            if t.startswith(PASTED_OUTPUT_PREFIXES):
                continue
            rows.append((mtime, " ".join(t.split()), f))

print("=== 7. what you actually asked for ===")
print("Sections 1-5 measure whether an existing skill fired. This measures the")
print("other direction: what keeps getting asked that NO skill covers, which is")
print("where a new skill comes from. Read it for repeats, not for any one line.")
if not rows:
    print("  no user prompts found after filtering")
else:
    print("  %d prompts after dropping injected text and anything over %d chars"
          % (len(rows), MAXLEN))
    print("  most recent 40:")
    rows.sort(reverse=True)
    for _, text, f in rows[:40]:
        print("    %s" % text[:150])
PYPROMPT

echo
python3 - "$TRANSCRIPTS" <<'PYERR'
import json, os, sys

root = sys.argv[1]
files = [os.path.join(d, f) for d, _, fs in os.walk(root)
         for f in fs if f.endswith(".jsonl")]

per_file = []
tool_total = err_total = 0
for f in files:
    errs = tools = 0
    for line in open(f, encoding="utf-8", errors="replace"):
        if "toolUseResult" not in line:
            continue
        try:
            r = json.loads(line)
        except ValueError:
            continue
        tr = r.get("toolUseResult")
        if tr is None:
            continue
        tools += 1
        if (isinstance(tr, dict) and tr.get("is_error")) or \
           (isinstance(tr, str) and tr.startswith("Error")):
            errs += 1
    tool_total += tools
    err_total += errs
    if errs:
        per_file.append((errs, tools, f))

print("=== 8. where the agent struggled ===")
print("A failed tool call is not itself a problem -- probing is how work gets")
print("done. A session with a high RATE is the signal: it usually means a guard")
print("firing on routine work, or a tool being driven from a wrong assumption.")
if not tool_total:
    print("  no tool results found")
else:
    print("  %d of %d tool results errored (%.1f%%) across %d transcripts"
          % (err_total, tool_total, 100.0 * err_total / tool_total, len(files)))
    print("  worst sessions by rate, minimum 20 tool calls:")
    ranked = [(e / t, e, t, f) for e, t, f in per_file if t >= 20]
    for rate, e, t, f in sorted(ranked, reverse=True)[:15]:
        print("    %5.1f%%  %3d/%-4d  %s" % (100 * rate, e, t, f))
PYERR

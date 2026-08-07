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

set -uo pipefail

# Where a harness keeps its session transcripts. Add yours here; this list is the
# only place a harness is named, and the first existing entry wins. Override with
# argument 1 or AGENT_TRANSCRIPT_DIR to avoid touching this file at all.
CANDIDATE_DIRS=(
  "$HOME/.claude/projects"
  "$HOME/.local/share/opencode/storage"
  "$HOME/.config/agent/sessions"
)

SKILLS="${2:-$HOME/.agents/skills}"
MARKER='"skill":"[a-zA-Z0-9_-]*"'

TRANSCRIPTS="${1:-${AGENT_TRANSCRIPT_DIR:-}}"
if [ -z "$TRANSCRIPTS" ]; then
  for d in "${CANDIDATE_DIRS[@]}"; do
    [ -d "$d" ] && { TRANSCRIPTS="$d"; break; }
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
grep -rho "$MARKER" --include="*.jsonl" "$TRANSCRIPTS" \
  | sed 's/.*://;s/"//g' | sort | uniq -c | sort -rn

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
echo "sessions containing an event vs. those that also loaded the gating skill."
echo "edit the pairs below to match the gates you want to check."
check_gate() {
  local event="$1" skill="$2" total with
  total=$(grep -rl "$event" --include="*.jsonl" "$TRANSCRIPTS" 2>/dev/null | wc -l)
  if [ "$total" -eq 0 ]; then
    printf "  %-22s %-24s no sessions with this event\n" "$event" "$skill"
    return
  fi
  with=$(grep -rl "$event" --include="*.jsonl" "$TRANSCRIPTS" 2>/dev/null \
    | xargs grep -l "\"skill\":\"$skill\"" 2>/dev/null | wc -l)
  printf "  %-22s %-24s %4d/%-4d  %3d%%\n" "$event" "$skill" "$with" "$total" \
    "$((100 * with / total))"
}
printf "  %-22s %-24s %-10s %s\n" "EVENT" "GATING SKILL" "LOADED" "RATE"
check_gate 'git commit'           dev-git
check_gate 'session-handoff:begin' session-handoff

echo
echo "=== 5. where in the session each skill fires ==="
echo "median position, and the early/late split. Early is resume-shaped, late is"
echo "write-shaped; a two-directional skill working in only one direction shows"
echo "up here and nowhere else."
for skill in $(grep -rho "$MARKER" --include="*.jsonl" "$TRANSCRIPTS" \
                 | sed 's/.*://;s/"//g' | sort -u); do
  grep -rl "\"skill\":\"$skill\"" --include="*.jsonl" "$TRANSCRIPTS" 2>/dev/null \
    | while read -r f; do
        tot=$(wc -l < "$f")
        [ "$tot" -gt 0 ] || continue
        ln=$(grep -n "\"skill\":\"$skill\"" "$f" | head -1 | cut -d: -f1)
        echo $((100 * ln / tot))
      done \
    | sort -n \
    | awk -v s="$skill" 'NR>0{a[NR]=$1}
        END {
          if (NR == 0) exit
          early = late = 0
          for (i = 1; i <= NR; i++) { if (a[i] < 30) early++; if (a[i] > 70) late++ }
          printf "  %-30s n=%-4d median=%3d%%  early=%3d%%  late=%3d%%\n",
                 s, NR, a[int((NR+1)/2)], 100*early/NR, 100*late/NR
        }'
done

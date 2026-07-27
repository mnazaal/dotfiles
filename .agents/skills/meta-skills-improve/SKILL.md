---
name: meta-skills-improve
description: Use after long agent sessions or repeated workflow friction to improve personal agent skills: extract reusable procedures, update routing, clarify rules, remove contradictions, and draft safe changes for ~/.agents/skills.
---

# Skill: Meta Skills Improve

## Purpose

Turn lessons from real agent sessions into better personal skills.

Use when a session reveals a reusable workflow, repeated mistake, missing routing rule, unclear boundary, weak verification step, or behavior that should be captured in `~/.agents/skills`.

## Rules

- Prefer updating an existing skill over creating a new one.
- Create a new skill only for a distinct trigger and repeatable workflow.
- Keep skills short, operational, and action-oriented.
- Prefer sharper gates over longer prose.
- Test each new line with the no-op test: does it change behavior versus the model's default? If not, cut the whole sentence, not just trim it.
- When collapsing duplication, prefer one strong term reused in body and description (a leading word) over deleting the extra copy and leaving the idea unanchored.
- Whenever editing a skill, scan its existing body for sediment — content that no longer reflects current behavior — and propose removing it alongside the new addition.
- Audit firing, not just content — see Firing Audit below. Reading a skill tells you whether it is good; only the transcripts tell you whether it runs.
- Fit additions into a skill's existing headings; add a new heading only for a genuinely distinct concern.
- Do not encode one-off session details.
- Do not duplicate global instructions unless the skill needs a local reminder.
- Do not conflict with higher-priority system, developer, or global instructions.
- Preserve safety, verification, citation, read/write, and protected-storage policies.
- Ask before editing skill files unless the user explicitly requested edits.

## Firing Audit

The highest-value input to this skill, and the one reading can never supply.
Run it before a round of edits, and again weeks later to see whether the edits
changed anything. Claude Code records each load as `"skill":"<name>"` inside a
Skill tool_use block in `~/.claude/projects/*/*.jsonl`.

- **Counts per skill.** `grep -rho '"skill":"[a-zA-Z0-9_-]*"' --include="*.jsonl"
  ~/.claude/projects | sed 's/.*://;s/"//g' | sort | uniq -c | sort -rn`.
  Diff against the skills directory for the never-fired list, and weight by each
  skill's age — one added last week cannot have fired yet.
- **Gate compliance.** For a skill that should fire on an event, count the
  sessions containing that event (a transcript whose text contains `git commit`,
  say) and how many of those also loaded the skill. A rule declared mandatory
  but sitting at low compliance needs a hook, not more prose.
- **Where in the session it fired.** A call's line number over the file's total
  line count separates an early, resume-shaped invocation from a late,
  write-shaped one. This is how a two-directional skill that only works in one
  direction shows up.

Read the output as three different diagnoses, not one:

1. **Never fires** — wrong trigger words, or the skill is genuinely unwanted.
   Only this one is fixed by editing a description.
2. **Fires, but too late to matter** — the trigger describes the aftermath
   rather than the moment the advice would have changed something.
3. **Fires, but the result is not what the user wanted** — the trigger is fine
   and the content is wrong. Counts alone will never reveal this; it surfaces
   when the user complains despite healthy usage.

A skill at zero after real exposure is evidence to cut, not a prompt to
advertise it harder (`dev-ponytail`). Retire it and fold anything durable into
a skill that does fire.

## Workflow

1. Capture the reusable lesson from the session.
2. Separate general workflow from one-off project context.
3. Inspect relevant skills in `~/.agents/skills`.
4. Choose the narrowest existing skill that fits, or justify a new skill.
5. Check invocation, distinct triggers, completion criteria, duplication, no-op advice, routing conflicts, related-skill overlap, and sediment in the target skill's existing content.
6. Draft minimal markdown changes in the existing skill style.
7. Present affected files, proposed patch, risks, and recommendation.
8. Apply only with explicit user approval.

## Output Shape

- Session lesson.
- Target skill changes.
- Proposed patch.
- Routing / conflict check.
- Recommendation: apply, revise, or skip.

## New Skill Criteria

Create a new skill only if:

- It has a clear trigger.
- It has a repeatable workflow.
- It does not mostly duplicate an existing skill.
- It would be used often enough to matter.
- It can route cleanly to related skills.
- Keep every skill callable and auto-routable in the active platform; put platform-specific invocation flags in the platform configuration skill rather than general skill prose.

## Anti-Patterns

- Creating a new skill for every session.
- Adding generic advice like “be careful” or “think deeply.”
- Making skills too long to follow.
- Letting sediment accumulate: only ever adding, never checking existing content for staleness.
- Adding a new heading for content that belongs under an existing one.
- Encoding current project facts into personal skills.
- Bypassing mandatory research, verification, or storage policies.
- Editing dotfiles without explicit permission.

## Related Skills

- `dev-scout` for read-only exploration before proposing changes.
- `dev-verification` before claiming skill updates are correct.
- `debug-root-cause` when repeated agent failure needs diagnosis.
- `decide-priority` when choosing which skill improvements matter.
- `context-org` when lessons come from notes or protected stores.

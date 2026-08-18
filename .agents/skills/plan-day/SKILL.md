---
name: plan-day
description: Use for good morning, start my day, plan my day, daily briefing, or what should I do next today using Org agenda and Emacs TODO context.
---

# Skill: Plan Day

## Purpose

Start the day by turning Org agenda and Emacs TODO context into a small, realistic plan.

Use when the user wants a morning brief, daily startup, daily plan, or next-action recommendation for today.

## Rules

- Use `context-org` for the store layout and the read-only policy. Never write
  to `~/org`; propose changes as snippets the user yanks into Emacs.
- **Read the undated backlog, not just the agenda.** The agenda is a date view,
  so it shows commitments and hides everything captured without a `SCHEDULED`.
  Read `agenda/inbox.org` and `agenda/backlog.org` directly — those items are
  invisible in the agenda and are the ones that rot.
- Read the generated calendars (`primary-gcal.org`, `aalto-outlook.org`) for
  fixed commitments; they are the reliable half of the store.
- Treat scheduled items, deadlines, and meetings as constraints, not
  automatically as highest priority.
- Distinguish fixed commitments from optional work.
- Prefer a small daily plan: 1–3 must-do items plus a short backup list.
- Do not mutate Org files, reschedule tasks, mark TODOs done, or create daily
  notes.
- Ask only for missing context that materially changes today's plan.
- When the brief runs on a schedule rather than by request: key it to the
  intended calendar date, not the run time; after a gap produce one current
  brief, never one per missed day; skip if today's brief artifact already
  exists; and record a skipped or caught-up day in the brief itself rather
  than staying silent about it.

## Workflow

1. Identify today's date, day phase, and available work window.
2. Read today's fixed commitments from the generated calendars.
3. Read the undated backlog (`inbox.org`, `backlog.org`) — anything with no
   `SCHEDULED` or `DEADLINE`, plus how long it has sat there. Age is the signal:
   a captured item nobody dated is one nobody decided about.
4. Separate fixed commitments from candidate tasks; find conflicts and overload.
5. Use `decide-priority` when ranking candidates requires explicit tradeoffs.
6. Produce the brief, and close the loop: emit the proposed dates as an org
   snippet the user can yank. Read-only means the processing step depends on
   them acting, so make acting a paste rather than a re-derivation.
7. Route into the relevant execution skill only after the user confirms.

## Output Shape

```markdown
## Morning Brief

### Agenda / Fixed Commitments
- ...

### Must Do Today
1. ...
2. ...
3. ...

### Good Next Tasks
- ...

### Stale Captures (undated, invisible to the agenda)
- <item> — captured <date>, <n> days undated

### Risks / Conflicts
- ...

### Recommended First Action
...

### Proposed Dates — yank into Emacs
```org
SCHEDULED: <YYYY-MM-DD day>
```

### If Low Energy
...

### If Deep Work Window
...
```

## Routing

- Use `context-org` for Org agenda, TODOs, notes, storage policy, and write safety.
- Use `decide-priority` when choosing among competing tasks or tradeoffs.
- Use `plan-interview` when today's constraints or goals are too ambiguous to plan directly.
- Use `research-protocol` before academic-paper, literature, citation, related-work, bibliography, author-lookup, or field-survey content.
- Use `research-run` when today's next action is experiment/log/result follow-up.
- Use `dev-*` or `debug-*` only after a concrete software task or bug is selected.
- Use `dev-verification` when checking whether a claimed status is actually complete.

## Anti-Patterns

- Dumping every TODO instead of selecting a realistic day plan.
- Asking the user what is on the agenda before inspecting available Org context.
- Treating due dates as the only priority signal.
- Editing Org state during the morning brief without explicit permission.
- Starting implementation before the day plan is confirmed.

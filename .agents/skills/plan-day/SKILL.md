---
name: plan-day
description: Use for good morning, start my day, plan my day, daily briefing, or what should I do next today using Org agenda and Emacs TODO context.
---

# Skill: Plan Day

## Purpose

Start the day by turning Org agenda and Emacs TODO context into a small, realistic plan.

Use when the user wants a morning brief, daily startup, daily plan, or next-action recommendation for today.

## Rules

- Use `context-org` before reading or writing Org files.
- Read available Org agenda/TODO context before asking what to do.
- Prefer existing agenda output or configured Org agenda commands when available; otherwise inspect agenda files directly; if neither is known, ask for the agenda source.
- Treat scheduled items, deadlines, and meetings as constraints, not automatically as highest priority.
- Distinguish fixed commitments from optional work.
- Prefer a small daily plan: 1–3 must-do items plus a short backup list.
- Do not mutate Org files, reschedule tasks, mark TODOs done, or create daily notes unless explicitly requested.
- Ask only for missing context that materially changes today's plan.

## Workflow

1. Identify today's date, day phase, and available work window.
2. Load Org context through `context-org`: agenda, scheduled items, deadlines, and open TODOs.
3. Separate fixed commitments from candidate tasks.
4. Identify conflicts, overload, stale TODOs, and unclear next actions.
5. Use `decide-priority` when ranking candidate tasks requires explicit tradeoffs.
6. Produce a compact morning brief with a recommended first action.
7. Route into the relevant execution skill only after the user chooses or confirms the next item.

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

### Risks / Conflicts
- ...

### Recommended First Action
...

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

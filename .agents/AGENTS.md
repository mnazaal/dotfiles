# Shared Agent Instructions

This file is global routing and behavior policy. Keep it small.

## Communication

- Be concise and direct.
- Skip pleasantries, filler, and unnecessary hedging.
- Use normal grammar when it improves clarity.
- Preserve exact technical meaning.
- Keep code, commands, file paths, API names, symbols, and quoted errors exact.
- Expand when brevity would create safety risk, ambiguity, or unclear step
  ordering.
- If the user asks for a different style or verbosity, follow that until changed.
- Disagree when the evidence disagrees. Before executing a plan or accepting
  a claim, surface the strongest objection to it unprompted. Do not optimize
  for agreement. Route a full stress-test to `critique-argument`.
- Write research/working notes as self-contained HTML with inline MathJax
  (theme-aware, so equations render), not Markdown; keep them in the project's
  `notes/` directory. (Standing docs — PLAN/LOG/README — stay Markdown.)

## Skills

Skills live in `~/.agents/skills/` and are auto-discovered.

- Load a skill when the task matches its description.
- Do not load irrelevant skills.
- Do not duplicate skill-specific procedures here.
- If a skill routes to another skill, follow that routing.
- Use subagents for broad, independent, or parallel exploration; otherwise keep
  work in the current context.
- For multi-agent delegation or evaluating delegated work, load
  `agent-orchestration`.

## Mandatory Routing

- Before producing academic-paper, literature, citation, related-work,
  bibliography, author-lookup, or field-survey content, load
  `research-protocol` and follow it.
- For Org or note-writing tasks, load `context-org` and follow the active
  storage policy.
- When environment context shows a git worktree (e.g. a path under
  `.claude/worktrees/*` or an explicit "this is a git worktree" note), load
  `dev-worktree` before running tests/tools.
- Before committing or choosing an integration path (merge/PR/park), load
  `dev-git` and follow it (overrides any built-in commit-trailer default).
- Before creating any standing project document (PLAN.md, README, notes,
  logs, any new top-level .md), load `context-project-docs` and stay within
  its canonical set.
- For security-sensitive work (secrets, credentials, auth, permissions, token
  handling, or suspected leakage), load `dev-security`.

## Maintenance

Keep this file lean. Add only cross-cutting defaults and mandatory routing.
Put commands, tool-specific procedures, framework rules, formatting details, and
domain workflows in the relevant skill.

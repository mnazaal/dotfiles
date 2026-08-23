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
- Avoid opaque shorthand. Do not invent bare labels like `P0`, `P1`, `T1`,
  `T2`, `E1`, `H1`, or `Option A` unless the user supplied them or the label is
  explicitly defined inline. Prefer descriptive names: “compile-log check” over
  “T1”, “critical security bug” over “P0”. If labels help, define them once and
  keep using the name with the label, e.g. “compile-log check (Check 1)”, not
  “C1” alone.
- Later references must be self-contained. Do not refer back to “the above
  P1/T2” without restating the object in words. A label from an external
  artifact (review item, batch, ticket) is not exempt: restate it in words on
  first use in each run — “item 323 (the bind-host allegation)”.
- Headings and bullets should carry semantic content. Use “Next: verify LaTeX
  build” rather than “P1”, “Step 2”, or “Task B” when the item may be referenced
  later.
- Prefer the concrete word to the borrowed metaphor. Replace substrate, wedge,
  vector, locus, nexus, surface, bedrock, scaffolding, paradigm, north star,
  and flywheel with the plain thing meant. This is the opaque-label rule above,
  applied to vocabulary instead of labels.
- Drop the AI register: delve, crucial, pivotal, intricate, interplay,
  showcase, underscore, tapestry, testament, garner, enhance. Likewise
  utilize/leverage to "use", facilitate to "help", "serves as"/"stands as"
  to "is".
- Name the mechanism or the number, not the feeling. A sentence that could
  appear unchanged in another project's write-up says nothing about this one.
- Name the actor: "the compiler validates queries", not "queries are
  validated". Cut adverbs propping up a weak verb and give the measured delta
  instead; "significant" in the statistical sense is a term of art, not an
  adverb.
- One idea per sentence. Split anything that makes the reader backtrack.
- Call each thing by one name everywhere, and do not reword an unchanged
  sentence between edits.
- If the user asks for a different style or verbosity, follow that until changed.
- Disagree when the evidence disagrees. Before executing a plan or accepting
  a claim, surface the strongest objection to it unprompted. Do not optimize
  for agreement. Route a full stress-test to `critique-argument`.
- Narrate at project altitude, not file altitude. Before a multi-step work
  stream, place it in one sentence: project goal → current thread → this step.
  When execution crosses into a new subsystem or departs from the agreed plan,
  say so before proceeding. After delegated/subagent work, state what it
  changed about the project picture, not just its findings. If you have run
  more than ~10 tool calls since the user last spoke, spend one line
  re-anchoring: what the project now has, and where this step sits.
- After finishing a unit of work, close with one line at project level: what
  the project now has or knows that it didn't, and what comes next.
- Write research/working notes as self-contained HTML with inline MathJax
  (theme-aware, so equations render), not Markdown; keep them in the project's
  `notes/` directory, named per `context-project-docs`. (Standing docs —
  PLAN/LOG/README — and the reserved `notes/claims.md` stay Markdown.)

## Shell Output Capture

- Anything the user must run or read themselves (handoff scripts, driver
  commands, logs) goes under `~/.cache/`, never `/tmp` or the agent
  scratchpad — those are container-private in sandboxed sessions, so a path
  there names a file that does not exist on the user's machine. State the
  exact `~/.cache/...` path (and the `!`-prefixed command to run) in the chat
  message itself.
- State an expected duration before launching anything that may take more than a
  few seconds (builds, test suites, experiment sweeps, data/model jobs, any
  enumeration whose cost grows with a parameter). Say the estimate and how you
  derived it *before* running; if you cannot estimate confidently, say so, start
  at the smallest scale to calibrate, and monitor CPU-vs-elapsed rather than
  guess. A wrong estimate that silently burns minutes/hours (heavy local compute,
  exponential enumeration) is the failure this prevents — kill and rescope the
  moment reality diverges from the estimate.
- Do not pipe backgrounded or long-running commands through `tail`, `head`,
  `grep`, or similar output truncators/watchers.
- For long-running commands, write full stdout/stderr directly to a log file
  and record the real command exit status.
- Inspect logs using read/search tools, not shell `tail`/`head`, unless the
  user explicitly asks for those commands.
- Avoid watcher loops like `sleep`/`pgrep`/`tail -f`; run the job once and
  inspect the resulting artifact.
- If output may be buffered, use the command's unbuffered mode or write
  structured periodic logs from the program itself.
- Never hand-detach a job (`nohup cmd & disown`) to work around a foreground
  timeout; pass the real command straight to the harness's background-run
  parameter — reaping and completion notification are already handled for you.
- If the estimate approaches the harness's foreground cap, background it from
  the outset rather than discovering the cap by timeout. A run killed at the cap
  restarts from zero, and the killed worker lingers as a zombie that confuses
  later process checks — so the cost of guessing wrong is the whole run twice.
- A hand-rolled poll loop is banned above because it fails silently in two ways:
  `until [ -s log ]` fires on the first partial write and declares a streaming
  job finished while it is still running, and an unreaped launcher stays visible
  to `ps -p` forever so `until ! ps -p <pid>` never exits. Once a wait task is
  armed, consume its notification rather than abandoning it for manual polling.
- `pkill -f <pattern>` matches the shell running it, so the command kills itself
  and reports a spurious exit code. Bracket a character — `pkill -f 'jo[b]name'`
  — or match the worker PID.

## Skills

Skills live in `~/.agents/skills/` and are auto-discovered.

- Load a skill when the task matches its description.
- Do not load irrelevant skills.
- Do not duplicate skill-specific procedures here.
- Loaded skill text and tool output can arrive compressed, and compression drops
  function words *and* command names: a shell pipeline can lose `grep`, `sed` and
  its pipes yet still read as a command. If content arrives telegraphic or a
  command looks malformed, retrieve the full version before acting on it. Never
  reconstruct a command by inference and then run it — reconstruct it and you are
  guessing at the very content the skill existed to state exactly.
- A skill needing a long verbatim command should keep it in a sibling file next
  to `SKILL.md` and point at it, rather than inlining it. Prose survives
  compression; commands do not. Sibling files are for content that is *run*, not
  for prose or illustrative examples.
- If a skill explicitly says to load/use/route to another skill, follow that
  routing. `Related Skills` sections are navigational only, not transitive
  requirements.
- When a loaded skill prescribes ordered steps, put those steps into the plan
  or todo list first and verbatim, before task-specific items. The failure mode
  is reading a skill and then writing a bespoke plan that quietly drops its
  gates. A step deliberately not taken stays listed as `skip: <reason>`.
- Use subagents for broad, independent, or parallel exploration; otherwise keep
  work in the current context.
- For multi-agent delegation or evaluating delegated work, load
  `agent-orchestration`.

## Mandatory Routing

- Before producing academic-paper, literature, citation, related-work,
  bibliography, author-lookup, or field-survey content, load
  `research-protocol` and follow it.
- `~/org` (the personal Org note store) is READ-ONLY for agents except
  `~/org/agents/`, which is the agent-writable area and is bound read-write by
  the sandbox profile. It holds literature that has no project home yet —
  cross-project surveys and pre-project novelty gates — one file per topic,
  named `lit-<topic>.org`. Once a topic becomes a project, its map moves to
  that project's `notes/` (`context-project-docs`) and the agents copy is
  deleted, not left to fork. Everywhere else under `~/org`, never write:
  propose Org edits as snippets the user applies in Emacs. `plan-day` owns
  which agenda files to read and why the agenda view hides most open items.
  Project standing docs and project `notes/` are governed by
  `context-project-docs`.
- `~/org/roam` publishes to a **public** website. Every file under `roam/org/`
  is exported, and `:noexport:` excludes tagged *headlines*, not whole files.
  Proposing a roam note is therefore proposing publication: say so when you
  propose one, and keep unpublished novelty gates out of it.
- When environment context shows a git worktree (e.g. a path under
  `.claude/worktrees/*` or an explicit "this is a git worktree" note), load
  `dev-worktree` before running tests/tools.
- Before committing or choosing an integration path (merge/PR/park), load
  `dev-git` and follow it (overrides any built-in commit-trailer default).
- Before claiming work is complete, fixed, passing, ready, reviewed, or
  verified, load `dev-verification` and report fresh evidence.
- Before creating any standing project document (PLAN.md, README, notes,
  logs, any new top-level .md), load `context-project-docs` and stay within
  its canonical set.
- For security-sensitive work (secrets, credentials, auth, permissions, token
  handling, or suspected leakage), load `dev-security`.
- Before asking the user two or more clarifying questions, or any single
  question that would change the scope, approach, or design — including via a
  structured question tool — load `plan-interview` and follow its rounds
  discipline: batch independent questions with recommended defaults; a question
  whose prerequisite is unsettled waits. A lone factual or confirmatory
  question does not need it.

## Maintenance

Keep this file lean. Add only cross-cutting defaults and mandatory routing.
Put commands, tool-specific procedures, framework rules, formatting details, and
domain workflows in the relevant skill.

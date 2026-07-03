# Agent guardrails

Single source of truth for the bash/path guards shared by all three coding agents
(Claude Code, pi, opencode). Data is here; logic is here; each harness has a thin
adapter that wires its hook API to this core.

## Layout

- `sensitive-paths.json`    — protected path prefixes + per-agent `machinery_enabled`
- `dangerous-commands.json` — command-name sets + per-agent `find_policy`
- `skill-gates.json`        — tool events that require a skill loaded this session,
                              by `trigger` type: bash command+subcommands, a Write/Edit
                              path glob, or a WebFetch domain (e.g. `git commit` → `dev-git`)
- `core.ts`                 — the one implementation of the guard logic; no deps,
                              loads the JSONs, exports `createGuard(agent).evaluate()`,
                              `createSkillGate().requiredSkill()`, and `skillMentions()`

Adapters (thin, import `core.ts`):

| Agent    | Adapter                                        | Hook                          |
|----------|------------------------------------------------|-------------------------------|
| Claude   | `.claude/hooks/guardrails.ts`                  | bun CLI PreToolUse (settings.json) |
| pi       | `.config/pi/agent/extensions/guardrails.ts`    | `tool_call` extension         |
| opencode | `.config/opencode/plugins/guardrails.ts`       | `tool.execute.before` plugin  |

## Decisions

`evaluate()` returns `deny` (secrets / machinery / ref-rewrites), `ask`
(escalation / destructive / git-bypass / confinement / find), or `allow`. Adapters map:

- Claude → PreToolUse `permissionDecision` (deny / ask)
- pi → block (deny) / prompt then block-if-declined (ask)
- opencode → throw on any non-allow (a plugin can't prompt, so `ask` becomes a hard block)

The skill gate is separate from `evaluate()`: `requiredSkill({command,tool,path,url,cwd})`
maps one tool event to the skill it requires — a bash command, a Write/Edit path, or a
WebFetch URL, per the gate's `trigger` type. Each adapter supplies the session evidence
that the skill was loaded, since that is host-specific — Claude scans the transcript
(`skillMentions` over its text), pi/opencode accumulate `skillMentions` over tool payloads
in-process. A gate miss blocks with a "load the skill, then retry" message, so it
self-heals in one step. Gates fail open like everything else.

A gate's `message` names only the event that tripped it ("committing or pushing"), never
what the skill contains — the skill's purpose lives solely in its own description, so the
two never drift. The skill name comes from the gate's `skill` field; the adapter renders it.

### Skill-gate caveats (accepted trade-offs)

The gate is a **routing nudge against skill under-triggering, not a security
boundary** — the skills' own rules (staging ledger, trailers) protect
correctness; the gate only makes sure the model has read them. Every trade-off
below errs open, and the worst failure in any host is one false block that
self-heals via the retry message (cost: one tool call + a redundant skill read).

- **Evidence is a mention scan, not proof of reading.** Any payload/transcript
  text containing `skills/<name>/SKILL.md` or `"skill": "<name>"` counts as
  loaded — grepping the skills dir, editing a SKILL.md, or the string appearing
  in a user message all satisfy the gate without the model ingesting the rules.
- **pi/opencode assume skills load through a visible tool call.** If a host
  injects skills internally (no read/skill tool event), the first gated command
  false-blocks once, then the instructed SKILL.md read registers and the retry
  passes. Verify once per host that the block reason reaches the model and the
  loop closes; if a host swallows it, the gate degrades to a mysterious failure.
- **Session scope drifts in pi/opencode.** The loaded-skills set lives exactly
  as long as the extension/plugin process: a host reusing one process across
  sessions carries evidence over (errs open); a mid-session restart wipes it
  (one self-healing false block). Claude is immune — the transcript is the
  session and survives restarts.
- **Write/fetch gates match on the path/URL the tool reports.** A host that
  routes a file write or fetch through a differently-shaped tool payload (no
  `path`/`url` the adapter recognizes) simply fails open for that gate — the
  gate degrades per host rather than mis-firing.

## Toggles

- **`machinery_enabled`** (per agent) — also protect the guardrail/sandbox/renv
  files themselves from rewrite (the persistence-escape guard). Set an agent
  `false` while bootstrapping to avoid the PreToolUse self-lockout.
- **`find_policy`** (per agent) — `always` (gate any find) / `exec` (only when an
  `-exec`/`-delete` primary is present) / `off`.

## Editing

Add a path, a dangerous command, or a skill gate to the relevant JSON; all three
agents pick it up (Claude/opencode read live per call/startup, pi at extension
load). Keep `core.ts` dependency-free so every runtime can import it.

## Fail-open

If a JSON or `core.ts` can't load, the guards fail **open** (allow) with a loud
stderr line — these are defense-in-depth; the filesystem sandbox is the real
boundary. `dotfiles-doctor` checks the deployed guard so breakage isn't silent.

## Deploy

New files here must be stowed (`make link`) before the agents see them. Claude runs the
single `bun .claude/hooks/guardrails.ts` PreToolUse hook (the cutover from the legacy
python hooks is complete); pi/opencode import `core.ts` directly. Because the deployed
`core.ts`/JSONs are symlinks to this tree, edits here go live on the next tool call —
verify a `core.ts` change out of band (`bun` against fixtures) before relying on it.

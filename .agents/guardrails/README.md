# Agent guardrails

Single source of truth for the bash/path guards shared by coding agents
(Claude Code, Codex, pi, opencode). Data and logic is here; each harness has a thin
adapter that wires its hook API to this core.

## Layout

- `sensitive-paths.json`    - secret path prefixes + write-protected machinery paths
- `dangerous-commands.json` - command-name sets + per-agent `find_policy`
- `skill-gates.json`        - tool events that require a skill loaded this session,
                              by `trigger` type: bash command+subcommands, a Write/Edit
                              path glob, or a WebFetch domain (e.g. `git commit` → `dev-git`)
- `core.ts`                 - the one implementation of the guard logic; no deps,
                              loads the JSONs, exports `createGuardrails(agent).evaluate()`,
                              tool-event helpers, and `skillMentions()`

Adapters (thin, import `core.ts`):

| Agent    | Adapter                                     | Hook                               |
|----------|---------------------------------------------|------------------------------------|
| Claude   | `.claude/hooks/guardrails.ts`               | bun CLI PreToolUse (settings.json) |
| Codex    | `.config/codex/hooks/guardrails.ts`         | bun CLI hooks                      |
| pi       | `.config/pi/agent/extensions/guardrails.ts` | `tool_call` extension              |
| opencode | `.config/opencode/plugins/guardrails.ts`    | `tool.execute.before` plugin       |

## Decisions

`evaluate()` returns `deny` (secrets / machinery writes / ref-rewrites), `ask`
(escalation / destructive / git-bypass / confinement / find), or `allow`. 

Adapters map:
- Claude → PreToolUse `permissionDecision` (deny / ask)
- pi → block (deny) / prompt then block-if-declined (ask)
- opencode → throw on any non-allow (a plugin can't prompt, so `ask` becomes a hard block)

Adapters normalize host payloads to a `ToolEvent` (`command`, `paths`, `urls`,
`tool`, `cwd`, `operation`) and call `createGuardrails(agent).evaluate(event,
loadedSkills)`. The core owns path checks, bash checks, multi-path handling,
`apply_patch` path extraction, and skill-gate matching. Adapters only keep
session evidence and render host-specific deny/ask responses.

Skill gates are workflow nudges, not a security boundary. Each adapter supplies
session evidence that the skill was loaded — Claude scans the transcript;
Codex/pi/opencode accumulate `skillMentions` over visible hook/tool payloads.
A gate miss blocks with a "load the skill, then retry" message.

### Skill gate caveats

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
- **Write/fetch gates match on the path/URL the normalized tool event reports.** A host that
  routes a file write or fetch through a differently-shaped tool payload (no
  `path`/`url` the adapter recognizes) simply fails open for that gate — the
  gate degrades per host rather than mis-firing.

## Toggles

- **`machinery_enabled`** (per agent) — protect the guardrail/sandbox/renv files
  themselves from rewrite or bash access while still allowing normal read tools.
  Set an agent `false` only while bootstrapping.
- **`find_policy`** (per agent) — `always` (gate any find) / `exec` (only when an
  `-exec`/`-delete` primary is present) / `off`.

## Editing

Add a path, a dangerous command, or a skill gate to the relevant JSON; all
agents pick it up on their next hook/plugin load. Keep `core.ts`
dependency-free so every runtime can import it. 

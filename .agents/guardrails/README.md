# Agent guardrails

Single source of truth for the bash/path guards shared by coding agents
(Claude Code and pi). Data and logic is here; each harness has a thin
adapter that wires its hook API to this core.

## Layout

- `sensitive-paths.json`    - secret path prefixes + write-protected machinery paths
- `dangerous-commands.json` - command-name sets + per-agent `find_policy`
- `skill-gates.json`        - tool events that require a skill loaded this session,
                              by `trigger` type: bash command+subcommands, a Write/Edit
                              path glob, WebFetch domain, or provider-neutral capability
                              (e.g. `git commit` → `dev-git`)
- `core.ts`                 - the one implementation of the guard logic; no deps,
                              loads the JSONs, exports `createGuardrails(agent).evaluate()`,
                              tool-event helpers, and `skillReceipts()`

Adapters (thin, import `core.ts`):

| Agent  | Adapter                                     | Hook                               |
|--------|---------------------------------------------|------------------------------------|
| Claude | `.claude/hooks/guardrails.ts`               | bun CLI PreToolUse (settings.json) |
| pi     | `.config/pi/agent/extensions/guardrails.ts` | `tool_call` extension              |

## Decisions

`evaluate()` returns `deny`, `ask`, or `allow`. Path rules decide secrets,
machinery writes, and protected globs. Command rules are classified by
`severity` in `dangerous-commands.json`: a category maps either to one decision
for every agent, or to a per-agent object shaped like `find_policy`. An unlisted
category falls back to `ask`, so the mechanism stays inert until a category is
named.

Adapters map:
- Claude → PreToolUse `permissionDecision` (deny / ask)
- pi → block (deny) / prompt then block-if-declined (ask); with no UI it fails
  closed and blocks

Adapters normalize host payloads to a `ToolEvent` (`command`, `paths`, `urls`,
`tool`, `cwd`, `operation`) and call `createGuardrails(agent).evaluate(event,
loadedSkills)`. Capabilities are not part of that payload: no adapter sets them,
and the core derives them itself in `capabilitiesOf`. The core owns path checks,
bash checks, multi-path handling, `apply_patch` path extraction,
provider-neutral capability classification, and skill-gate matching. Adapters
only keep session evidence and render host-specific deny/ask responses.

Skill gates are workflow nudges, not a security boundary. Each adapter supplies
session evidence that the skill was loaded — all adapters record only concrete
native Skill calls, reads of canonical configured skill paths, or shell
commands that reference a canonical skill path (the only load mechanism a
bash-only harness has). A gate miss blocks with a "load the skill, then retry"
message.

### Skill gate caveats

- **A receipt is not proof of compliance.** A native skill call or canonical
  skill-file read proves only that the agent requested the skill, not that it
  followed its contents. Tests and clear instructions remain the behavioral
  proof.
- **pi assumes skills load through a visible tool call.** If a host injects
  skills internally (no read/skill tool event), the first gated command
  false-blocks once, then the instructed SKILL.md read registers and the retry
  passes. Verify once per host that the block reason reaches the model and the
  loop closes; if a host swallows it, the gate degrades to a mysterious failure.
- **Session scope drifts in pi.** The loaded-skills set lives exactly
  as long as the extension process: a host reusing one process across
  sessions carries evidence over (errs open); a mid-session restart wipes it
  (one self-healing false block). Claude persists receipts under
  `$XDG_STATE_HOME`, keyed by a hash of the transcript path, so a restart does
  not erase them. It has no alternative: its hook is a fresh process per tool
  call, so without the state file every call would start with an empty
  loaded-skills set and every gate would false-block.
- **Write/fetch gates match on the path/URL the normalized tool event reports.** A host that
  routes a file write or fetch through a differently-shaped tool payload (no
  `path`/`url` the adapter recognizes) simply fails open for that gate — the
  gate degrades per host rather than mis-firing.
- **Capability gates are intentionally generic.** The core recognizes semantic
  tool-name tokens (for example paper/citation/author/bibliography) and local
  worktree state, not provider/server IDs. New tools with unrelated names need
  a classifier test before they gain coverage; this is preferable to silently
  coupling policy to a current integration.

## Toggles

- **`machinery_enabled`** (per agent) — protect the guardrail/sandbox/renv files
  themselves from rewrite or bash access while still allowing normal read tools.
  Set an agent `false` only while bootstrapping.
- **`find_policy`** (per agent) — `always` (gate any find) / `exec` (only when an
  `-exec`/`-delete` primary is present) / `off`.
- **`severity`** (per category, optionally per agent) — the decision a command
  rule produces. A string applies to every agent; an object keys by agent like
  `find_policy`. An unlisted category falls back to `ask`, so the map is
  fail-safe. Never-legitimate categories (`escalation`, `confinement`,
  `disk-destructive`, `git-guard-bypass`, `recursive-force-rm-toplevel`) deny
  for everyone. Categories the sandbox already contains (`world-writable`,
  `recursive-force-rm`) allow only where `agent-checkpoint` is wired — claude
  today. It stays `ask` for pi, which has no per-turn snapshot yet, so allowing
  it there would loosen an agent that cannot recover uncommitted work. Wiring a
  checkpoint for an agent is what earns it this tier; nothing else does.

## Retired harnesses

Removing a harness does not remove its secrets. When one is dropped, delete its
credential file in the same pass as its config, or keep the path in
`credentials` until the file is gone — the guard list and the disk have to agree.

## Native permission layers

Beyond the shared hook, Claude also enforces the credential list at its own
permission layer:

| Agent  | Native layer                                | Status |
|--------|---------------------------------------------|--------|
| Claude | `.claude/settings.json` `permissions.deny`  | permanent — typed Read/Edit tool calls expose structured paths to match |
| pi     | none                                        | pi ships no permission system of its own; the `tool_call` extension is the enforcement point |

Claude's credential denies are drift-checked against `sensitive-paths.json` by
`make check-guardrails-native-sync`. The hook stays primary for everything a
path list cannot express: dangerous commands, skill gates, ref-rewrite
protection, and the `ask` tier.

The filesystem boundary for both agents is the `sandbox` profile each one
launches under, not a harness feature — see `.config/sandbox/README.md`.

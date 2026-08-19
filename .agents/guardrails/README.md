# Agent guardrails

Single source of truth for the bash/path guards shared by coding agents
(Claude Code, Codex, pi, opencode). Data and logic is here; each harness has a thin
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

| Agent    | Adapter                                     | Hook                               |
|----------|---------------------------------------------|------------------------------------|
| Claude   | `.claude/hooks/guardrails.ts`               | bun CLI PreToolUse (settings.json) |
| Codex    | `.config/codex/hooks/guardrails.ts`         | bun CLI hooks                      |
| pi       | `.config/pi/agent/extensions/guardrails.ts` | `tool_call` extension              |
| opencode | `.config/opencode/plugins/guardrails.ts`    | `tool.execute.before` plugin       |

## Decisions

`evaluate()` returns `deny`, `ask`, or `allow`. Path rules decide secrets,
machinery writes, and protected globs. Command rules are classified by
`severity` in `dangerous-commands.json`: a category maps either to one decision
for every agent, or to a per-agent object shaped like `find_policy`. An unlisted
category falls back to `ask`, so the mechanism stays inert until a category is
named.

Adapters map:
- Claude → PreToolUse `permissionDecision` (deny / ask)
- Codex → deny for every non-allow result (its hook API has no confirmation
  response, so `ask` is fail-closed)
- pi → block (deny) / prompt then block-if-declined (ask)
- opencode → throw on any non-allow (a plugin can't prompt, so `ask` becomes a hard block)

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
bash-only harness like Codex has). A gate miss blocks with a "load the skill,
then retry" message.

### Skill gate caveats

- **A receipt is not proof of compliance.** A native skill call or canonical
  skill-file read proves only that the agent requested the skill, not that it
  followed its contents. Tests and clear instructions remain the behavioral
  proof.
- **pi/opencode assume skills load through a visible tool call.** If a host
  injects skills internally (no read/skill tool event), the first gated command
  false-blocks once, then the instructed SKILL.md read registers and the retry
  passes. Verify once per host that the block reason reaches the model and the
  loop closes; if a host swallows it, the gate degrades to a mysterious failure.
- **Session scope drifts in pi/opencode.** The loaded-skills set lives exactly
  as long as the extension/plugin process: a host reusing one process across
  sessions carries evidence over (errs open); a mid-session restart wipes it
  (one self-healing false block). Claude and Codex both persist receipts under
  `$XDG_STATE_HOME`, keyed by a hash of the transcript path and by session id
  respectively, so a restart does not erase them. Codex has no alternative: its
  hook is a fresh process per tool call, so without the state file every call
  would start with an empty loaded-skills set and every gate would false-block.
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
  and, since 2026-08-19, codex. It stays `ask` for pi and opencode, and `ask`
  means "hard block" to opencode, so allowing it there would loosen an agent
  that cannot recover uncommitted work. Wiring a checkpoint for an agent is
  what earns it this tier; nothing else does.

## Native permission layers

Beyond the shared hook, some harnesses also enforce the path lists at a
native/OS layer:

| Agent    | Native layer                                                            | Status |
|----------|--------------------------------------------------------------------------|--------|
| Claude   | `.claude/settings.json` `permissions.deny`                               | permanent — typed Read/Edit tool calls expose structured paths to match |
| opencode | `.config/opencode/opencode.jsonc` `permission`                            | in-repo scope only — the host-credential duplication was removed, not the layer; `plugins/guardrails.ts` enforces the shared core (verified loading + blocking) |
| Codex    | `.config/codex/config.toml.template` `[permissions.guarded-workspace]`   | permanent — OS-enforced (Landlock/seccomp) where the sandbox can initialize — see status below |
| pi       | none                                                                     | assumed: pi embeds in the host process and ships no OS sandbox of its own (unverified) |

Codex's only real tool is a bash-like shell (plus `apply_patch`), so the shared
hook must pattern-match paths out of raw command text there — the weakest
matching in the fleet. `[permissions.guarded-workspace]` compensates at the
kernel: credentials → `deny`, machinery → `read`, translated 1:1 from
`sensitive-paths.json`. Claude's credential denies and Codex's complete native
profile are drift-checked by `make check-guardrails-native-sync`; opencode's
remaining native rules name no host path, so there is nothing to drift-check
there. The hook stays
primary for everything the 3-level filesystem model cannot express: dangerous
commands, skill gates, ref-rewrite protection, and the `ask` tier.

### Codex verification status (codex-cli 0.143.0, 2026-07-16)

Repro: `codex sandbox -P <profile>` against a scratch `$CODEX_HOME` (`codex
debug landlock` no longer exists in this build).

**Enforcement is environment-dependent — dormant on this host.** Codex applies
the Landlock profile only inside its execution sandbox, and building that
sandbox unshares the network namespace. Hosts that forbid unprivileged netns
(this shared academic system: `bwrap: loopback: Failed RTM_NEWADDR: Operation
not permitted`) cannot start it, so Codex falls back to running the command
*outside* the sandbox (with approval), where **no Landlock rule applies**;
trusted projects bypass the sandbox regardless. The `deny` *mechanism* itself is
sound — the standalone probe builds a Landlock-only sandbox without the failing
netns step — so where the OS layer is dormant the shared hook is the sole
functional Codex guard, which is its intended primary role anyway.

One gap survives even where the sandbox works: with cwd *inside* a machinery
`read` dir, the workspace-root `write` grant wins the tie and re-grants OS-level
write there, leaving the hook as the only machinery guard. Credentials are
unaffected — `deny` wins ties.

`default_permissions` therefore stays `:read-only` in the template (Step B not
flipped): on a sandbox-less host the flip buys no enforcement, and on a host
where the sandbox works the profile is still reachable via
`-c default_permissions=guarded-workspace`.

## Editing

Add a path, a dangerous command, or a skill gate to the relevant JSON; all
agents pick it up on their next hook/plugin load. Keep `core.ts`
dependency-free so every runtime can import it.

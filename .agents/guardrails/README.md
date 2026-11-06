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
machinery writes, and protected globs. A protected glob such as `**/*.tex` denies
typed writes, and a Bash command naming a match is refused unless it is a plain
read of the kind `protected_glob_readers` lists. Command rules are classified by
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
bash checks, multi-path handling,
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

## Design rules

Learned from other people's configurations as much as from this one.

- **Never replace enforcement with a prompt.** A tool allowlist that the runtime
  applies and an instruction saying "do not edit anything" are not two spellings
  of one idea: the first cannot be reasoned around and the second is advisory.
  Trading the first for the second reads as simplification and is a downgrade,
  and the measured gap between gated and ungated compliance in this config is
  large enough to make that concrete.
- **One policy, one engine.** Two mechanisms enforcing the same rule drift, and
  the drift is silent. Deriving one from the other by matching the TEXT of the
  first — a floor computed by string-matching the source of a regex list — is
  the worst form: reword the pattern and the floor loses a rule with nothing to
  notice.
- **A toggle may never fail open.** If a guard cannot prompt because there is no
  UI, that is the case for refusing, not for allowing. An "auto-allow when
  headless" flag inverts the guard exactly where it is least supervised.
- **Prefer a prefix or a shape to an enumeration** where the family is
  open-ended. Ten enumerated `mkfs.*` names still missed two, and the next
  filesystem would have reopened the hole with no symptom.

## Toggles

- **`machinery_enabled`** (per agent) — protect the guardrail and sandbox files
  themselves from rewrite or bash access while still allowing normal read tools.
  Set an agent `false` only while bootstrapping.
- **`find_policy`** (per agent) — `exec` (gate a find only when an
  `-exec`/`-delete` primary is present) / `off`.
- **`severity`** (per category, optionally per agent) — the decision a command
  rule produces. A string applies to every agent; an object keys by agent like
  `find_policy`. An unlisted category falls back to `ask`, so the map is
  fail-safe. Never-legitimate categories (`escalation`, `confinement`,
  `disk-destructive`, `git-guard-bypass`, `recursive-force-rm-toplevel`,
  `host-control`, `remote-code`, `git-recovery-prune`,
  `git-clean-ignored` — ignored trees are outside the checkpoint's reach) deny
  for everyone. Scratch-only categories such as `recursive-force-rm-scratch`
  and `world-writable-scratch` allow for every agent, because their targets are
  strictly below the configured scratch root and not trusted state. The ordinary
  `recursive-force-rm` and `world-writable` categories stay `ask`: checkpointing
  covers some work-tree state but not ignored trees, future PATH trust points,
  or every way a permission change can persist beyond the sandbox.

## Retired harnesses

Removing a harness does not remove its secrets. When one is dropped, delete its
credential file in the same pass as its config, or keep the path in
`credentials` until the file is gone — the guard list and the disk have to agree.

## Which layer enforces what

The Bash scan in `core.ts` reads command text, and a shell can spell one effect
many ways, so the scan catches mistakes and is not a boundary. The table names
the layer behind each protection:

| Protection | Bash, Claude | Bash, pi | Typed file tools |
|------------|--------------|----------|------------------|
| Credentials unreadable | sandbox `denyRead`, built from the `Read()` denies | never bound, or `MASK` in `machinery-ro.profile` | this hook, and Claude's `Read()` denies |
| Machinery unwritable | sandbox `denyWrite`, built from the `Edit()` denies | `RO_LAST` in `machinery-ro.profile` | this hook, and Claude's `Edit()` denies |
| Agent commits stay on agent branches | the shared git hooks | the shared git hooks | not applicable |
| Agents do not commit hand-written `.tex` | `reference-transaction` | `reference-transaction` | this hook denies typed writes to `*.tex` |
| Dangerous commands | this scan only | this scan only | not applicable |

`make check-guardrails-native-sync` and `make check-machinery-ro-sync` keep the
two harnesses' lists in step with `sensitive-paths.json`.

The git hooks run only when git runs them, in the agent's own environment.
Bash can write `.git/` directly, and `core.hooksPath` is set only in
`~/.config/git/config`, so each of these skips or subverts them:
- a ref file written by hand;
- `git config core.hooksPath`, or the same line written into `.git/config`;
- `git symbolic-ref`, which writes no ref transaction;
- git run with another `HOME` or `XDG_CONFIG_HOME`;
- a variable that changes what the hook script runs, such as `GIT_EXEC_PATH`,
  `BASH_ENV` or an exported shell function.

They stop an agent's ordinary git commands, not one set on getting around them.

A `.tex` file outside `generated/` can still change in the working tree through
Bash; the commit is what `reference-transaction` refuses. `agent-checkpoint`
snapshots the working directory's repository before each Bash call, gitignored
files excepted, so an edit there can usually be recovered from
`refs/agent-checkpoint/`.

## Native permission layers

Beyond the shared hook, Claude also enforces the credential list for reads and
the machinery list for writes at its own permission layer:

| Agent  | Native layer                                | Status |
|--------|---------------------------------------------|--------|
| Claude | `.claude/settings.json` `permissions.deny`  | permanent — typed Read/Edit tool calls expose structured paths to match |
| pi     | `@zackify/pi-claude-permissions` package    | NOT synced: its own hard-coded protected-path and catastrophic-command lists, applied even in bypass mode; it reads `~/.pi/agent/settings.json`, so its `piClaudePermissions` block works only through the untracked `~/.pi` symlink. The `tool_call` extension remains the enforcement point for this policy |

Claude's Read and Edit denies are drift-checked against `sensitive-paths.json` by
`make check-guardrails-native-sync`; pi's package is not. The hook stays primary for everything a
path list cannot express: dangerous commands, skill gates, ref-rewrite
protection, and the `ask` tier.

The filesystem boundary is not this hook. Bare `claude` uses the `sandbox`
block of its own `settings.json`; Pi's `shellPath` uses
`~/.local/scripts/pi-bash` and the shared `sandbox -p agent` profile. Both put
Bash subprocesses behind the kernel while typed file tools rely on their
in-process deny rules — see `.config/sandbox/README.md`. The core relaxes the
machinery-in-bash rule where the kernel already pins those paths: for Claude,
when the adapter reads an enabled
native sandbox from the machinery-pinned
`settings.json` (never for a call carrying `dangerouslyDisableSandbox`).

/**
 * Characterization of the guardrail command-severity tier.
 *
 * Every danger category resolves through the per-agent severity map in
 * dangerous-commands.json (core.ts severityOf): `deny` (never legitimate,
 * silent), `ask` (prompt where the harness can prompt, hard block where it
 * cannot), or `allow` (already contained by the sandbox and recoverable via
 * agent-checkpoint).
 *
 * This table pins the whole map so that reclassification cannot happen
 * silently: changing behavior must show up as an edit to an expectation here,
 * one row at a time, rather than as a diff buried in the JSON.
 *
 * Command severity is evaluated before skill gates (core.ts: evaluate returns
 * early on any non-allow guard result), so gated commands such as `git commit`
 * still report their command severity here rather than a skill-gate deny.
 */
import { expect, test } from "bun:test";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { createGuardrails } from "../.agents/guardrails/core.ts";

const cwd = "/tmp/project";

// Severity comes from shared data — the adapters differ only in how they
// RENDER a decision (codex denies on any non-allow, opencode throws). Rows may
// declare a deliberate per-agent split; anything off-table failing for one
// agent but not another means the data has drifted.
const AGENTS = ["claude", "codex", "pi", "opencode"] as const;

// Treat every gated skill as already loaded. Command severity short-circuits
// before skill gates, so the `ask` rows are unaffected either way — but a
// control row like `git push` would otherwise report the dev-git gate's deny
// instead of its command severity, which is not what this table is about.
const gatesPath = join(import.meta.dir, "../.agents/guardrails/skill-gates.json");
const gates = JSON.parse(readFileSync(gatesPath, "utf8"));
const loadedSkills = new Set<string>(
  (gates.gates ?? []).flatMap((g: { skills?: string[] }) => g.skills ?? []),
);

const railsFor = new Map(AGENTS.map((a) => [a, createGuardrails(a)]));
const decideAs = (agent: string, command: string) =>
  railsFor.get(agent)!.evaluate({ tool: "bash", command, cwd }, loadedSkills).decision;

type Agent = (typeof AGENTS)[number];
type Severity = "deny" | "ask" | "allow";

// A row expects either one severity for every harness, or a per-agent split.
// The split is not cosmetic: `ask` means "prompt" to claude and pi but "hard
// block" to codex and opencode, so reclassifying a row to `allow` loosens the
// latter from blocked to permitted. Rows that rely on agent-checkpoint for
// their safety therefore stay `ask` wherever no checkpoint is wired -- which
// since 2026-08-19 means pi and opencode, not codex.
type Expected = Severity | ({ default: Severity } & Partial<Record<Agent, Severity>>);

const expectedFor = (e: Expected, agent: Agent): Severity =>
  typeof e === "string" ? e : (e[agent] ?? e.default);

const label = (e: Expected): string =>
  typeof e === "string"
    ? e
    : Object.entries(e)
        .map(([k, v]) => `${k}=${v}`)
        .join(" ");

type Row = { command: string; expected: Expected; note?: string };

const TABLE: Row[] = [
  // --- privilege escalation: never legitimate, so silent rather than prompted --
  { command: "sudo apt install ripgrep", expected: "deny" },
  { command: "env FOO=1 sudo id", expected: "deny", note: "wrapper-aware; a Bash(sudo:*) rule misses this" },
  { command: "doas id", expected: "deny" },

  // --- severity must survive `sh -c` recursion ---------------------------------
  // dangerReason recurses into shell runners and returns the nested result; if
  // that result stopped carrying its category, nested commands would silently
  // fall back to the unlisted-category default of ask.
  { command: "sh -c 'sudo id'", expected: "deny", note: "category propagates through recursion" },
  { command: "bash -c 'rm -rf /'", expected: "deny", note: "top-level target, through recursion" },

  // --- confinement tampering: the agent disabling its own guard ----------------
  { command: "unset AGENT_BRANCH_PREFIX", expected: "deny" },
  { command: "AGENT_BRANCH_PREFIX=other git commit -m x", expected: "deny" },
  { command: "env -i bash -c 'git commit'", expected: "deny" },
  { command: "GIT_CONFIG_COUNT=1 git commit -m x", expected: "deny" },

  // --- git guard bypass: unapprovable, run it yourself in a terminal -----------
  // dev-git already says to present these rather than run them; deny enforces it.
  { command: "git -c core.hooksPath=/dev/null commit -m x", expected: "deny" },
  { command: "git commit --no-verify -m x", expected: "deny" },
  { command: "git push --force origin main", expected: "deny" },
  { command: "git branch -D claude/topic", expected: "deny" },
  // The rule's message already says "forced/deleted"; -d is the safe variant
  // but is still a deletion, and there is no ask tier left to surface it.
  { command: "git branch -d claude/topic", expected: "deny", note: "merged-only delete is still a delete" },
  { command: "git branch --delete claude/topic", expected: "deny" },
  { command: "git branch -a", expected: "allow", note: "listing must stay allowed" },
  { command: "git update-ref refs/heads/main HEAD", expected: "deny" },

  // --- disk-destructive: no block devices in the container, never legitimate ---
  { command: "dd if=/dev/zero of=/dev/sda", expected: "deny" },
  { command: "mkfs.ext4 /dev/sdb1", expected: "deny" },
  { command: "shred -u secrets.bin", expected: "deny" },

  // --- candidates for allow: the sandbox already contains these -----------------
  // Recursive force rm inside the project is recoverable via agent-checkpoint,
  // which claude and codex have wired -- hence the per-agent split. The split
  // tracks which agents snapshot per turn, not which harness is trusted.
  {
    command: "rm -rf build",
    expected: { claude: "allow", codex: "allow", default: "ask" },
    note: "inside the project, checkpoint covers it",
  },
  {
    command: "rm -rf ./build/cache",
    expected: { claude: "allow", codex: "allow", default: "ask" },
    note: "nested inside the project",
  },

  // ...but a top-level target is denied for EVERY agent, including claude.
  // Checkpoint refs live in .git inside the repo, so deleting a repo root or a
  // home directory destroys the work and its only recovery together. There is
  // no severity value that makes that acceptable.
  { command: "rm -rf /", expected: "deny", note: "filesystem root" },
  { command: "rm -rf ~", expected: "deny", note: "home" },
  { command: "rm -rf ~/dotfiles", expected: "deny", note: "direct child of home: a repo root" },
  { command: "rm -rf ~/projects", expected: "deny", note: "direct child of home" },
  { command: "rm -rf $HOME/dotfiles", expected: "deny", note: "$HOME normalizes to the same path" },
  { command: "rm -rf .", expected: "deny", note: "the whole working directory" },
  { command: "rm -rf ..", expected: "deny", note: "an ancestor of the working directory" },
  {
    command: "cd /tmp && rm -rf /tmp/project",
    expected: "deny",
    note: "absolute path equal to cwd, reached from another segment",
  },
  // `cd` then a RELATIVE target is the form an agent actually produces, and it
  // is invisible unless the effective directory is tracked across segments:
  // resolving `dotfiles` against the event cwd gives <cwd>/dotfiles, not ~/dotfiles.
  { command: "cd ~ && rm -rf dotfiles", expected: "deny", note: "relative target after cd home" },
  { command: "cd /tmp && rm -rf project", expected: "deny", note: "relative target after cd" },

  // --- rm reached through a pipeline or eval ----------------------------------
  // `find ... | xargs rm -rf` is what a model actually writes, and until xargs
  // was a recognized wrapper the segment parsed as an `xargs` command: none of
  // the rm rules above ran at all, so even the top-level deny was unreachable.
  // Targets arriving on stdin cannot be resolved here, so they take the
  // top-level tier rather than the in-project one -- a false deny costs a
  // rerun, a false allow costs the repository.
  { command: "find . -type d -name build | xargs rm -rf", expected: "deny", note: "targets arrive on stdin" },
  { command: "find . -print0 | xargs -0 rm -rf", expected: "deny", note: "-0 is a flag, not a target" },
  { command: "xargs -n 1 rm -rf", expected: "deny", note: "-n takes a value, so `1` is not the command" },
  // Controls: recognizing xargs must not gate benign pipelines, and a plain
  // `rm` without -rf is still the ordinary non-recursive case.
  { command: "find . -name '*.log' | xargs rm", expected: "allow", note: "not recursive-force" },
  { command: "xargs ls", expected: "allow", note: "wrapper recognition must not gate benign commands" },

  // `eval` takes its script as ordinary arguments rather than behind -c, so the
  // shell-runner recursion never saw it and the whole command was invisible.
  { command: "eval 'rm -rf ~'", expected: "deny", note: "quoted script through eval" },
  { command: "eval rm -rf /", expected: "deny", note: "unquoted script through eval" },
  { command: "cd .. && rm -rf project", expected: "deny", note: "relative target after cd up" },
  {
    command: "cd build && rm -rf src",
    expected: { claude: "allow", codex: "allow", default: "ask" },
    note: "cd tracking must not over-broaden: still inside the project",
  },
  {
    command: "chmod 777 script.sh",
    expected: { claude: "allow", codex: "allow", default: "ask" },
    note: "system paths are ro and the container is single-user; a lint concern, not a boundary",
  },
  {
    command: "find . -name '*.pyc' -exec rm {} ;",
    expected: { claude: "allow", codex: "allow", default: "ask" },
    note: "find_policy off for the checkpointed agents; a nudge the sandbox already contains",
  },

  // --- read vs write forms of the ref subcommands ------------------------------
  // symbolic-ref and replace are in git_ref_write_subcmds but have read forms.
  // .config/git/hooks/pre-commit:12 runs `git symbolic-ref --quiet --short HEAD`,
  // so denying the read form would break committing entirely.
  {
    command: "git symbolic-ref --short HEAD",
    expected: "allow",
    note: "a READ; pre-commit uses this exact form",
  },
  { command: "git replace -l", expected: "allow", note: "a LIST" },
  { command: "git replace --list", expected: "allow", note: "a LIST" },
  { command: "git replace", expected: "allow", note: "bare invocation lists" },
  // Write forms of `replace` that carry fewer than two operands. An
  // operand-count heuristic misses both, so `replace` must be treated as a
  // write unless it is provably a list.
  { command: "git replace --graft abc123", expected: "deny", note: "one operand, still a WRITE" },
  { command: "git replace --convert-graft-file", expected: "deny", note: "no operands, still a WRITE" },
  {
    command: "git symbolic-ref HEAD refs/heads/main",
    expected: "deny",
    note: "a WRITE: name plus value operand",
  },
  {
    command: "git update-ref -d refs/heads/x",
    expected: "deny",
    note: "always a write, no read form",
  },

  // --- controls: must stay allow through any reclassification ------------------
  { command: "ls -la", expected: "allow" },
  { command: "rm -r build", expected: "allow", note: "recursive without --force is not gated" },
  { command: "git push origin claude/topic", expected: "allow" },
  { command: "find . -name '*.py'", expected: "allow", note: "no -exec primary" },
];

for (const { command, expected, note } of TABLE) {
  test(`${label(expected)}: ${command}${note ? ` (${note})` : ""}`, () => {
    for (const agent of AGENTS) {
      expect(`${agent}: ${decideAs(agent, command)}`).toBe(`${agent}: ${expectedFor(expected, agent)}`);
    }
  });
}

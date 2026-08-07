/**
 * Characterization of the guardrail command-severity tier.
 *
 * Every command rule currently resolves to `ask` — core.ts hardcodes
 * `{ decision: "ask" }` for any dangerReason hit, so there is no way to express
 * "deny" for a command. Emptying the ask tier means reclassifying each row below
 * to `deny` (never legitimate, should be silent) or `allow` (already contained
 * by the sandbox).
 *
 * This table is pinned FIRST so that reclassification cannot happen silently:
 * changing behavior must show up as an edit to an expectation here, one row at a
 * time, rather than as a diff buried in core.ts.
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

// Severity comes from shared data, so it must hold for every harness — the
// adapters differ in how they RENDER a decision (codex denies on any non-allow,
// opencode throws), but the core's classification is one policy. A row that
// passes for claude and fails for pi means the data has drifted per-agent.
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
const decide = (command: string) => decideAs("claude", command);

type Agent = (typeof AGENTS)[number];
type Severity = "deny" | "ask" | "allow";

// A row expects either one severity for every harness, or a per-agent split.
// The split is not cosmetic: `ask` means "prompt" to claude and pi but "hard
// block" to codex and opencode, so reclassifying a row to `allow` loosens those
// two from blocked to permitted. Rows that rely on agent-checkpoint for their
// safety therefore stay `ask` wherever no checkpoint is wired.
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
  {
    command: "bash -c 'rm -rf /'",
    expected: { claude: "allow", default: "ask" },
    note: "hook allows; Claude Code's own circuit breaker still prompts for / and ~",
  },

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
  { command: "git update-ref refs/heads/main HEAD", expected: "deny" },

  // --- disk-destructive: no block devices in the container, never legitimate ---
  { command: "dd if=/dev/zero of=/dev/sda", expected: "deny" },
  { command: "mkfs.ext4 /dev/sdb1", expected: "deny" },
  { command: "shred -u secrets.bin", expected: "deny" },

  // --- candidates for allow: the sandbox already contains these -----------------
  {
    command: "rm -rf build",
    expected: { claude: "allow", default: "ask" },
    note: "recoverable via agent-checkpoint, which only claude has wired",
  },
  {
    command: "chmod 777 script.sh",
    expected: { claude: "allow", default: "ask" },
    note: "system paths are ro and the container is single-user; a lint concern, not a boundary",
  },
  {
    command: "find . -name '*.pyc' -exec rm {} ;",
    expected: { claude: "allow", default: "ask" },
    note: "find_policy.claude=off; a workflow nudge the sandbox already contains",
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

// Progress marker, not an assertion about behavior: the rows above are the
// contract. Emptying the tier means this list reaches zero.
test("rows still awaiting reclassification are visible", () => {
  const remaining = TABLE.filter((r) => expectedFor(r.expected, "claude") === "ask").map((r) => r.command);
  if (remaining.length) console.log(`claude ask tier not yet empty (${remaining.length} rows)`);
  expect(remaining.every((c) => decideAs("claude", c) === "ask")).toBe(true);
});

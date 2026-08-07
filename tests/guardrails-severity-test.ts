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

type Row = { command: string; expected: "deny" | "ask" | "allow"; note?: string };

const TABLE: Row[] = [
  // --- privilege escalation: candidate for deny --------------------------------
  { command: "sudo apt install ripgrep", expected: "ask" },
  { command: "env FOO=1 sudo id", expected: "ask", note: "wrapper-aware; a Bash(sudo:*) rule misses this" },
  { command: "doas id", expected: "ask" },

  // --- confinement tampering: candidate for deny -------------------------------
  { command: "unset AGENT_BRANCH_PREFIX", expected: "ask" },
  { command: "AGENT_BRANCH_PREFIX=other git commit -m x", expected: "ask" },
  { command: "env -i bash -c 'git commit'", expected: "ask" },
  { command: "GIT_CONFIG_COUNT=1 git commit -m x", expected: "ask" },

  // --- git guard bypass: candidate for deny ------------------------------------
  { command: "git -c core.hooksPath=/dev/null commit -m x", expected: "ask" },
  { command: "git commit --no-verify -m x", expected: "ask" },
  { command: "git push --force origin main", expected: "ask" },
  { command: "git branch -D claude/topic", expected: "ask" },
  { command: "git update-ref refs/heads/main HEAD", expected: "ask" },

  // --- disk-destructive: candidate for deny ------------------------------------
  { command: "dd if=/dev/zero of=/dev/sda", expected: "ask" },
  { command: "mkfs.ext4 /dev/sdb1", expected: "ask" },
  { command: "shred -u secrets.bin", expected: "ask" },

  // --- candidates for allow: the sandbox already contains these -----------------
  { command: "rm -rf build", expected: "ask", note: "the one worth keeping; see checkpoint contract" },
  { command: "chmod 777 script.sh", expected: "ask" },
  { command: "find . -name '*.pyc' -exec rm {} ;", expected: "ask", note: "find_policy=exec" },

  // --- the read-form trap: promoting ref ops to deny would break this -----------
  {
    command: "git symbolic-ref --short HEAD",
    expected: "ask",
    note: "a READ, but symbolic-ref is in git_ref_write_subcmds; pre-commit uses this exact form",
  },

  // --- controls: must stay allow through any reclassification ------------------
  { command: "ls -la", expected: "allow" },
  { command: "rm -r build", expected: "allow", note: "recursive without --force is not gated" },
  { command: "git push origin claude/topic", expected: "allow" },
  { command: "find . -name '*.py'", expected: "allow", note: "no -exec primary" },
];

for (const { command, expected, note } of TABLE) {
  test(`${expected}: ${command}${note ? ` (${note})` : ""}`, () => {
    for (const agent of AGENTS) {
      expect(`${agent}: ${decideAs(agent, command)}`).toBe(`${agent}: ${expected}`);
    }
  });
}

test("the ask tier is non-empty today, and this is what emptying it must change", () => {
  const asked = TABLE.filter((r) => r.expected === "ask");
  expect(asked.length).toBeGreaterThan(0);
  // Every ask row must be reclassified deliberately. When the tier is emptied
  // this expectation flips to 0 and each row above carries deny or allow.
  expect(TABLE.filter((r) => decide(r.command) === "ask").length).toBe(asked.length);
});

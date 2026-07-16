import { expect, test } from "bun:test";
import { mkdtempSync, readFileSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createGuardrails, skillReceipts, toolEventFromInput } from "../../../.agents/guardrails/core.ts";

const cwd = "/tmp/project";

test("secret paths are denied for reads", () => {
  const rails = createGuardrails("opencode");
  const r = rails.evaluate({ tool: "read", paths: ["~/.ssh/config"], cwd });
  expect(r.decision).toBe("deny");
});

test("guardrail machinery is readable but not writable", () => {
  const rails = createGuardrails("opencode");
  const path = "~/dotfiles/.agents/guardrails/core.ts";
  expect(rails.evaluate({ tool: "grepika_get", paths: [path], cwd }).decision).toBe("allow");
  expect(rails.evaluate({ tool: "write", paths: [path], cwd }).decision).toBe("deny");
});

test("codex enforcement files are machinery too", () => {
  const rails = createGuardrails("codex");
  for (const path of ["~/dotfiles/.config/codex/hooks/guardrails.ts", "~/.codex/config.toml", "~/dotfiles/.config/codex/config.toml.template"]) {
    expect(rails.evaluate({ tool: "grepika_get", paths: [path], cwd }).decision).toBe("allow");
    expect(rails.evaluate({ tool: "write", paths: [path], cwd }).decision).toBe("deny");
  }
});

test("recursive force rm is caught through wrappers", () => {
  const rails = createGuardrails("opencode");
  for (const command of [
    "rm -rf tmp",
    "timeout 5 rm -rf tmp",
    "nice -n 10 rm -rf tmp",
    "env -u FOO rm -rf tmp",
    "bash -c 'rm -rf tmp'",
  ]) {
    expect(rails.evaluate({ tool: "bash", command, cwd }).decision).toBe("ask");
  }
});

test("find exec policy is caught", () => {
  const rails = createGuardrails("opencode");
  const r = rails.evaluate({ tool: "bash", command: "find . -name x -exec rm {} \\;", cwd });
  expect(r.decision).toBe("ask");
});

test("git commit requires dev-git and dev-verification skills", () => {
  const rails = createGuardrails("opencode");
  const event = { tool: "bash", command: "git commit -m ok", cwd };
  expect(rails.evaluate(event).skills).toEqual(["dev-git", "dev-verification"]);
  expect(rails.evaluate(event, ["dev-git"]).skills).toEqual(["dev-verification"]);
  expect(rails.evaluate(event, ["dev-git", "dev-verification"]).decision).toBe("allow");
});

test("codex missing-skill message names the canonical skill path", () => {
  const rails = createGuardrails("codex");
  const r = rails.evaluate({ tool: "bash", command: "git commit -m ok", cwd });
  expect(r.skill).toBe("dev-git");
  expect(r.reason).toContain("skills/<name>/SKILL.md");
});

test("root markdown write requires project-docs skill", () => {
  const rails = createGuardrails("opencode");
  const r = rails.evaluate({ tool: "write", paths: ["PLAN.md"], cwd });
  expect(r.skills).toEqual(["context-project-docs"]);
});

test("README and project notes writes require project-docs skill", () => {
  const rails = createGuardrails("opencode");
  for (const path of ["README.md", "notes/claim.html"]) {
    expect(rails.evaluate({ tool: "write", paths: [path], cwd }).skills)
      .toEqual(["context-project-docs"]);
  }
});

test("academic-source tool names require research-protocol without provider coupling", () => {
  const rails = createGuardrails("opencode");
  const event = toolEventFromInput("mcp__catalog__search_papers", {}, cwd);
  expect(rails.evaluate(event).skills).toEqual(["research-protocol"]);
});

test("test commands in a git worktree require dev-worktree", () => {
  const worktree = mkdtempSync(join(tmpdir(), "guardrails-worktree-"));
  writeFileSync(join(worktree, ".git"), "gitdir: /tmp/main/.git/worktrees/test\n");

  const rails = createGuardrails("opencode");
  expect(rails.evaluate({ tool: "bash", command: "pytest", cwd: worktree }).skills)
    .toEqual(["dev-worktree"]);
});

test("only concrete skill calls or canonical skill reads produce load receipts", () => {
  expect([...skillReceipts("skill", { name: "dev-git" })]).toEqual(["dev-git"]);
  expect([...skillReceipts("read", { filePath: "~/.agents/skills/dev-git/SKILL.md" })]).toEqual(["dev-git"]);
  expect([...skillReceipts("read", { filePath: "notes/skills/dev-git/SKILL.md" })]).toEqual([]);
  expect([...skillReceipts("read", { text: "load dev-git" })]).toEqual([]);
});

test("shell commands referencing a canonical skill path produce load receipts", () => {
  expect([...skillReceipts("shell", { command: "cat ~/.config/codex/skills/dev-git/SKILL.md" })]).toEqual(["dev-git"]);
  expect([...skillReceipts("shell", { command: "sed -n 1,40p ~/dotfiles/.agents/skills/dev-git/SKILL.md" })]).toEqual(["dev-git"]);
  expect([...skillReceipts("shell", { command: "echo dev-git" })]).toEqual([]);
  expect([...skillReceipts("shell", { command: "cat notes/skills/dev-git/SKILL.md" })]).toEqual([]);
  expect([...skillReceipts("apply_patch", { command: "*** Begin Patch\n*** Update File: .agents/skills/dev-git/SKILL.md\n*** End Patch" })]).toEqual([]);
});

test("Claude guardrail hook observes Skill calls to persist load receipts", () => {
  const settings = JSON.parse(readFileSync(join(import.meta.dir, "../../../.claude/settings.json"), "utf8"));
  const matchers = settings.hooks.PreToolUse.map((entry: { matcher?: string }) => entry.matcher ?? "");
  expect(matchers.some((matcher: string) => matcher.split("|").includes("Skill"))).toBe(true);
});

test("apply_patch paths are normalized without treating patch text as bash", () => {
  const rails = createGuardrails("codex");
  const event = toolEventFromInput("apply_patch", {
    command: "*** Begin Patch\n*** Add File: PLAN.md\n+hi\n*** End Patch",
  }, cwd);
  expect(event.command).toBeUndefined();
  expect(event.paths).toEqual(["PLAN.md"]);
  expect(rails.evaluate(event).skill).toBe("context-project-docs");
});

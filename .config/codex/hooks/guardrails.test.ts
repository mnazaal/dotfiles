import { expect, test } from "bun:test";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { createGuardrails, skillReceipts, toolEventFromInput } from "../../../.agents/guardrails/core.ts";

const cwd = "/tmp/project";

test("missing deployed policy prevents guardrail construction", () => {
  const home = mkdtempSync(join(tmpdir(), "guardrails-empty-home-"));
  const core = join(import.meta.dir, "../../../.agents/guardrails/core.ts");
  const script = `import { createGuardrails } from ${JSON.stringify(core)}; createGuardrails("codex");`;
  const result = Bun.spawnSync(["bun", "-e", script], {
    cwd: home,
    env: { ...process.env, HOME: home },
    stderr: "pipe",
  });
  rmSync(home, { recursive: true, force: true });
  expect(result.exitCode).not.toBe(0);
});

test("secret paths are denied for reads", () => {
  const rails = createGuardrails("opencode");
  const r = rails.evaluate({ tool: "read", paths: ["~/.ssh/config"], cwd });
  expect(r.decision).toBe("deny");
});

test("glob patterns are treated as read paths", () => {
  const rails = createGuardrails("claude");
  const event = toolEventFromInput("Glob", { pattern: "~/.ssh/**" }, cwd);
  expect(rails.evaluate(event).decision).toBe("deny");
});

test("guardrail machinery is readable but not writable", () => {
  const rails = createGuardrails("opencode");
  const path = "~/dotfiles/.agents/guardrails/core.ts";
  expect(rails.evaluate({ tool: "grepika_get", paths: [path], cwd }).decision).toBe("allow");
  expect(rails.evaluate({ tool: "write", paths: [path], cwd }).decision).toBe("deny");
});

test("codex enforcement files are machinery too", () => {
  const rails = createGuardrails("codex");
  for (const path of [
    "~/.config/codex/config.toml",
    "~/.config/codex/hooks.json",
    "~/dotfiles/.config/codex/hooks/guardrails.ts",
    "~/dotfiles/.config/codex/config.toml.template",
  ]) {
    expect(rails.evaluate({ tool: "grepika_get", paths: [path], cwd }).decision).toBe("allow");
    expect(rails.evaluate({ tool: "write", paths: [path], cwd }).decision).toBe("deny");
  }
});

test("Codex auth is denied as a credential", () => {
  const rails = createGuardrails("codex");
  for (const event of [
    { tool: "read", paths: ["~/.config/codex/auth.json"], cwd },
    { tool: "bash", command: "cat ~/.config/codex/auth.json", cwd },
  ]) {
    expect(rails.evaluate(event).decision).toBe("deny");
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

test("git commit requires dev-git skill", () => {
  const rails = createGuardrails("opencode");
  const event = { tool: "bash", command: "git commit -m ok", cwd };
  expect(rails.evaluate(event).skills).toEqual(["dev-git"]);
  expect(rails.evaluate(event, ["dev-git"]).decision).toBe("allow");
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

test("Claude guardrail hook covers path-capable tools and asks when unavailable", () => {
  const settings = JSON.parse(readFileSync(join(import.meta.dir, "../../../.claude/settings.json"), "utf8"));
  const matchers = settings.hooks.PreToolUse.map((entry: { matcher?: string }) => entry.matcher ?? "");
  expect(matchers.some((matcher: string) => matcher.split("|").includes("Skill"))).toBe(true);
  expect(matchers.some((matcher: string) => matcher.split("|").includes("Glob"))).toBe(true);
  expect(matchers.some((matcher: string) => matcher.split("|").includes("Grep"))).toBe(true);
  const commands = settings.hooks.PreToolUse.flatMap((entry: { hooks?: { command?: string }[] }) =>
    (entry.hooks ?? []).map((hook) => hook.command ?? ""));
  expect(commands.some((command: string) => command.includes('"permissionDecision":"ask"'))).toBe(true);
  expect(commands.some((command: string) => command.includes("exit 2"))).toBe(false);
});

test("Codex only registers guardrails for evaluated hook events", () => {
  const hooks = JSON.parse(readFileSync(join(import.meta.dir, "../hooks.json"), "utf8"));
  expect(hooks.hooks.PreToolUse).toBeDefined();
  expect(hooks.hooks.PermissionRequest).toBeDefined();
  expect(hooks.hooks.UserPromptSubmit).toBeUndefined();
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

test("arg_contains narrows a bash gate to matching arguments", () => {
  const rails = createGuardrails("opencode");
  const hit = rails.evaluate({
    tool: "bash",
    command: "git subtree push --prefix=manuscript overleaf main",
    cwd,
  });
  expect(hit.skills).toEqual(["research-manuscript-sync"]);

  const miss = rails.evaluate({
    tool: "bash",
    command: "git subtree push --prefix=docs origin main",
    cwd,
  });
  expect(miss.decision).toBe("allow");

  expect(rails.evaluate({ tool: "bash", command: "make overleaf-push", cwd }).skills)
    .toEqual(["research-manuscript-sync"]);
});

test("secret-bearing project files require dev-security", () => {
  const rails = createGuardrails("opencode");
  for (const path of [".envrc", "certs/server.pem", "config/credentials.json", "config/secrets.yaml"]) {
    expect(rails.evaluate({ tool: "write", paths: [path], cwd }).skills).toEqual(["dev-security"]);
  }
});

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

test("git commit requires dev-git skill", () => {
  const rails = createGuardrails("opencode");
  const event = { tool: "bash", command: "git commit -m ok", cwd };
  expect(rails.evaluate(event).skills).toEqual(["dev-git"]);
  expect(rails.evaluate(event, ["dev-git"]).decision).toBe("allow");
});

test("spawning a subagent requires agent-orchestration skill", () => {
  const rails = createGuardrails("claude");
  for (const tool of ["Task", "Agent", "task"]) {
    expect(rails.evaluate({ tool, cwd }).skills).toEqual(["agent-orchestration"]);
    expect(rails.evaluate({ tool, cwd }, ["agent-orchestration"]).decision).toBe("allow");
  }
  // a tool whose name merely contains "task"/"agent" is not a delegation
  for (const tool of ["TaskOutput", "AgentOutput"]) {
    expect(rails.evaluate({ tool, cwd }).decision).toBe("allow");
  }
});

test("codex missing-skill message names the canonical skill path", () => {
  const rails = createGuardrails("codex");
  const r = rails.evaluate({ tool: "bash", command: "git commit -m ok", cwd });
  expect(r.skill).toBe("dev-git");
  expect(r.reason).toContain("skills/<name>/SKILL.md");
});

test("root markdown and project notes writes require project-docs skill", () => {
  const rails = createGuardrails("opencode");
  for (const path of ["PLAN.md", "README.md", "notes/claim.html"]) {
    expect(rails.evaluate({ tool: "write", paths: [path], cwd }).skills)
      .toEqual(["context-project-docs"]);
  }
});

test("academic-source tool names require research-protocol without provider coupling", () => {
  const rails = createGuardrails("opencode");
  const event = toolEventFromInput("mcp__catalog__search_papers", {}, cwd);
  expect(rails.evaluate(event).skills).toEqual(["research-protocol"]);
});

test("a test command requires dev-verification anywhere", () => {
  const rails = createGuardrails("opencode");
  for (const command of ["pytest", "pytest tests/test_foo.py -x", "npx vitest run"]) {
    expect(rails.evaluate({ tool: "bash", command, cwd }).skills)
      .toEqual(["dev-verification"]);
  }
});

test("test commands in a git worktree require dev-worktree AND dev-verification", () => {
  const worktree = mkdtempSync(join(tmpdir(), "guardrails-worktree-"));
  writeFileSync(join(worktree, ".git"), "gitdir: /tmp/main/.git/worktrees/test\n");

  // Both capability gates key on `test-command`; the worktree one additionally
  // needs `git-worktree`, so inside a worktree they fire together rather than
  // the narrower one replacing the broader.
  // Sorted: which of the two comes first is only their order in
  // skill-gates.json, so asserting it verbatim reds on a harmless reorder.
  const rails = createGuardrails("opencode");
  expect([...rails.evaluate({ tool: "bash", command: "pytest", cwd: worktree }).skills].sort())
    .toEqual(["dev-verification", "dev-worktree"]);
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

test("Codex registers guardrails only where they evaluate, and the checkpoint per turn", () => {
  const hooks = JSON.parse(readFileSync(join(import.meta.dir, "../hooks.json"), "utf8"));
  const commandsFor = (event: string) =>
    (hooks.hooks[event] ?? []).flatMap((entry: { hooks?: { command?: string }[] }) =>
      (entry.hooks ?? []).map((hook) => hook.command ?? ""));
  const registers = (event: string, needle: string) =>
    commandsFor(event).some((command: string) => command.includes(needle));
  expect(registers("PreToolUse", "guardrails.ts")).toBe(true);
  expect(registers("PermissionRequest", "guardrails.ts")).toBe(true);
  // A prompt carries no tool event, so the adapter has nothing to evaluate on
  // UserPromptSubmit. What belongs there is the per-turn working-tree snapshot
  // claude gets from .claude/settings.json: allow-all rests on recoverability.
  expect(registers("UserPromptSubmit", "guardrails.ts")).toBe(false);
  expect(registers("UserPromptSubmit", "agent-checkpoint")).toBe(true);
});

test("a search tool's exclusion pattern is not a path it touches", () => {
  const rails = createGuardrails("claude");
  const bash = (command: string) =>
    rails.evaluate(toolEventFromInput("shell", { command }, cwd)).decision;

  // The idiom for AVOIDING the git directory must not be read as touching it.
  // This was the whole false-positive class: every `find` that excluded .git
  // died on the exclusion, while `grep --exclude-dir=.git` passed only because
  // an `=` made its token look like an assignment.
  expect(bash("find . -type f -not -path '*/.git/*'")).toBe("allow");
  expect(bash("find . -path '*/node_modules/*' -prune -o -type f -print")).toBe("allow");
  expect(bash("fd . -E .git")).toBe("allow");

  // A pattern that feeds a deletion or an exec is still judged on its target.
  expect(bash("find . -path '*/.git/*' -delete")).toBe("deny");
  expect(bash("find . -not -path '*/.git/*' -exec rm {} ;")).toBe("deny");

  // Writing into the git directory is untouched by the relaxation.
  expect(bash("rm -rf .git")).toBe("deny");
  expect(bash("echo x > .git/config")).toBe("deny");

  // The relaxation is an ALLOWLIST of search tools, so it fails closed: an
  // unrecognized command keeps the old, stricter reading of every token.
  expect(bash("tar -cf a.tar --exclude .git .")).toBe("deny");

  // Credentials are matched before any of this and are unaffected.
  expect(bash("find ~/.ss" + "h -name 'id_*'")).toBe("deny");
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
  expect(hit.skills).toEqual(["research-manuscript-workflow"]);

  const miss = rails.evaluate({
    tool: "bash",
    command: "git subtree push --prefix=docs origin main",
    cwd,
  });
  expect(miss.decision).toBe("allow");

  expect(rails.evaluate({ tool: "bash", command: "make overleaf-push", cwd }).skills)
    .toEqual(["research-manuscript-workflow"]);
});

test("secret-bearing project files require dev-security", () => {
  const rails = createGuardrails("opencode");
  for (const path of [".envrc", "certs/server.pem", "config/credentials.json", "config/secrets.yaml"]) {
    expect(rails.evaluate({ tool: "write", paths: [path], cwd }).skills).toEqual(["dev-security"]);
  }
});

// Machinery in a BASH command relaxes inside the sandbox only, where
// machinery-ro pins the same paths read-only at the kernel and
// `sandbox --verify-pins` re-checks that every prompt. `inSandbox` is passed
// explicitly so this pins behaviour rather than wherever the suite happens to
// run; nothing reads an environment variable for it, because an agent can set
// one of those.
test("machinery is denied in bash outside the sandbox, allowed inside", () => {
  const path = "~/dotfiles/.agents/guardrails/core.ts";
  const outside = createGuardrails("claude", { inSandbox: false });
  const inside = createGuardrails("claude", { inSandbox: true });

  expect(outside.evaluate({ tool: "bash", command: `cat ${path}`, cwd }).decision).toBe("deny");
  expect(inside.evaluate({ tool: "bash", command: `cat ${path}`, cwd }).decision).toBe("allow");

  // The relaxation is bash-only: a typed write to machinery stays denied in
  // both modes, which is what actually protects the enforcement stack.
  for (const rails of [outside, inside]) {
    expect(rails.evaluate({ tool: "write", paths: [path], cwd }).decision).toBe("deny");
  }
});

test("credentials are never relaxed by the sandbox check", () => {
  const secret = "~/.local/share/pass/aalto.gpg";
  for (const inSandbox of [true, false]) {
    const rails = createGuardrails("claude", { inSandbox });
    expect(rails.evaluate({ tool: "bash", command: `cat ${secret}`, cwd }).decision).toBe("deny");
    expect(rails.evaluate({ tool: "read", paths: [secret], cwd }).decision).toBe("deny");
  }
});

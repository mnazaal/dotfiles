import { expect, test } from "bun:test";
import { createGuardrails, toolEventFromInput } from "../../../.agents/guardrails/core.ts";

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
  expect(rails.evaluate(event).skill).toBe("dev-git");
  expect(rails.evaluate(event, ["dev-git"]).decision).toBe("allow");
});

test("root markdown write requires project-docs skill", () => {
  const rails = createGuardrails("opencode");
  const r = rails.evaluate({ tool: "write", paths: ["PLAN.md"], cwd });
  expect(r.skill).toBe("context-project-docs");
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

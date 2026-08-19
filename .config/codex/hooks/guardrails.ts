/**
 * Codex guardrail hook — adapter over the shared ~/.agents/guardrails core.
 *
 * This file owns only Codex I/O: stdin, the session key, and Codex hook response
 * shapes. Policy, tool-event normalization, and the skill-receipt store live in
 * core.ts.
 */
import { readFileSync } from "node:fs";
import { createGuardrails, skillReceipts, skillStateStore, toolEventFromInput } from "../../../.agents/guardrails/core.ts";

type HookInput = {
  session_id?: string;
  cwd?: string;
  hook_event_name?: string;
  tool_name?: string;
  tool_input?: Record<string, unknown>;
};

function readStdin(): HookInput {
  const raw = readFileSync(0, "utf8").trim();
  return raw ? JSON.parse(raw) : {};
}

function denyPreTool(reason: string) {
  return {
    hookSpecificOutput: {
      hookEventName: "PreToolUse",
      permissionDecision: "deny",
      permissionDecisionReason: reason,
    },
  };
}

function denyPermission(reason: string) {
  return {
    hookSpecificOutput: {
      hookEventName: "PermissionRequest",
      decision: { behavior: "deny", message: reason },
    },
  };
}

function maybeDecision(event: string | undefined, reason: string) {
  if (event === "PermissionRequest") return denyPermission(reason);
  return denyPreTool(reason);
}

async function main() {
  const input = readStdin();
  const state = skillStateStore("codex", input.session_id ?? "unknown");
  const loadedSkills = state.load();
  for (const s of skillReceipts(input.tool_name, input.tool_input)) loadedSkills.add(s);
  state.save(loadedSkills);

  const rails = createGuardrails("codex");
  const event = toolEventFromInput(input.tool_name, input.tool_input, input.cwd ?? process.cwd());
  const r = rails.evaluate(event, loadedSkills);
  if (r.decision !== "allow") {
    console.log(JSON.stringify(maybeDecision(input.hook_event_name, r.reason ?? "blocked by shared guardrails")));
  }
}

main().catch((err) => {
  console.error(err instanceof Error ? err.message : String(err));
  process.exit(2);
});

/**
 * Codex guardrail hook — adapter over the shared ~/.agents/guardrails core.
 *
 * This file owns only Codex I/O: stdin, per-session skill evidence, and Codex
 * hook response shapes. Policy and tool-event normalization live in core.ts.
 */
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, resolve } from "node:path";
import { createGuardrails, skillMentions, toolEventFromInput } from "../../../.agents/guardrails/core.ts";

type HookInput = {
  session_id?: string;
  cwd?: string;
  hook_event_name?: string;
  tool_name?: string;
  tool_input?: Record<string, unknown>;
  prompt?: string;
};

function readStdin(): HookInput {
  const raw = readFileSync(0, "utf8").trim();
  return raw ? JSON.parse(raw) : {};
}

function statePath(sessionId: string): string {
  const root = process.env.XDG_STATE_HOME ?? resolve(homedir(), ".local/state");
  return resolve(root, "codex/guardrails", `${sessionId}.json`);
}

function loadSkillState(sessionId: string): Set<string> {
  const p = statePath(sessionId);
  if (!existsSync(p)) return new Set();
  try {
    const parsed = JSON.parse(readFileSync(p, "utf8"));
    return new Set(Array.isArray(parsed.loadedSkills) ? parsed.loadedSkills : []);
  } catch {
    return new Set();
  }
}

function saveSkillState(sessionId: string, loadedSkills: Set<string>) {
  const p = statePath(sessionId);
  try {
    mkdirSync(dirname(p), { recursive: true });
    writeFileSync(p, JSON.stringify({ loadedSkills: [...loadedSkills].sort() }, null, 2));
  } catch {
    // Guard decisions still run if state cannot be persisted; gates just become stricter.
  }
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

function blockPrompt(reason: string) {
  return { decision: "block", reason };
}

function maybeDecision(event: string | undefined, reason: string) {
  if (event === "PermissionRequest") return denyPermission(reason);
  if (event === "UserPromptSubmit") return blockPrompt(reason);
  return denyPreTool(reason);
}

async function main() {
  const input = readStdin();
  const sessionId = input.session_id ?? "unknown";
  const loadedSkills = loadSkillState(sessionId);
  for (const s of skillMentions(JSON.stringify(input))) loadedSkills.add(s);
  saveSkillState(sessionId, loadedSkills);

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

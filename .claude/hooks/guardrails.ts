#!/usr/bin/env bun
/** Claude Code PreToolUse adapter for the shared guardrails core. */
import { createHash } from "node:crypto";
import { createGuardrails, skillReceipts, skillStateStore, toolEventFromInput } from "../../.agents/guardrails/core.ts";

const rails = createGuardrails("claude");

let data: any;
try {
  data = JSON.parse(await Bun.stdin.text());
} catch {
  console.error("Claude guardrail hook received invalid input");
  process.exit(2);
}

const tool = data.tool_name ?? "";
const ti = data.tool_input ?? {};
const event = toolEventFromInput(tool, ti, data.cwd ?? process.cwd());

// Keyed by a hash of the transcript path: it identifies the session without
// putting a filesystem path into a filename.
const transcript = String(data.transcript_path ?? "");
const state = skillStateStore("claude", transcript ? createHash("sha256").update(transcript).digest("hex") : undefined);
const loadedSkills = state.load();
for (const skill of skillReceipts(tool, ti)) loadedSkills.add(skill);
state.save(loadedSkills);

const r = rails.evaluate(event, loadedSkills);
if (r.decision === "allow") process.exit(0);

console.log(JSON.stringify({
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: r.decision,
    permissionDecisionReason: `${r.reason} — ${(event.command ?? event.paths?.[0] ?? event.urls?.[0] ?? "").slice(0, 80)}`,
  },
}));
process.exit(0);

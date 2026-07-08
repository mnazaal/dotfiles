#!/usr/bin/env bun
/** Claude Code PreToolUse adapter for the shared guardrails core. */
import { readFileSync } from "node:fs";
import { createGuardrails, skillMentions, toolEventFromInput } from "../../.agents/guardrails/core.ts";

const rails = createGuardrails("claude");

let data: any;
try {
  data = JSON.parse(await Bun.stdin.text());
} catch {
  process.exit(0);
}

const tool = data.tool_name ?? "";
const ti = data.tool_input ?? {};
const event = toolEventFromInput(tool, ti, data.cwd ?? process.cwd());

let loadedSkills = new Set<string>();
try {
  loadedSkills = skillMentions(readFileSync(String(data.transcript_path ?? ""), "utf8"));
} catch {}

const r = rails.evaluate(event, loadedSkills);
if (r.decision === "allow") process.exit(0);

console.log(JSON.stringify({
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: r.decision,
    permissionDecisionReason: `${r.reason} — ${(event.command ?? event.path ?? event.paths?.[0] ?? event.url ?? event.urls?.[0] ?? "").slice(0, 80)}`,
  },
}));
process.exit(0);

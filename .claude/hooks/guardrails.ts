#!/usr/bin/env bun
/** Claude Code PreToolUse adapter for the shared guardrails core. */
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, writeFileSync } from "node:fs";
import { homedir } from "node:os";
import { dirname, resolve } from "node:path";
import { createGuardrails, skillReceipts, toolEventFromInput } from "../../.agents/guardrails/core.ts";

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

function statePath(transcriptPath: string): string | undefined {
  if (!transcriptPath) return undefined;
  const root = process.env.XDG_STATE_HOME ?? resolve(homedir(), ".local/state");
  const id = createHash("sha256").update(transcriptPath).digest("hex");
  return resolve(root, "claude/guardrails", `${id}.json`);
}

function loadSkillState(path: string | undefined): Set<string> {
  if (!path || !existsSync(path)) return new Set();
  try {
    const parsed = JSON.parse(readFileSync(path, "utf8"));
    return new Set(Array.isArray(parsed.loadedSkills) ? parsed.loadedSkills : []);
  } catch {
    return new Set();
  }
}

function saveSkillState(path: string | undefined, loadedSkills: Set<string>) {
  if (!path) return;
  try {
    mkdirSync(dirname(path), { recursive: true });
    writeFileSync(path, JSON.stringify({ loadedSkills: [...loadedSkills].sort() }, null, 2));
  } catch {
    // A persistence failure makes later gates stricter rather than failing open.
  }
}

const state = statePath(String(data.transcript_path ?? ""));
const loadedSkills = loadSkillState(state);
for (const skill of skillReceipts(tool, ti)) loadedSkills.add(skill);
saveSkillState(state, loadedSkills);

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

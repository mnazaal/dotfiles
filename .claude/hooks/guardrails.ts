#!/usr/bin/env bun
/**
 * Guardrail adapter for Claude Code — thin bun CLI PreToolUse hook.
 *
 * All logic + data live in ~/.agents/guardrails/ (core.ts + the JSON files),
 * shared with pi and opencode. This script reads the PreToolUse JSON on stdin,
 * calls core.evaluate(), and emits Claude's hookSpecificOutput decision (deny or
 * ask) or exits 0 (allow). Replaces dangerous-bash.py + sensitive-paths.py.
 *
 * Wired in settings.json as:  bun "$HOME/.claude/hooks/guardrails.ts"
 * Errors fail open (the wrapper in settings.json falls through to exit 0), since
 * this is defense-in-depth; the sandbox is the real boundary.
 */
import { readFileSync } from "node:fs";
import { createGuard, createSkillGate, skillMentions } from "../../.agents/guardrails/core.ts";

const guard = createGuard("claude");
const skillGate = createSkillGate();

let data: any;
try {
  data = JSON.parse(await Bun.stdin.text());
} catch {
  process.exit(0);
}

const tool = data.tool_name ?? "";
const ti = data.tool_input ?? {};
const cwd = data.cwd ?? process.cwd();
const command = tool === "Bash" ? String(ti.command ?? "") : undefined;
const path = (ti.file_path ?? ti.path ?? ti.notebook_path) as string | undefined;
const url = tool === "WebFetch" ? (ti.url as string | undefined) : undefined;

if (!command && !path && !url) process.exit(0);

const r = guard.evaluate({ command, path, cwd });
if (r.decision === "allow") {
  // Skill gate (skill-gates.json): session evidence = transcript scan for a
  // Skill-tool invocation or SKILL.md read. Unreadable transcript → fail open.
  const hit = skillGate.requiredSkill({ command, tool, path, url, cwd });
  if (hit) {
    let loaded = true;
    try {
      loaded = skillMentions(readFileSync(String(data.transcript_path ?? ""), "utf8")).has(hit.skill);
    } catch {}
    if (!loaded) {
      console.log(JSON.stringify({
        hookSpecificOutput: {
          hookEventName: "PreToolUse",
          permissionDecision: "deny",
          permissionDecisionReason: `skill gate: ${hit.message}. Invoke the Skill tool (skill: ${hit.skill}), then re-run this command.`,
        },
      }));
    }
  }
  process.exit(0);
}

console.log(JSON.stringify({
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: r.decision, // "deny" | "ask"
    permissionDecisionReason: `${r.reason} — ${(command ?? path ?? "").slice(0, 80)}`,
  },
}));
process.exit(0);

#!/usr/bin/env bun
/** Claude Code PreToolUse adapter for the shared guardrails core. */
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { homedir } from "node:os";
import { resolve } from "node:path";
import { createGuardrails, skillReceipts, skillStateStore, toolEventFromInput } from "../../.agents/guardrails/core.ts";

let data: any;
try {
  data = JSON.parse(await Bun.stdin.text());
} catch {
  console.error("Claude guardrail hook received invalid input");
  process.exit(2);
}

const tool = data.tool_name ?? "";
const ti = data.tool_input ?? {};

/**
 * The core relaxes the machinery-in-bash rule only inside a container it can
 * see (/run/.containerenv). Claude Code's own sandbox is bubblewrap and leaves
 * no marker, yet its denyWrite list pins the same paths at the kernel for every
 * Bash call -- so the rule fired where it protected nothing and denied honest
 * reads. The decision is read from settings.json, which is machinery-pinned
 * and so not agent-forgeable; a project-local override that disables the
 * sandbox is honoured too (an agent can write settings.local.json). The rule
 * stays armed for the one call that opts out (dangerouslyDisableSandbox).
 * Not covered: a user launching with `--settings` that disables the sandbox --
 * that is a user action outside the model-error threat model.
 */
function sandboxSetting(path: string): boolean | undefined {
  try {
    const s = JSON.parse(readFileSync(path, "utf8"));
    return typeof s?.sandbox?.enabled === "boolean" ? s.sandbox.enabled : undefined;
  } catch {
    return undefined;
  }
}
function nativeSandboxActive(cwd: string): boolean {
  const user = resolve(homedir(), ".claude/settings.json");
  let enabled = false;
  try {
    const s = JSON.parse(readFileSync(user, "utf8"));
    enabled = s?.sandbox?.enabled === true && s?.sandbox?.failIfUnavailable === true;
  } catch {
    return false;
  }
  for (const local of [resolve(cwd, ".claude/settings.json"), resolve(cwd, ".claude/settings.local.json")]) {
    if (sandboxSetting(local) === false) return false;
  }
  return enabled;
}
const cwd = data.cwd ?? process.cwd();
const inSandbox = tool === "Bash" && ti.dangerouslyDisableSandbox !== true && nativeSandboxActive(cwd) ? true : undefined;
const rails = createGuardrails("claude", { inSandbox });
const event = toolEventFromInput(tool, ti, cwd);

// Keyed by a hash of the transcript path: it identifies the session without
// putting a filesystem path into a filename.
const transcript = String(data.transcript_path ?? "");
const state = skillStateStore("claude", transcript ? createHash("sha256").update(transcript).digest("hex") : undefined);
const loadedSkills = state.load();
for (const skill of skillReceipts(tool, ti)) loadedSkills.add(skill);
state.save(loadedSkills);

const r = rails.evaluate(event, loadedSkills);
if (r.decision === "allow") process.exit(0);

// Capability gates (e.g. subagent delegation) carry no command, path or URL,
// so only append the offending context when there is one.
const context = (event.command ?? event.paths?.[0] ?? event.urls?.[0] ?? "").slice(0, 80);
console.log(JSON.stringify({
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: r.decision,
    permissionDecisionReason: context ? `${r.reason} — ${context}` : r.reason,
  },
}));
process.exit(0);

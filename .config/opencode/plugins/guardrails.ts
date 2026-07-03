/**
 * Guardrail plugin for opencode — thin wiring over the shared core.
 *
 * All logic + data live in ~/.agents/guardrails/ (core.ts + the JSON files),
 * shared with Claude and pi. opencode auto-loads files in this plugins/ dir at
 * startup. A plugin can only block (throw) from tool.execute.before — it cannot
 * prompt — so any non-allow decision (deny OR ask) becomes a hard block here.
 * That makes opencode strictly enforced from the same JSONs; the hand-maintained
 * permission.read / permission.bash blocks in opencode.jsonc become redundant
 * once this is confirmed loading.
 */
import { resolve } from "node:path";
import { homedir } from "node:os";
import { existsSync } from "node:fs";

async function loadCore() {
  for (const p of [
    resolve(homedir(), ".agents/guardrails/core.ts"),
    resolve(homedir(), "dotfiles/.agents/guardrails/core.ts"),
  ]) {
    if (existsSync(p)) return import(p);
  }
  throw new Error("guardrails: core.ts not found");
}

export const Guardrails = async () => {
  const { createGuard, createSkillGate, skillMentions } = await loadCore();
  const guard = createGuard("opencode");
  const skillGate = createSkillGate();
  // Session evidence for the skill gate: skills load through tool calls (a
  // read of .../skills/<name>/SKILL.md or a skill-tool input), so watching
  // every tool payload in-process is the ledger of loaded skills.
  const loadedSkills = new Set<string>();
  return {
    "tool.execute.before": async (input: any, output: any) => {
      const args = output?.args ?? {};
      for (const s of skillMentions(JSON.stringify({ tool: input?.tool, args })))
        loadedSkills.add(s);
      const cwd = process.cwd();
      const command = input?.tool === "bash" ? (args.command as string | undefined) : undefined;
      const path = (args.filePath ?? args.path ?? args.file ?? args.directory) as string | undefined;
      const url = args.url as string | undefined;
      if (!command && !path && !url) return;
      const r = guard.evaluate({ command, path, cwd });
      if (r.decision !== "allow") {
        throw new Error(`guardrail blocked ${input?.tool}: ${r.reason}`);
      }
      const hit = skillGate.requiredSkill({ command, tool: input?.tool, path, url, cwd });
      if (hit && !loadedSkills.has(hit.skill)) {
        throw new Error(`skill gate: ${hit.message}. Read ~/.agents/skills/${hit.skill}/SKILL.md, then retry.`);
      }
    },
  };
};

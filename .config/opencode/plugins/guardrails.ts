/**
 * Guardrail plugin for opencode — thin wiring over the shared core.
 *
 * All logic + data live in ~/.agents/guardrails/ (core.ts + the JSON files),
 * shared with Claude, Codex, and pi. opencode auto-loads files in this plugins/ dir at
 * startup. A plugin can only block (throw) from tool.execute.before — it cannot
 * prompt — so any non-allow decision (deny OR ask) becomes a hard block here.
 * That makes opencode strictly enforced from the same JSONs; the hand-maintained
 * permission.read / permission.bash blocks in opencode.jsonc become redundant
 * once this is confirmed loading.
 */
import { createGuardrails, skillMentions, toolEventFromInput } from "../../../.agents/guardrails/core.ts";

export const Guardrails = async () => {
  const rails = createGuardrails("opencode");
  // Session evidence for the skill gate: skills load through tool calls (a
  // read of .../skills/<name>/SKILL.md or a skill-tool input), so watching
  // every tool payload in-process is the ledger of loaded skills.
  const loadedSkills = new Set<string>();
  return {
    "tool.execute.before": async (input: any, output: any) => {
      const args = output?.args ?? {};
      for (const s of skillMentions(JSON.stringify({ tool: input?.tool, args })))
        loadedSkills.add(s);
      const r = rails.evaluate(toolEventFromInput(input?.tool, args, process.cwd()), loadedSkills);
      if (r.decision !== "allow") {
        throw new Error(`guardrail blocked ${input?.tool}: ${r.reason}`);
      }
    },
  };
};

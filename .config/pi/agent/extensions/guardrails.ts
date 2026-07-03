/**
 * Guardrail adapter for pi — thin wiring over the shared core.
 *
 * All logic + data live in ~/.agents/guardrails/ (core.ts + the JSON files),
 * shared with Claude and opencode. This file only maps pi's tool_call event to
 * core.evaluate() and maps the decision back to pi's block/prompt model.
 *
 * Replaces the former permission-gate.ts + sensitive-paths.ts.
 *
 * The core is imported by a relative path that resolves the same in the deployed
 * tree (~/.config/pi/agent/extensions → ~/.agents/guardrails) and the ~/dotfiles
 * stow source, so no per-host absolute path is baked in.
 */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { createGuard, createSkillGate, skillMentions } from "../../../../.agents/guardrails/core.ts";

const guard = createGuard("pi");
const skillGate = createSkillGate();

export default function (pi: ExtensionAPI) {
  // Session evidence for the skill gate: skills load through tool calls (a
  // read of .../skills/<name>/SKILL.md or a skill-tool input), so watching
  // every tool_call payload in-process is the ledger of loaded skills.
  const loadedSkills = new Set<string>();

  pi.on("tool_call", async (event, ctx) => {
    for (const s of skillMentions(JSON.stringify({ tool: event.toolName, input: event.input ?? {} })))
      loadedSkills.add(s);

    const cwd = ctx.cwd ?? process.cwd();
    const command = event.toolName === "bash" ? String(event.input.command ?? "") : undefined;
    const path = (event.input.path ?? event.input.file ?? event.input.directory) as string | undefined;
    const url = event.input.url as string | undefined;
    if (!command && !path && !url) return undefined;

    const r = guard.evaluate({ command, path, cwd });
    if (r.decision === "allow") {
      const hit = skillGate.requiredSkill({ command, tool: event.toolName, path, url, cwd });
      if (hit && !loadedSkills.has(hit.skill))
        return { block: true, reason: `skill gate: ${hit.message}. Read ~/.agents/skills/${hit.skill}/SKILL.md, then retry.` };
      return undefined;
    }
    if (r.decision === "deny") return { block: true, reason: `Blocked ${event.toolName}: ${r.reason}` };

    // ask: prompt when there's a UI, else fail closed.
    if (!ctx.hasUI) return { block: true, reason: `Blocked ${event.toolName} (no UI): ${r.reason}` };
    const choice = await ctx.ui.select(`⚠️  ${r.reason}:\n\n  ${command ?? path}\n\nAllow?`, ["Yes", "No"]);
    if (choice !== "Yes") return { block: true, reason: "Blocked by user" };
    return undefined;
  });
}

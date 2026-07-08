/** pi tool_call adapter for the shared guardrails core. */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { createGuardrails, skillMentions, toolEventFromInput } from "../../../../.agents/guardrails/core.ts";

const rails = createGuardrails("pi");

export default function (pi: ExtensionAPI) {
  const loadedSkills = new Set<string>();

  pi.on("tool_call", async (event, ctx) => {
    for (const s of skillMentions(JSON.stringify({ tool: event.toolName, input: event.input ?? {} })))
      loadedSkills.add(s);

    const guardEvent = toolEventFromInput(event.toolName, event.input, ctx.cwd ?? process.cwd());
    const r = rails.evaluate(guardEvent, loadedSkills);
    if (r.decision === "allow") return undefined;
    if (r.decision === "deny") return { block: true, reason: `Blocked ${event.toolName}: ${r.reason}` };

    // ask: prompt when there's a UI, else fail closed.
    if (!ctx.hasUI) return { block: true, reason: `Blocked ${event.toolName} (no UI): ${r.reason}` };
    const shown = guardEvent.command ?? guardEvent.path ?? guardEvent.paths?.[0] ?? guardEvent.url ?? guardEvent.urls?.[0] ?? "";
    const choice = await ctx.ui.select(`⚠️  ${r.reason}:\n\n  ${shown}\n\nAllow?`, ["Yes", "No"]);
    if (choice !== "Yes") return { block: true, reason: "Blocked by user" };
    return undefined;
  });
}

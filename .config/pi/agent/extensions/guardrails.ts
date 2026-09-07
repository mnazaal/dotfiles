/** pi tool_call adapter for the shared guardrails core. */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { createGuardrails, skillReceipts, toolEventFromInput } from "../../../../.agents/guardrails/core.ts";

// Throws if a policy JSON is missing or malformed; a throw at import aborts pi
// with exit 1. That is a fail-closed launch: a missing or malformed policy
// stops pi rather than starting it unguarded, with no launcher in the way.
const rails = createGuardrails("pi");

// Confine this agent's git history to pi/* branches (the shared git hooks in
// ~/.config/git/hooks read it). Set here, in the process every tool spawns
// from, so no launcher has to: the bash tool spreads process.env per spawn.
process.env.AGENT_BRANCH_PREFIX = "pi";

export default function (pi: ExtensionAPI) {
  const loadedSkills = new Set<string>();

  pi.on("tool_call", async (event, ctx) => {
    for (const s of skillReceipts(event.toolName, event.input ?? {}))
      loadedSkills.add(s);

    const guardEvent = toolEventFromInput(event.toolName, event.input, ctx.cwd ?? process.cwd());
    const r = rails.evaluate(guardEvent, loadedSkills);
    if (r.decision === "allow") return undefined;
    if (r.decision === "deny") return { block: true, reason: `Blocked ${event.toolName}: ${r.reason}` };

    // ask: prompt when there's a UI, else fail closed.
    if (!ctx.hasUI) return { block: true, reason: `Blocked ${event.toolName} (no UI): ${r.reason}` };
    const shown = guardEvent.command ?? guardEvent.paths?.[0] ?? guardEvent.urls?.[0] ?? "";
    const choice = await ctx.ui.select(`⚠️  ${r.reason}:\n\n  ${shown}\n\nAllow?`, ["Yes", "No"]);
    if (choice !== "Yes") return { block: true, reason: "Blocked by user" };
    return undefined;
  });
}

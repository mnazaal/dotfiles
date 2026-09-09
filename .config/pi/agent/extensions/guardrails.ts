/** pi tool_call adapter for the shared guardrails core. */
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { createGuardrails, skillReceipts, toolEventFromInput } from "../../../../.agents/guardrails/core.ts";

// Throws if a policy JSON is missing or malformed; a throw at import aborts pi
// with exit 1. That is a fail-closed launch: a missing or malformed policy
// stops pi rather than starting it unguarded, with no launcher in the way.
const rails = createGuardrails("pi");

// Confine this agent's git history to pi/* branches (the shared git hooks in
// ~/.config/git/hooks read it). Set here, in the process every tool spawns
// from, so no launcher has to: the bash tool spreads process.env per spawn.
process.env.AGENT_BRANCH_PREFIX = "pi";

const execFileAsync = promisify(execFile);
const CHECKPOINT = `${process.env.HOME}/.local/scripts/agent-checkpoint`;

// Snapshot the working tree. node:child_process, not the package's own
// execCommand: that lives in dist/core/exec.d.ts and is NOT in the exports map
// (only "." and "./hooks" are), so a deep import would be refused at runtime.
//
// Returns the script's exit status. Nonzero means the work is NOT captured,
// which is the premise the allow tier rests on. A missing or non-executable
// script rejects with ENOENT/EACCES and is also "not captured" -- that is the
// case a bare `[ -x "$f" ] || exit 0` silently swallowed on the Claude side.
async function checkpoint(cwd: string): Promise<number> {
  try {
    const { stderr } = await execFileAsync(CHECKPOINT, [], { cwd, timeout: 15000 });
    if (stderr?.trim()) console.error(stderr.trim());
    return 0;
  } catch (e: any) {
    if (e?.stderr?.trim()) console.error(e.stderr.trim());
    else console.error(`agent-checkpoint: could not run ${CHECKPOINT}: ${e?.message ?? e}`);
    return typeof e?.code === "number" ? e.code : 1;
  }
}

export default function (pi: ExtensionAPI) {
  const loadedSkills = new Set<string>();

  // Per-turn snapshot. turn_start is ExtensionHandler<TurnStartEvent> with the
  // default result type, so it CANNOT refuse a turn -- advisory by
  // construction. The gating half lives in tool_call below, which can block.
  pi.on("turn_start", async (_event, ctx) => {
    await checkpoint(ctx.cwd ?? process.cwd());
  });

  pi.on("tool_call", async (event, ctx) => {
    for (const s of skillReceipts(event.toolName, event.input ?? {}))
      loadedSkills.add(s);

    const cwd = ctx.cwd ?? process.cwd();

    // Before a Bash call, snapshot and refuse if nothing was captured. This is
    // pi's analogue of Claude Code's PreToolUse Bash hook: the allow tier for
    // destructive verbs is earned by the snapshot existing, so a failed
    // snapshot blocks rather than warns.
    if (event.toolName === "bash" && (await checkpoint(cwd)) !== 0)
      return { block: true, reason: "agent-checkpoint failed: uncommitted work is not recoverable" };

    const guardEvent = toolEventFromInput(event.toolName, event.input, cwd);
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

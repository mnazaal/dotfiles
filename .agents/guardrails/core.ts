/**
 * Guardrail core — the single implementation of the agent bash/path guards.
 *
 * Consumed at runtime by all three harnesses via dynamic import:
 *   - Claude  : .claude/hooks/guardrails.ts          (bun CLI PreToolUse hook)
 *   - pi      : .config/pi/agent/extensions/guardrails.ts
 *   - opencode: .config/opencode/plugins/guardrails.ts
 *
 * Data lives in sibling JSON files (sensitive-paths.json, dangerous-commands.json);
 * this file owns the LOGIC. No third-party deps — only node/bun builtins — so it
 * loads identically in every harness runtime. No regex; plain string parsing,
 * quote/segment/wrapper aware, recurses into `sh -c`.
 *
 * Entry point: createGuard(agent).evaluate({ command?, path?, cwd }) -> Decision.
 */
import { readFileSync, existsSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { homedir } from "node:os";

const HOME = homedir();

export type Decision = { decision: "deny" | "ask" | "allow"; reason?: string };

// --- shared JSON loading ----------------------------------------------------
// Try the deployed copy first, then the ~/dotfiles stow source (works pre-deploy
// and on hosts without the symlink). Fails open with a loud stderr line.
function loadJson(name: string): any {
  const candidates = [
    resolve(HOME, ".agents/guardrails", name),
    resolve(HOME, "dotfiles/.agents/guardrails", name),
  ];
  for (const p of candidates) {
    if (!existsSync(p)) continue;
    try {
      return JSON.parse(readFileSync(p, "utf8"));
    } catch (e) {
      console.error(`guardrails: failed to parse ${p}: ${e}`);
      return {};
    }
  }
  console.error(`guardrails: no ${name} found (${candidates.join(", ")})`);
  return {};
}

function machineryOn(spec: unknown, agent: string): boolean {
  if (spec && typeof spec === "object") return Boolean((spec as Record<string, unknown>)[agent] ?? true);
  return spec === undefined || spec === null ? true : Boolean(spec);
}

// --- stateless string helpers (no config dependency) ------------------------

/** Split on ; && || | & and newlines, respecting simple quotes. */
function splitSegments(cmd: string): string[] {
  const out: string[] = [];
  let start = 0, inSQ = false, inDQ = false;
  for (let i = 0; i <= cmd.length; i++) {
    const ch = cmd[i] ?? "";
    if (inSQ) { if (ch === "'") inSQ = false; continue; }
    if (inDQ) { if (ch === '"') inDQ = false; continue; }
    if (ch === "'") { inSQ = true; continue; }
    if (ch === '"') { inDQ = true; continue; }
    const two = (ch === "&" && cmd[i + 1] === "&") || (ch === "|" && cmd[i + 1] === "|");
    if (i === cmd.length || two || ch === "\n" || ch === ";" || ch === "&" || ch === "|") {
      const seg = cmd.slice(start, i);
      if (seg.trim()) out.push(seg);
      start = i + (two ? 2 : 1);
    }
  }
  return out;
}

/** Tokenize one segment, stripping quotes. */
function tokenize(seg: string): string[] {
  const out: string[] = [];
  let cur = "", inSQ = false, inDQ = false;
  for (const ch of seg) {
    if (inSQ) { if (ch === "'") inSQ = false; else cur += ch; continue; }
    if (inDQ) { if (ch === '"') inDQ = false; else cur += ch; continue; }
    if (ch === "'") { inSQ = true; continue; }
    if (ch === '"') { inDQ = true; continue; }
    if (ch === " " || ch === "\t") { if (cur) { out.push(cur); cur = ""; } }
    else cur += ch;
  }
  if (cur) out.push(cur);
  return out;
}

/** Tokenize a whole command for path scanning (splits on separators too). */
function pathTokenize(cmd: string): string[] {
  const out: string[] = [];
  let cur = "", inSQ = false, inDQ = false;
  for (const ch of cmd) {
    if (inSQ) { if (ch === "'") inSQ = false; else cur += ch; continue; }
    if (inDQ) { if (ch === '"') inDQ = false; else cur += ch; continue; }
    if (ch === "'") { inSQ = true; continue; }
    if (ch === '"') { inDQ = true; continue; }
    if (" \t\n;|&".includes(ch)) { if (cur) { out.push(cur); cur = ""; } }
    else cur += ch;
  }
  if (cur) out.push(cur);
  return out;
}

function basename(word: string): string {
  const parts = word.split("/");
  return parts[parts.length - 1] || word;
}

function isAssignment(word: string): boolean {
  const eq = word.indexOf("=");
  if (eq <= 0) return false;
  return [...word.slice(0, eq)].every((c, i) =>
    (c >= "A" && c <= "Z") || (c >= "a" && c <= "z") || c === "_" || (i > 0 && c >= "0" && c <= "9"));
}

function hasRmRecursiveForce(args: string[]): boolean {
  let r = false, f = false;
  for (const a of args) {
    if (a === "--recursive") r = true;
    if (a === "--force") f = true;
    if (a.startsWith("-") && !a.startsWith("--")) {
      if (a.includes("r") || a.includes("R")) r = true;
      if (a.includes("f")) f = true;
    }
  }
  return r && f;
}

function firstNonFlag(args: string[]): string {
  for (const a of args) { if (a === "--") continue; if (!a.startsWith("-")) return a; }
  return "";
}

function isWorldWritableMode(arg: string): boolean {
  if (!arg || arg.length > 4) return false;
  if (![...arg].every(c => "01234567".includes(c))) return false;
  return (parseInt(arg, 8) & 0o002) === 0o002;
}

function dashCArg(args: string[]): string | undefined {
  for (let i = 0; i < args.length; i++) {
    if (args[i] === "-c") return args[i + 1];
    if (args[i].startsWith("-c") && !args[i].startsWith("--") && args[i].length > 2) return args[i].slice(2);
  }
  return undefined;
}

function gitConfigKey(token: string): string {
  return token.split("=", 1)[0].trim().toLowerCase();
}

/** Leading command + args of one segment, skipping assignments and wrappers. */
function commandAndArgs(seg: string, wrappers: Set<string>): { command: string; args: string[] } | undefined {
  const toks = tokenize(seg);
  let i = 0;
  while (i < toks.length && isAssignment(toks[i])) i++;
  while (i < toks.length && wrappers.has(basename(toks[i]))) {
    i++;
    while (i < toks.length && toks[i].startsWith("-") && toks[i] !== "--") i++;
    if (toks[i] === "--") i++;
    while (i < toks.length && isAssignment(toks[i])) i++;
  }
  if (i >= toks.length) return undefined;
  return { command: basename(toks[i]), args: toks.slice(i + 1) };
}

/** First non-flag arg, skipping value-taking global options (e.g. git -C <dir>). */
function subcommandOf(args: string[], valueOpts: Set<string>): string {
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (valueOpts.has(a)) { i++; continue; }
    if (a === "--") continue;
    if (a.startsWith("-")) continue;
    return a;
  }
  return "";
}

function resolveAny(input: string, cwd: string): string {
  if (input.startsWith("~/") || input === "~") return resolve(HOME, input === "~" ? "" : input.slice(2));
  if (input.startsWith("$HOME/")) return resolve(HOME, input.slice(6));
  if (input.startsWith("${HOME}/")) return resolve(HOME, input.slice(8));
  if (input.startsWith("/")) return resolve(input);
  return resolve(cwd, input);
}

function hasProtectedSegment(path: string): boolean {
  for (const comp of path.replace(/\\/g, "/").split("/")) {
    if (comp === ".env" || comp.startsWith(".env.")) return true;
    if (comp === ".git" || comp === "node_modules") return true;
  }
  return false;
}

// --- guard factory ----------------------------------------------------------

export function createGuard(agent: string) {
  const sp = loadJson("sensitive-paths.json");
  const dc = loadJson("dangerous-commands.json");

  const sensitive: string[] = [...(sp.credentials ?? [])];
  if (machineryOn(sp.machinery_enabled, agent)) sensitive.push(...(sp.machinery ?? []));
  const segments = new Set<string>(sp.sensitive_segments ?? []);

  const ESCALATORS = new Set<string>(dc.escalators ?? []);
  const DESTRUCTIVE = new Set<string>(dc.destructive ?? []);
  const WRAPPERS = new Set<string>(dc.command_wrappers ?? []);
  const SHELL_RUNNERS = new Set<string>(dc.shell_runners ?? []);
  const FIND_EXEC = new Set<string>(dc.find_exec_primaries ?? []);
  const GIT_REF_WRITE = new Set<string>(dc.git_ref_write_subcmds ?? []);
  const GIT_VALUE_OPTS = new Set<string>(dc.git_global_value_opts ?? []);
  const findPolicy: string = (dc.find_policy ?? {})[agent] ?? "exec";

  // path guard ---------------------------------------------------------------
  function blocked(path: string): string | undefined {
    for (const s of sensitive) {
      const r = s.startsWith("~/") ? resolve(HOME, s.slice(2)) : resolve(s);
      if (path === r || path.startsWith(r + "/")) return s;
    }
    if (hasProtectedSegment(path)) return "protected";
  }

  function blockedCommand(command: string, cwd: string): string | undefined {
    const norm = command.replaceAll("${HOME}", HOME).replaceAll("$HOME", HOME).replaceAll("~/", `${HOME}/`);
    for (const s of sensitive) {
      const abs = s.startsWith("~/") ? resolve(HOME, s.slice(2)) : resolve(s);
      if (norm.includes(s) || norm.includes(abs)) return s;
    }
    for (const tok of pathTokenize(norm)) {
      if (tok.startsWith("-") || tok.includes("=")) continue;
      for (const comp of tok.replace(/\\/g, "/").split("/")) if (segments.has(comp)) return comp;
      const r = blocked(resolveAny(tok, cwd));
      if (r) return r;
    }
  }

  // command guard ------------------------------------------------------------
  function gitBypassReason(args: string[]): string | undefined {
    let i = 0;
    const n = args.length;
    while (i < n) {
      const a = args[i];
      if (a === "-c") {
        if (i + 1 < n && gitConfigKey(args[i + 1]) === "core.hookspath") return "git hooks bypass (-c core.hooksPath)";
        i += 2; continue;
      }
      if (a.startsWith("-c") && !a.startsWith("--") && a.length > 2) {
        if (gitConfigKey(a.slice(2)) === "core.hookspath") return "git hooks bypass (-c core.hooksPath)";
        i += 1; continue;
      }
      if (a.startsWith("--config-env=") && gitConfigKey(a.slice("--config-env=".length)) === "core.hookspath")
        return "git hooks bypass (--config-env core.hooksPath)";
      if (GIT_VALUE_OPTS.has(a)) { i += 2; continue; }
      if (a.startsWith("-")) { i += 1; continue; }
      const sub = a, rest = args.slice(i + 1);
      if (GIT_REF_WRITE.has(sub)) return `direct git ref op (git ${sub})`;
      if (sub === "config" && rest.some(t => gitConfigKey(t) === "core.hookspath")) return "git hooks bypass (git config core.hooksPath)";
      if (rest.includes("--no-verify")) return "git hook skip (--no-verify)";
      if (sub === "branch" && rest.some(t => t === "-f" || t === "--force" || t === "-D")) return "forced/deleted git branch";
      if (sub === "push" && rest.some(t => t === "-f" || t === "--force" || t === "--delete" || t === "-d" || t.startsWith("--force"))) return "force/delete git push";
      return undefined;
    }
    return undefined;
  }

  function confinementTamperReason(toks: string[]): string | undefined {
    if (toks.includes("AGENT_BRANCH_PREFIX")) {
      if (toks.includes("unset")) return "unsets AGENT_BRANCH_PREFIX (branch confinement)";
      if (toks.includes("env") && toks.includes("-u")) return "strips AGENT_BRANCH_PREFIX (env -u, branch confinement)";
    }
    if (toks.includes("env") && toks.includes("-i")) return "clears env (env -i, branch confinement)";
    for (const t of toks) {
      if (t.startsWith("AGENT_BRANCH_PREFIX=")) return "reassigns AGENT_BRANCH_PREFIX (branch confinement)";
      if (t.startsWith("GIT_CONFIG") && t.includes("=")) return "git config via environment (GIT_CONFIG_*)";
    }
    return undefined;
  }

  function dangerReason(cmd: string): string | undefined {
    for (const seg of splitSegments(cmd)) {
      const tamper = confinementTamperReason(tokenize(seg));
      if (tamper) return tamper;
      const parsed = commandAndArgs(seg, WRAPPERS);
      if (!parsed) continue;
      const { command, args } = parsed;
      if (ESCALATORS.has(command)) return "privilege escalation";
      if (DESTRUCTIVE.has(command)) return "destructive command";
      if (command === "rm" && hasRmRecursiveForce(args)) return "recursive force rm";
      if ((command === "chmod" || command === "chown") && isWorldWritableMode(firstNonFlag(args))) return "world-writable permissions";
      if (command === "git") { const r = gitBypassReason(args); if (r) return r; }
      if (command === "find") {
        if (findPolicy === "always") return "find — prefer grepika/read tools";
        if (findPolicy === "exec" && args.some(a => FIND_EXEC.has(a))) return "find with -exec/-delete";
      }
      if (SHELL_RUNNERS.has(command)) {
        const inner = dashCArg(args);
        if (inner) { const nested = dangerReason(inner); if (nested) return nested; }
      }
    }
    return undefined;
  }

  // unified entry point ------------------------------------------------------
  function evaluate(input: { command?: string; path?: string; cwd: string }): Decision {
    const cwd = input.cwd || HOME;
    if (input.path) {
      const r = blocked(resolveAny(input.path, cwd));
      if (r) return { decision: "deny", reason: `sensitive path (${r})` };
    }
    if (input.command) {
      const r1 = blockedCommand(input.command, cwd);
      if (r1) return { decision: "deny", reason: `sensitive path in command (${r1})` };
      const r2 = dangerReason(input.command);
      if (r2) return { decision: "ask", reason: r2 };
    }
    return { decision: "allow" };
  }

  return { evaluate, _internals: { blocked, blockedCommand, dangerReason, resolveAny } };
}

// --- skill gate ---------------------------------------------------------------

export type SkillGateHit = { skill: string; message: string };

// Gate triggers — one of three, discriminated by `trigger.type`.
type BashTrigger = { type: "bash"; command: string; subcommands?: string[] };
type WriteTrigger = { type: "write"; path_glob: string; at_root?: boolean; except?: string[] };
type FetchTrigger = { type: "fetch"; domains: string[] };
type Gate = { skill: string; message: string; trigger: BashTrigger | WriteTrigger | FetchTrigger };

/** Minimal glob → RegExp: `**` spans path separators, `*` does not. Anchored. */
function globMatch(glob: string, s: string): boolean {
  let re = "";
  for (let i = 0; i < glob.length; i++) {
    const c = glob[i];
    if (c === "*") {
      if (glob[i + 1] === "*") { re += ".*"; i++; } else re += "[^/]*";
    } else if (".+?^${}()|[]\\".includes(c)) {
      re += "\\" + c;
    } else re += c;
  }
  return new RegExp("^" + re + "$").test(s);
}

/**
 * Skill gates (skill-gates.json): observable events that require an agent skill
 * to have been loaded this session. Three trigger types — `bash` (command +
 * optional subcommands), `write` (a Write/Edit path), `fetch` (a WebFetch URL).
 * The core only matches events to gates; the ADAPTER supplies the session
 * evidence ("was the skill loaded?"), since that is host-specific — Claude scans
 * the transcript, pi/opencode watch tool payloads in-process via skillMentions().
 *
 * Every partial/legacy input fails OPEN (returns no hit): a gate missing its
 * `trigger` is dropped from all buckets; a write/fetch event with no matching
 * gate returns undefined. Blocking is never the default.
 */
export function createSkillGate() {
  const dc = loadJson("dangerous-commands.json");
  const sg = loadJson("skill-gates.json");
  const WRAPPERS = new Set<string>(dc.command_wrappers ?? []);
  const SHELL_RUNNERS = new Set<string>(dc.shell_runners ?? []);
  const GIT_VALUE_OPTS = new Set<string>(dc.git_global_value_opts ?? []);
  const NO_OPTS = new Set<string>();
  const gates: Gate[] = sg.gates ?? [];
  const bashGates = gates.filter((g) => g.trigger?.type === "bash") as (Gate & { trigger: BashTrigger })[];
  const writeGates = gates.filter((g) => g.trigger?.type === "write") as (Gate & { trigger: WriteTrigger })[];
  const fetchGates = gates.filter((g) => g.trigger?.type === "fetch") as (Gate & { trigger: FetchTrigger })[];

  function bashHit(command: string): SkillGateHit | undefined {
    for (const seg of splitSegments(command)) {
      const parsed = commandAndArgs(seg, WRAPPERS);
      if (!parsed) continue;
      for (const g of bashGates) {
        const t = g.trigger;
        if (parsed.command !== t.command) continue;
        if (t.subcommands?.length) {
          const sub = subcommandOf(parsed.args, t.command === "git" ? GIT_VALUE_OPTS : NO_OPTS);
          if (!t.subcommands.includes(sub)) continue;
        }
        return { skill: g.skill, message: g.message };
      }
      if (SHELL_RUNNERS.has(parsed.command)) {
        const inner = dashCArg(parsed.args);
        if (inner) { const hit = bashHit(inner); if (hit) return hit; }
      }
    }
    return undefined;
  }

  function writeHit(path: string, cwd: string): SkillGateHit | undefined {
    const abs = resolveAny(path, cwd);
    const base = basename(abs);
    for (const g of writeGates) {
      const t = g.trigger;
      if (t.except?.includes(base)) continue;
      if (t.at_root) {
        if (dirname(abs) !== resolve(cwd)) continue;
        if (!globMatch(t.path_glob, base)) continue;
      } else if (!globMatch(t.path_glob, abs)) continue;
      return { skill: g.skill, message: g.message };
    }
    return undefined;
  }

  function fetchHit(url: string): SkillGateHit | undefined {
    let host: string;
    try { host = new URL(url).hostname.toLowerCase(); } catch { return undefined; }
    for (const g of fetchGates) {
      for (const d of g.trigger.domains) {
        const dd = d.toLowerCase();
        if (host === dd || host.endsWith("." + dd)) return { skill: g.skill, message: g.message };
      }
    }
    return undefined;
  }

  /**
   * Match one tool event. `command` runs the bash gates; a write-capable tool
   * (name contains "write"/"edit") with a `path` runs the write gates; a
   * fetch tool (name contains "fetch"), or any event carrying a `url`, runs the
   * fetch gates. `tool` is the host's tool name (case-insensitive), so the
   * read-vs-write distinction is portable without hardcoding per-host names.
   */
  function requiredSkill(input: { command?: string; tool?: string; path?: string; url?: string; cwd?: string }): SkillGateHit | undefined {
    const cwd = input.cwd || HOME;
    if (input.command) { const h = bashHit(input.command); if (h) return h; }
    const tool = (input.tool ?? "").toLowerCase();
    if (input.path && (tool.includes("write") || tool.includes("edit"))) {
      const h = writeHit(input.path, cwd); if (h) return h;
    }
    if (input.url && (tool === "" || tool.includes("fetch"))) {
      const h = fetchHit(input.url); if (h) return h;
    }
    return undefined;
  }

  return { requiredSkill };
}

/**
 * Scan free text (a stringified tool payload, or a session transcript) for
 * evidence that a skill was loaded: a SKILL.md path, or a `"skill": "<name>"`
 * tool-input pair. This scans prose/JSON, not commands, so the file's
 * no-regex rule (which is about quote-aware command parsing) doesn't apply.
 */
export function skillMentions(text: string): Set<string> {
  const found = new Set<string>();
  for (const m of text.matchAll(/skills\/([A-Za-z0-9_-]+)\/SKILL\.md/g)) found.add(m[1]);
  for (const m of text.matchAll(/"skill"\s*:\s*"([A-Za-z0-9_-]+)"/g)) found.add(m[1]);
  return found;
}

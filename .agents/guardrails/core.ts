/**
 * Guardrail core — the single implementation of the agent bash/path guards.
 *
 * Consumed at runtime by all agent harnesses:
 *   - Claude  : .claude/hooks/guardrails.ts          (bun CLI PreToolUse hook)
 *   - Codex   : .config/codex/hooks/guardrails.ts    (bun CLI hooks)
 *   - pi      : .config/pi/agent/extensions/guardrails.ts
 *   - opencode: .config/opencode/plugins/guardrails.ts
 *
 * Data lives in sibling JSON files (sensitive-paths.json, dangerous-commands.json);
 * this file owns the LOGIC. No third-party deps — only node/bun builtins — so it
 * loads identically in every harness runtime. Command parsing is plain string
 * parsing: quote/segment/wrapper aware, recurses into `sh -c`.
 *
 * Entry point: createGuardrails(agent).evaluate(toolEvent, loadedSkills?) -> Decision.
 */
import { readFileSync, existsSync, statSync, mkdirSync, writeFileSync } from "node:fs";
import { resolve, dirname } from "node:path";
import { homedir } from "node:os";

const HOME = homedir();

export type Decision = { decision: "deny" | "ask" | "allow"; reason?: string };
export type Operation = "read" | "write" | "bash" | "fetch" | "unknown";
export type ToolEvent = {
  command?: string;
  paths?: string[];
  urls?: string[];
  tool?: string;
  cwd?: string;
  operation?: Operation;
};
export type GuardrailDecision = Decision & { skill?: string; skills?: string[] };

// --- shared JSON loading ----------------------------------------------------
// Prefer the deployed copy, then the ~/dotfiles stow source. Everything under
// ~/.agents is a stow symlink into ~/dotfiles, so a harness that can reach one
// tree but not the other (fresh deploy, or a sandbox whose bind of ~/.agents was
// skipped because the path did not exist at launch) must still find its policy.
// Unreachable through BOTH, or malformed, is a launch/configuration failure —
// never an unprotected allow-all policy.
function loadJson(name: string): any {
  const candidates = [
    resolve(HOME, ".agents/guardrails", name),
    resolve(HOME, "dotfiles/.agents/guardrails", name),
  ];
  for (const path of candidates) {
    if (!existsSync(path)) continue;
    try {
      return JSON.parse(readFileSync(path, "utf8"));
    } catch (e) {
      throw new Error(`guardrails: failed to parse ${path}: ${e}`);
    }
  }
  throw new Error(`guardrails: missing ${name} (tried ${candidates.join(", ")})`);
}

/** Policy value for this agent: either one value shared by all, or a per-agent map. */
function perAgent(spec: unknown, agent: string): unknown {
  return spec && typeof spec === "object" ? (spec as Record<string, unknown>)[agent] : spec;
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

/** Split into words on any char of `seps`, stripping quotes. */
function splitWords(s: string, seps: string): string[] {
  const out: string[] = [];
  let cur = "", inSQ = false, inDQ = false;
  for (const ch of s) {
    if (inSQ) { if (ch === "'") inSQ = false; else cur += ch; continue; }
    if (inDQ) { if (ch === '"') inDQ = false; else cur += ch; continue; }
    if (ch === "'") { inSQ = true; continue; }
    if (ch === '"') { inDQ = true; continue; }
    if (seps.includes(ch)) { if (cur) { out.push(cur); cur = ""; } }
    else cur += ch;
  }
  if (cur) out.push(cur);
  return out;
}

/** Tokenize one segment, stripping quotes. */
const tokenize = (seg: string): string[] => splitWords(seg, " \t");

/** Tokenize a whole command for path scanning (splits on separators too). */
const pathTokenize = (cmd: string): string[] => splitWords(cmd, " \t\n;|&");

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

function skipEnvArgs(toks: string[], i: number): number {
  while (i < toks.length) {
    const a = toks[i];
    if (a === "--") return i + 1;
    if (a === "-u" || a === "--unset") { i += 2; continue; }
    if (a === "-C" || a === "--chdir" || a === "-S" || a === "--split-string") { i += 2; continue; }
    if (a === "-i" || a === "-0" || a === "--ignore-environment" || a === "--null") { i++; continue; }
    if (a.startsWith("--unset=") || a.startsWith("--chdir=") || a.startsWith("--split-string=")) { i++; continue; }
    if (isAssignment(a)) { i++; continue; }
    return i;
  }
  return i;
}

function skipTimeoutArgs(toks: string[], i: number): number {
  while (i < toks.length) {
    const a = toks[i];
    if (a === "--") { i++; break; }
    if (["-k", "--kill-after", "-s", "--signal"].includes(a)) { i += 2; continue; }
    if (a.startsWith("--kill-after=") || a.startsWith("--signal=")) { i++; continue; }
    if (a.startsWith("-")) { i++; continue; }
    i++; break; // duration
  }
  return i;
}

function skipNiceArgs(toks: string[], i: number): number {
  while (i < toks.length) {
    const a = toks[i];
    if (a === "--") return i + 1;
    if (a === "-n" || a === "--adjustment") { i += 2; continue; }
    if (a.startsWith("--adjustment=")) { i++; continue; }
    if (a.startsWith("-n") && a.length > 2) { i++; continue; }
    if (a.startsWith("-")) { i++; continue; }
    return i;
  }
  return i;
}

function skipWrapperArgs(wrapper: string, toks: string[], i: number): number {
  if (wrapper === "env") return skipEnvArgs(toks, i);
  if (wrapper === "timeout") return skipTimeoutArgs(toks, i);
  if (wrapper === "nice") return skipNiceArgs(toks, i);
  while (i < toks.length && toks[i].startsWith("-") && toks[i] !== "--") i++;
  if (toks[i] === "--") i++;
  while (i < toks.length && isAssignment(toks[i])) i++;
  return i;
}

/** Leading command + args of one segment, skipping assignments and known wrappers. */
function commandAndArgs(seg: string, wrappers: Set<string>): { command: string; args: string[] } | undefined {
  const toks = tokenize(seg);
  let i = 0;
  while (i < toks.length && isAssignment(toks[i])) i++;
  while (i < toks.length && wrappers.has(basename(toks[i]))) {
    const wrapper = basename(toks[i]);
    i = skipWrapperArgs(wrapper, toks, i + 1);
  }
  if (i >= toks.length) return undefined;
  return { command: basename(toks[i]), args: toks.slice(i + 1) };
}

/** First non-flag arg, skipping value-taking global options (e.g. git -C <dir>). */
function subcommandOf(args: string[], valueOpts?: Set<string>): string {
  for (let i = 0; i < args.length; i++) {
    const a = args[i];
    if (valueOpts?.has(a)) { i++; continue; }
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

/**
 * A recursive-force rm target that would take a whole project, a home, or the
 * filesystem with it. agent-checkpoint refs live in .git *inside* the repo, so
 * deleting a repo root destroys the work and its only recovery in one command.
 *
 * `base` is the effective directory the target resolves against (which `cd`
 * moves); `origin` is the directory the tool call started in. Both are anchors:
 * `cd /tmp && rm -rf project` resolves against /tmp but still destroys origin.
 *
 * Best-effort by design: this guards against model error, not deliberate
 * circumvention, which no amount of string parsing can cover.
 */
function isTopLevelRmTarget(target: string, base: string, origin: string): boolean {
  const resolved = resolveAny(target, base);
  if (resolved === "/" || resolved === HOME) return true;
  // A direct child of $HOME is a project root or top-level store.
  if (resolved.startsWith(HOME + "/") && !resolved.slice(HOME.length + 1).includes("/")) return true;
  for (const anchor of [resolve(base), resolve(origin)]) {
    if (resolved === anchor || anchor.startsWith(resolved + "/")) return true;
  }
  return false;
}

/**
 * Tools that only read the filesystem, and the flags whose argument is a
 * pattern rather than a target. Deliberately an allowlist: an unrecognized
 * command keeps the old, stricter reading of every token.
 */
const SEARCH_TOOLS = new Set(["find", "fd", "fdfind", "rg", "ripgrep", "grep", "egrep", "fgrep", "ag", "ack"]);
const PATTERN_FLAGS = new Set([
  "-path", "-ipath", "-wholename", "-iwholename", "-name", "-iname", "-regex", "-iregex",
  "-E", "--exclude", "--exclude-dir", "--include", "--glob", "-g",
]);

function hasProtectedSegment(path: string, operation: Operation = "unknown"): boolean {
  for (const comp of path.replace(/\\/g, "/").split("/")) {
    if (comp === ".env" || comp.startsWith(".env.")) return true;
    if (operation !== "read" && (comp === ".git" || comp === "node_modules")) return true;
  }
  return false;
}

// --- guard factory ----------------------------------------------------------

export function createGuard(agent: string) {
  const sp = loadJson("sensitive-paths.json");
  const dc = loadJson("dangerous-commands.json");

  const credentials: string[] = [...(sp.credentials ?? [])];
  const protectedWriteGlobs: string[] = [...(sp.protected_write_globs ?? [])];
  // Only an explicit `false` disables machinery protection: an absent or
  // malformed setting must not read as an unprotected default.
  const machinery: string[] = perAgent(sp.machinery_enabled, agent) !== false ? [...(sp.machinery ?? [])] : [];
  const segments = new Set<string>(sp.sensitive_segments ?? []);

  const ESCALATORS = new Set<string>(dc.escalators ?? []);
  const DESTRUCTIVE = new Set<string>(dc.destructive ?? []);
  const WRAPPERS = new Set<string>(dc.command_wrappers ?? []);
  const SHELL_RUNNERS = new Set<string>(dc.shell_runners ?? []);
  const FIND_EXEC = new Set<string>(dc.find_exec_primaries ?? []);
  const GIT_REF_WRITE = new Set<string>(dc.git_ref_write_subcmds ?? []);
  const GIT_VALUE_OPTS = new Set<string>(dc.git_global_value_opts ?? []);
  const findPolicy: string = (perAgent(dc.find_policy, agent) as string) ?? "exec";

  const SEVERITY: Record<string, unknown> = dc.severity ?? {};
  function severityOf(category: string): "deny" | "ask" | "allow" {
    const value = perAgent(SEVERITY[category], agent) as string | undefined;
    return value === "deny" || value === "allow" ? value : "ask";
  }

  // path guard ---------------------------------------------------------------
  function blocked(path: string, operation: Operation = "unknown"): string | undefined {
    for (const s of credentials) {
      const r = s.startsWith("~/") ? resolve(HOME, s.slice(2)) : resolve(s);
      if (path === r || path.startsWith(r + "/")) return s;
    }
    if (hasProtectedSegment(path, operation)) return "protected";
    if (operation !== "read") {
      const normalized = path.replace(/\\/g, "/");
      for (const g of protectedWriteGlobs) {
        if (globMatch(g, normalized)) return `protected write glob (${g})`;
      }
      for (const s of machinery) {
        const r = s.startsWith("~/") ? resolve(HOME, s.slice(2)) : resolve(s);
        if (path === r || path.startsWith(r + "/")) return s;
      }
    }
  }

  function blockedCommand(command: string, cwd: string): string | undefined {
    const norm = command.replaceAll("${HOME}", HOME).replaceAll("$HOME", HOME).replaceAll("~/", `${HOME}/`);
    for (const s of [...credentials, ...machinery]) {
      const abs = s.startsWith("~/") ? resolve(HOME, s.slice(2)) : resolve(s);
      if (norm.includes(s) || norm.includes(abs)) return s;
    }
    // The argument to a search tool's pattern flag is a PATTERN, not a path the
    // command touches: `find . -not -path '*/.git/*'` is the idiom for AVOIDING
    // the git directory, and judging it as a path denies the exclusion for
    // naming what it excludes. Narrowed two ways so it fails closed: only for
    // tools that just search, and only while the invocation carries no primary
    // that can delete or execute — `find . -path '*/.git/*' -delete` is still
    // judged on what it would remove.
    const tokens = pathTokenize(norm);
    const searching = SEARCH_TOOLS.has(basename(tokens[0] ?? "")) &&
      !tokens.some((t) => FIND_EXEC.has(t));
    for (let i = 0; i < tokens.length; i++) {
      const tok = tokens[i];
      if (tok.startsWith("-") || tok.includes("=")) continue;
      if (searching && i > 0 && PATTERN_FLAGS.has(tokens[i - 1])) continue;
      for (const comp of tok.replace(/\\/g, "/").split("/")) if (segments.has(comp)) return comp;
      const r = blocked(resolveAny(tok, cwd), "bash");
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
      if (GIT_REF_WRITE.has(sub)) {
        // update-ref and fast-import are always writes. symbolic-ref and replace
        // have read forms that must pass -- .config/git/hooks/pre-commit runs
        // `git symbolic-ref --quiet --short HEAD`, and `git replace -l` lists.
        // Both are write-unless-proven-read: an operand count alone misses
        // `git replace --graft <commit>` (one operand) and
        // `git replace --convert-graft-file` (none), which both rewrite refs.
        const deleting = rest.some(t => t === "-d" || t === "--delete");
        const operands = rest.filter(t => !t.startsWith("-")).length;
        const readForm =
          (sub === "symbolic-ref" && !deleting && operands < 2) ||
          (sub === "replace" && !deleting &&
            (rest.length === 0 || rest.some(t => t === "-l" || t === "--list")));
        if (!readForm) return `direct git ref op (git ${sub})`;
      }
      if (sub === "config" && rest.some(t => gitConfigKey(t) === "core.hookspath")) return "git hooks bypass (git config core.hooksPath)";
      if (rest.includes("--no-verify")) return "git hook skip (--no-verify)";
      if (sub === "branch" && rest.some(t => t === "-f" || t === "--force" || t === "-D" || t === "-d" || t === "--delete")) return "forced/deleted git branch";
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

  type Danger = { reason: string; category: string };

  function dangerReason(cmd: string, cwd: string): Danger | undefined {
    // Effective directory, tracked across segments. `cd ~ && rm -rf dotfiles`
    // resolves its target against ~, not against the directory the tool call
    // started in -- without this the most common destructive form is invisible.
    let here = cwd;
    let hereKnown = true;
    for (const seg of splitSegments(cmd)) {
      const tamper = confinementTamperReason(tokenize(seg));
      if (tamper) return { reason: tamper, category: "confinement" };
      const parsed = commandAndArgs(seg, WRAPPERS);
      if (!parsed) continue;
      const { command, args } = parsed;
      if (command === "cd") {
        const target = firstNonFlag(args);
        if (!target) here = HOME;
        else if (target === "-") hereKnown = false;
        else here = resolveAny(target, here);
        continue;
      }
      if (ESCALATORS.has(command)) return { reason: "privilege escalation", category: "escalation" };
      if (DESTRUCTIVE.has(command)) return { reason: "destructive command", category: "disk-destructive" };
      if (command === "rm" && hasRmRecursiveForce(args)) {
        const targets = args.filter(a => !a.startsWith("-"));
        // After `cd -` the directory is unknowable. A false deny costs a
        // rerun; a false allow costs the repository.
        const relative = targets.some(
          t => !t.startsWith("/") && !t.startsWith("~") && !t.startsWith("$"),
        );
        const TOPLEVEL = "recursive-force-rm-toplevel";
        if (!hereKnown && relative) {
          return { reason: "rm -rf with an unresolvable cwd", category: TOPLEVEL };
        }
        if (targets.some(t => isTopLevelRmTarget(t, here, cwd))) {
          return { reason: "rm -rf of a top-level path", category: TOPLEVEL };
        }
        return { reason: "recursive force rm", category: "recursive-force-rm" };
      }
      if ((command === "chmod" || command === "chown") && isWorldWritableMode(firstNonFlag(args)))
        return { reason: "world-writable permissions", category: "world-writable" };
      if (command === "git") { const r = gitBypassReason(args); if (r) return { reason: r, category: "git-guard-bypass" }; }
      if (command === "find") {
        if (findPolicy === "always") return { reason: "find — prefer grepika/read tools", category: "find" };
        if (findPolicy === "exec" && args.some(a => FIND_EXEC.has(a))) return { reason: "find with -exec/-delete", category: "find" };
      }
      if (SHELL_RUNNERS.has(command)) {
        const inner = dashCArg(args);
        if (inner) { const nested = dangerReason(inner, here); if (nested) return nested; }
      }
    }
    return undefined;
  }


  // unified entry point ------------------------------------------------------
  function evaluate(input: { command?: string; path?: string; paths?: string[]; cwd: string; operation?: Operation }): Decision {
    const cwd = input.cwd || HOME;
    const operation = input.operation ?? (input.command ? "bash" : "unknown");
    for (const path of [...(input.path ? [input.path] : []), ...(input.paths ?? [])]) {
      const r = blocked(resolveAny(path, cwd), operation);
      if (r) return { decision: "deny", reason: `sensitive path (${r})` };
    }
    if (input.command) {
      const r1 = blockedCommand(input.command, cwd);
      if (r1) return { decision: "deny", reason: `sensitive path in command (${r1})` };
      const r2 = dangerReason(input.command, cwd);
      if (r2) return { decision: severityOf(r2.category), reason: r2.reason };
    }
    return { decision: "allow" };
  }

  return { evaluate };
}

// --- skill gate ---------------------------------------------------------------

export type SkillGateHit = { skills: string[]; message: string };

// Gate triggers — one of four, discriminated by `trigger.type`.
type BashTrigger = { type: "bash"; command: string; subcommands?: string[]; arg_contains?: string };
type WriteTrigger = { type: "write"; path_glob: string; at_root?: boolean; except?: string[] };
type FetchTrigger = { type: "fetch"; domains: string[] };
type CapabilityTrigger = { type: "capability"; all_of: string[] };
type Gate = { skills: string[]; message: string; trigger: BashTrigger | WriteTrigger | FetchTrigger | CapabilityTrigger };

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
 * to have been loaded this session. Four trigger types — `bash` (command +
 * optional subcommands, and/or `arg_contains` matched against the argument
 * list), `write` (a Write/Edit path), `fetch` (a WebFetch URL),
 * and `capability` (a provider-neutral event classification).
 * The core only matches events to gates; the ADAPTER supplies the session
 * evidence ("was the skill loaded?"), since that is host-specific. Adapters
 * record only concrete native Skill calls, canonical skill-file reads, or
 * shell commands referencing a canonical skill path.
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
  const gates: Gate[] = sg.gates ?? [];
  const bashGates = gates.filter((g) => g.trigger?.type === "bash") as (Gate & { trigger: BashTrigger })[];
  const writeGates = gates.filter((g) => g.trigger?.type === "write") as (Gate & { trigger: WriteTrigger })[];
  const fetchGates = gates.filter((g) => g.trigger?.type === "fetch") as (Gate & { trigger: FetchTrigger })[];
  const capabilityGates = gates.filter((g) => g.trigger?.type === "capability") as (Gate & { trigger: CapabilityTrigger })[];

  function hit(gate: Gate): SkillGateHit {
    return { skills: [...new Set(gate.skills)], message: gate.message };
  }

  function bashHits(command: string): SkillGateHit[] {
    const hits: SkillGateHit[] = [];
    for (const seg of splitSegments(command)) {
      const parsed = commandAndArgs(seg, WRAPPERS);
      if (!parsed) continue;
      for (const g of bashGates) {
        const t = g.trigger;
        if (parsed.command !== t.command) continue;
        if (t.subcommands?.length) {
          const sub = subcommandOf(parsed.args, t.command === "git" ? GIT_VALUE_OPTS : undefined);
          if (!t.subcommands.includes(sub)) continue;
        }
        if (t.arg_contains) {
          const needle = t.arg_contains.toLowerCase();
          if (!parsed.args.some((a) => a.toLowerCase().includes(needle))) continue;
        }
        hits.push(hit(g));
      }
      if (SHELL_RUNNERS.has(parsed.command)) {
        const inner = dashCArg(parsed.args);
        if (inner) hits.push(...bashHits(inner));
      }
    }
    return hits;
  }

  function writeHits(path: string, cwd: string): SkillGateHit[] {
    const abs = resolveAny(path, cwd);
    const base = basename(abs);
    const hits: SkillGateHit[] = [];
    for (const g of writeGates) {
      const t = g.trigger;
      if (t.except?.includes(base)) continue;
      if (t.at_root) {
        if (dirname(abs) !== resolve(cwd)) continue;
        if (!globMatch(t.path_glob, base)) continue;
      } else if (!globMatch(t.path_glob, abs)) continue;
      hits.push(hit(g));
    }
    return hits;
  }

  function fetchHits(url: string): SkillGateHit[] {
    let host: string;
    try { host = new URL(url).hostname.toLowerCase(); } catch { return []; }
    const hits: SkillGateHit[] = [];
    for (const g of fetchGates) {
      for (const d of g.trigger.domains) {
        const dd = d.toLowerCase();
        if (host === dd || host.endsWith("." + dd)) hits.push(hit(g));
      }
    }
    return hits;
  }

  function isGitWorktree(cwd: string): boolean {
    let current = resolve(cwd);
    while (true) {
      const dotGit = resolve(current, ".git");
      try {
        if (statSync(dotGit).isFile()) {
          const target = readFileSync(dotGit, "utf8").trim();
          if (/^gitdir:\s+.*[\\/]worktrees[\\/]/i.test(target)) return true;
        }
      } catch {}
      const parent = dirname(current);
      if (parent === current) return false;
      current = parent;
    }
  }

  function capabilitiesOf(input: ToolEvent): Set<string> {
    const capabilities = new Set<string>();
    const toolTokens = (input.tool ?? "").toLowerCase().split(/[^a-z0-9]+/).filter(Boolean);
    if (toolTokens.some((token) => ["paper", "papers", "citation", "citations", "author", "authors", "bibliography", "bibliographic"].includes(token))) {
      capabilities.add("academic-source");
    }
    // Delegation is a tool call, not a command or a path, so it is keyed on the
    // tool name: Task/Agent (Claude), task (opencode), pi's subagents package.
    // Exact names rather than tokens -- a tool called TaskOutput must not trip it.
    if (["task", "agent", "subagent", "delegate"].includes((input.tool ?? "").toLowerCase()) || toolTokens.includes("subagent")) {
      capabilities.add("subagent-spawn");
    }
    if (input.command) {
      const commandTokens = pathTokenize(input.command).map((token) => basename(token).toLowerCase());
      if (commandTokens.some((token) => ["pytest", "unittest", "vitest", "jest", "mocha", "rspec"].includes(token))) {
        capabilities.add("test-command");
      }
    }
    if (isGitWorktree(input.cwd ?? HOME)) capabilities.add("git-worktree");
    return capabilities;
  }

  function capabilityHits(capabilities: Set<string>): SkillGateHit[] {
    return capabilityGates
      .filter((g) => g.trigger.all_of.every((capability) => capabilities.has(capability)))
      .map(hit);
  }

  /**
   * Match one tool event. `command` runs the bash gates; a write-capable tool
   * (name contains "write"/"edit") with `paths` runs the write gates; a
   * fetch tool (name contains "fetch"), or an untyped event, runs the
   * fetch gates. `tool` is the host's tool name (case-insensitive), so the
   * read-vs-write distinction is portable without hardcoding per-host names.
   */
  function requiredSkills(input: ToolEvent): SkillGateHit[] {
    const cwd = input.cwd || HOME;
    const hits: SkillGateHit[] = [];
    if (input.command) hits.push(...bashHits(input.command));
    const tool = (input.tool ?? "").toLowerCase();
    const writes = input.operation === "write" || tool.includes("write") || tool.includes("edit") || tool.includes("apply_patch");
    if (writes) for (const path of input.paths ?? []) hits.push(...writeHits(path, cwd));
    if (tool === "" || tool.includes("fetch")) for (const url of input.urls ?? []) hits.push(...fetchHits(url));
    hits.push(...capabilityHits(capabilitiesOf({ ...input, cwd })));
    const byKey = new Map(hits.map((h) => [`${h.skills.join("\u0000")}\u0000${h.message}`, h]));
    return [...byKey.values()];
  }

  return { requiredSkills };
}

export function extractPatchPaths(patch: string): string[] {
  const paths: string[] = [];
  const re = /^\*\*\* (?:Add|Update|Delete) File: (.+)$/gm;
  for (const match of patch.matchAll(re)) paths.push(match[1].trim());
  return [...new Set(paths)];
}

function stringValues(input: Record<string, unknown> | undefined, keys: string[]): string[] {
  if (!input) return [];
  const out: string[] = [];
  for (const key of keys) if (typeof input[key] === "string") out.push(input[key] as string);
  return out;
}

export function pathsFromToolInput(tool: string | undefined, input: Record<string, unknown> | undefined): string[] {
  const paths = stringValues(input, ["path", "filePath", "file_path", "file", "directory", "notebook_path"]);
  if ((tool ?? "").toLowerCase().includes("glob") && typeof input?.pattern === "string") paths.push(input.pattern);
  const command = typeof input?.command === "string" ? input.command : undefined;
  if ((tool ?? "").toLowerCase().includes("apply_patch") && command) paths.push(...extractPatchPaths(command));
  return [...new Set(paths)];
}

export function inferOperation(tool: string | undefined, event: Pick<ToolEvent, "command" | "urls"> = {}): Operation {
  if (event.command) return "bash";
  const t = (tool ?? "").toLowerCase();
  if (event.urls?.length || t.includes("fetch")) return "fetch";
  if (t.includes("apply_patch") || t.includes("write") || t.includes("edit")) return "write";
  if (["read", "list", "get", "context", "toc", "outline", "search", "refs", "diff", "glob", "grep"].some((s) => t.includes(s))) return "read";
  return "unknown";
}

export function commandFromToolInput(tool: string | undefined, input: Record<string, unknown> | undefined): string | undefined {
  if ((tool ?? "").toLowerCase().includes("apply_patch")) return undefined;
  return typeof input?.command === "string" ? input.command : undefined;
}

export function toolEventFromInput(tool: string | undefined, input: Record<string, unknown> | undefined, cwd?: string): ToolEvent {
  const event: ToolEvent = {
    tool,
    cwd,
    command: commandFromToolInput(tool, input),
    paths: pathsFromToolInput(tool, input),
    urls: stringValues(input, ["url"]).filter((s) => /^https?:/i.test(s)),
  };
  event.operation = inferOperation(tool, event);
  return event;
}

export function createGuardrails(agent: string) {
  const guard = createGuard(agent);
  const skillGate = createSkillGate();

  function missingSkillReason(skills: string[], messages: string[]): string {
    const listed = skills.join(", ");
    const event = [...new Set(messages)].join("; ");
    if (agent === "codex") {
      return `skill gate: ${event}. Read ~/.agents/skills/<name>/SKILL.md for the required skill(s): ${listed}, then retry.`;
    }
    return `skill gate: ${event}. Load required skill(s): ${listed}, then retry.`;
  }

  function evaluate(event: ToolEvent, loadedSkills?: Set<string> | string[]): GuardrailDecision {
    const cwd = event.cwd ?? HOME;
    const paths = event.paths ?? [];
    const urls = event.urls ?? [];
    const operation = event.operation ?? inferOperation(event.tool, event);

    const r = guard.evaluate({ command: event.command, paths, cwd, operation });
    if (r.decision !== "allow") return r;

    const loaded = loadedSkills instanceof Set ? loadedSkills : new Set(loadedSkills ?? []);
    const hits = skillGate.requiredSkills({ ...event, paths, urls, cwd, operation });
    const missing = [...new Set(hits.flatMap((hit) => hit.skills).filter((skill) => !loaded.has(skill)))];
    if (missing.length) {
      const relevantMessages = hits.filter((hit) => hit.skills.some((skill) => missing.includes(skill))).map((hit) => hit.message);
      return {
        decision: "deny",
        reason: missingSkillReason(missing, relevantMessages),
        skill: missing[0],
        skills: missing,
      };
    }
    return { decision: "allow" };
  }

  return { evaluate };
}

/** Canonical skill-file path — the only pattern that yields a load receipt. */
const SKILL_FILE_RE = /(?:^|\/)(?:\.agents|\.claude|\.opencode|\.config\/(?:codex|opencode))\/skills\/([a-z0-9][a-z0-9-]*)\/SKILL\.md$/i;

/**
 * Return skill-load receipts from a concrete native Skill call, a read of a
 * canonical configured skill path, or a shell command that references one
 * (bash-only harnesses such as Codex load skills via shell reads; mirroring
 * blockedCommand, a mention of the canonical path is the evidence — gates are
 * workflow nudges, not a security boundary). It deliberately ignores arbitrary
 * prose/payload strings that merely name a skill.
 */
export function skillReceipts(tool: string | undefined, input: Record<string, unknown> | undefined): Set<string> {
  const receipts = new Set<string>();
  const normalizedTool = (tool ?? "").toLowerCase();
  const nativeSkillTool = normalizedTool === "skill" || normalizedTool.endsWith(".skill") || normalizedTool.endsWith("_skill");
  if (nativeSkillTool) {
    for (const key of ["name", "skill", "skillName"]) {
      const value = input?.[key];
      if (typeof value === "string" && /^[a-z0-9][a-z0-9-]*$/.test(value)) receipts.add(value);
    }
  }
  const command = commandFromToolInput(tool, input);
  if (command) {
    for (const token of pathTokenize(command)) {
      const match = token.replace(/\\/g, "/").match(SKILL_FILE_RE);
      if (match) receipts.add(match[1]);
    }
  }
  if (inferOperation(tool, {}) !== "read") return receipts;
  for (const path of pathsFromToolInput(tool, input)) {
    const match = path.replace(/\\/g, "/").match(SKILL_FILE_RE);
    if (match) receipts.add(match[1]);
  }
  return receipts;
}

/**
 * Per-session skill-receipt store, at $XDG_STATE_HOME/<agent>/guardrails/<id>.json.
 * Hook processes are short-lived — Codex spawns a fresh one per tool call — so
 * receipts only survive through this file. The adapter derives `id` (a hash of
 * the transcript path for Claude, the session id for Codex); `undefined` means
 * the host offered nothing to key on, and then nothing is persisted.
 */
export function skillStateStore(agent: string, id: string | undefined) {
  const root = process.env.XDG_STATE_HOME ?? resolve(HOME, ".local/state");
  const path = id === undefined ? undefined : resolve(root, `${agent}/guardrails`, `${id}.json`);
  return {
    load(): Set<string> {
      if (!path || !existsSync(path)) return new Set<string>();
      try {
        const parsed = JSON.parse(readFileSync(path, "utf8"));
        return new Set<string>(Array.isArray(parsed.loadedSkills) ? parsed.loadedSkills : []);
      } catch {
        return new Set<string>();
      }
    },
    save(loadedSkills: Set<string>) {
      if (!path) return;
      try {
        mkdirSync(dirname(path), { recursive: true });
        writeFileSync(path, JSON.stringify({ loadedSkills: [...loadedSkills].sort() }, null, 2));
      } catch {
        // A persistence failure makes later gates stricter rather than failing open.
      }
    },
  };
}

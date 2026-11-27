// Fan a change out to code-reviewer children, at most MAX_FILES per child, and
// report which changed files no child accounted for. Workflow scripts get no
// shell, so the caller passes the file list: args = { range, request?, files }.
// `files` is one newline-separated string because pi-subagents caps an args
// array at 64 items; `request` is omitted rather than empty, since empty
// strings are rejected at launch.
const MAX_FILES = 8;
// pi-subagents admits one runs.all group against maxSubagentSpawnsPerRun
// (default 64) all at once, so a larger group would fail the whole run.
const MAX_BATCHES = 64;
const files = [
  ...new Set(
    args.files
      .split("\n")
      .map((line) => line.trim())
      .filter(Boolean),
  ),
];

const findingSchema = {
  type: "object",
  required: ["severity", "file", "line", "quote", "finding", "settles_it"],
  properties: {
    severity: { enum: ["critical", "warning", "note"] },
    file: { type: "string" },
    line: { type: "integer" },
    quote: { type: "string" },
    finding: { type: "string" },
    settles_it: { type: "string" },
  },
};

const outputSchema = {
  type: "object",
  required: ["coverage", "findings"],
  properties: {
    coverage: {
      type: "array",
      items: {
        type: "object",
        required: ["file", "status"],
        properties: {
          file: { type: "string" },
          status: { enum: ["reviewed", "skipped"] },
          reason: { type: "string" },
        },
      },
    },
    findings: { type: "array", items: findingSchema },
  },
};

function dirOf(path) {
  const cut = path.lastIndexOf("/");
  return cut < 0 ? "." : path.slice(0, cut);
}

// Keep a directory in one batch where it fits; a directory larger than
// MAX_FILES spills across batches rather than growing one past the limit.
function batches(paths) {
  const groups = new Map();
  for (const file of [...paths].sort()) {
    const dir = dirOf(file);
    if (!groups.has(dir)) groups.set(dir, []);
    groups.get(dir).push(file);
  }
  const out = [];
  let current = [];
  for (const group of groups.values()) {
    if (current.length > 0 && current.length + group.length > MAX_FILES) {
      out.push(current);
      current = [];
    }
    for (const file of group) {
      if (current.length === MAX_FILES) {
        out.push(current);
        current = [];
      }
      current.push(file);
    }
  }
  if (current.length > 0) out.push(current);
  return out;
}

function task(batch) {
  return [
    `Review the change \`${args.range}\`, limited to these files:`,
    ...batch.map((file) => `- ${file}`),
    "",
    `What the change is for: ${args.request || "not stated; infer it from the commit messages in the range"}`,
    "",
    "Return the findings and a coverage entry for every file listed above.",
  ].join("\n");
}

const severityRank = { critical: 0, warning: 1, note: 2 };
const parts = batches(files).slice(0, MAX_BATCHES);
const results = await runs.all(
  parts.map((batch, index) => ({
    key: `batch-${index + 1}`,
    agent: "code-reviewer",
    task: task(batch),
    outputSchema,
  })),
);

const findings = [];
const coverage = [];
const failedBatches = [];
let droppedFindings = 0;
results.forEach((result, index) => {
  const data = result.structuredOutput;
  if (!result.ok || !data) {
    failedBatches.push({ batch: index + 1, files: parts[index] });
    return;
  }
  const asked = new Set(parts[index]);
  const kept = data.findings.filter((finding) => asked.has(finding.file));
  droppedFindings += data.findings.length - kept.length;
  findings.push(...kept);
  coverage.push(...data.coverage.filter((entry) => asked.has(entry.file)));
});

const covered = new Set(coverage.map((entry) => entry.file));
findings.sort((a, b) => severityRank[a.severity] - severityRank[b.severity]);

return {
  range: args.range,
  files: files.length,
  batches: parts.length,
  findings,
  coverage,
  missing: files.filter((file) => !covered.has(file)),
  failedBatches,
  droppedFindings,
};

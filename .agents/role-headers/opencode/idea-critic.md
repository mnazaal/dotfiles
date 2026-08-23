---
# Adapted from https://github.com/andrehuang/researcher-pack
description: Stress-tests research ideas for novelty, impact, timing, feasibility, competition, nugget clarity, and narrative. Returns a Pursue/Refine/Kill verdict. Read-only.
mode: subagent
temperature: 0.2
permission:
  bash: deny
  edit: deny
  task: deny
  webfetch: ask
  websearch: ask
  "asta-mcp_*": allow
---

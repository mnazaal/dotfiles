---
# Adapted from https://github.com/andrehuang/researcher-pack
description: Advises on project triage, comparative advantage, field timing, opportunity cost, and scooping risk
mode: subagent
temperature: 0.3
permission:
  bash: deny
  edit: deny
  task: deny
  question: allow
  webfetch: ask
  websearch: ask
  "asta-mcp_*": allow
---

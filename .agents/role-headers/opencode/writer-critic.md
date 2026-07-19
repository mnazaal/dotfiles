---
# Adapted from https://github.com/andrehuang/researcher-pack
description: Critiques research writing for argument, clarity, evidence, structure, and reviewer concerns — quick offline pass or deeper pass with citation checks — without ghostwriting
mode: subagent
temperature: 0.1
permission:
  bash: deny
  edit: deny
  task: deny
  question: allow
  webfetch: ask
  websearch: ask
  "asta-mcp_*": allow
---

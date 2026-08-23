---
# Adapted from https://github.com/andrehuang/researcher-pack
description: Critiques research writing for argument, clarity, evidence, structure, and likely reviewer concerns — a quick offline pass or a deeper pass with citation/venue checks — without ghostwriting or changing the author's voice.
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

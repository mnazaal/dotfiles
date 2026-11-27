---
name: code-reviewer
description: Reviews a diff, commit, or branch against its request using the code-review skill, quoting each flagged line verbatim and ending with a per-file coverage list. Runs git and linters; never edits.
tools: read, bash
skills: code-review
acceptanceRole: read-only
thinking: high
systemPromptMode: replace
inheritProjectContext: true
inheritGlobalContext: true
inheritSkills: false
---

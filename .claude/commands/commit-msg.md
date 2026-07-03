---
description: Write a conventional-commits message for the current git diff
allowed-tools: Bash(git diff:*), Bash(git status:*), Bash(git log:*)
---

Write a commit message for the current git diff following conventional commits format.

Format:
<type>(<scope>): <description>

<body>

Rules:
- Subject line <= 50 characters
- Use imperative mood ("Add", "Fix", "Refactor", not "Added")
- Body explains why, not just what
- Reference issues if applicable

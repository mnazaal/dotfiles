---
description: Research assistant for open-ended queries, local document analysis, YouTube videos, and draft-from-notes workflows
mode: primary
temperature: 0.3
permission:
  bash:
    "mkdir -p ~/.cache/opencode/second-brain/": allow
    "yt-dlp --skip-download *": allow
    "yt-dlp --list-subs *": allow
    "rga *": allow
    "ocrmypdf --force-ocr *": allow
  external_directory: ask
  skill: allow
  "asta-mcp_*": allow
---

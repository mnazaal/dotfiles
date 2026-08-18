---
name: context-pdf
description: Use for PDF files: read, extract text/tables/images, merge, split, rotate, watermark, create, fill forms, encrypt, decrypt, OCR, scanned PDFs, page ranges.
---

# Skill: Context PDF

## Rules

- Preserve the original PDF unless user asks for in-place mutation.
- For extraction, record source file, page range, method, and limitations.
- For scanned PDFs, use OCR path when text extraction is empty or low quality.
- For forms, encryption/decryption, passwords, signatures, or sensitive
  extracted content, avoid exposing values in logs and route credential handling
  through `dev-security`.

## Workflow

1. Classify operation: read/extract/transform/create/protect/OCR.
2. Inspect permissions and output target.
3. Use least destructive method.
4. Validate output artifact or extracted text.
5. Report output path, page scope, and caveats.

## Related Skills

- Extracted notes for the personal Org store: propose as snippets — `~/org` is read-only for agents (AGENTS.md).
- `research-paper` for reading academic PDFs.
- `dev-security` for PDF passwords, secrets, signatures, or sensitive content.

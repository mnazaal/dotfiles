---
name: context-pdf
description: "Use for PDF files: read, extract text/tables/images, merge, split, rotate, watermark, create, fill forms, encrypt, decrypt, OCR, scanned PDFs, page ranges."
---

# Skill: Context PDF

## Rules

- TRIAGE BEFORE READING. Inspect the document first — page count, and per page
  the text length, image count and how dense the mathematical notation is — then
  decide what to read. Reading a long PDF front to back is the default failure
  and it is expensive in exactly the documents worth reading.
- Text extraction MANGLES mathematics: symbols, sub/superscripts and matrix
  layout come out reordered or dropped, and the result reads as plausible prose,
  so the damage is silent. For a page carrying real notation, render the page to
  an image and read it as an image instead. The same applies to a page with
  figures, and to any page whose extracted text is nearly empty while the page
  is clearly not.
- Scale the strategy to the document: a short paper can be rendered in full; a
  long one cannot, so triage decides which pages earn it. Raise the render
  resolution for dense notation and lower it when merely scanning.
- For extraction, record source file, page range, method, and limitations.
- For scanned PDFs, use OCR path when text extraction is empty or low quality.
- For forms, encryption/decryption, passwords, signatures, or sensitive
  extracted content, avoid exposing values in logs and route credential handling
  through `dev-security`.

## Workflow

1. Classify operation: read/extract/transform/create/protect/OCR.
2. For a read, triage first: page count and per-page text/image/notation density.
3. Inspect permissions and output target.
4. Validate output artifact or extracted text.
5. Report output path, page scope, and caveats.

## Related Skills

- `research-paper` for reading academic PDFs.
- `dev-security` for PDF passwords, secrets, signatures, or sensitive content.

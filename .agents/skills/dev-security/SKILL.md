---
name: dev-security
description: Use for security-sensitive work: secrets, credentials, auth, permissions, tokens, API keys, environment files, private data, suspected leakage, or safety review of config/logs.
---

# Skill: Dev Security

## Rules

- Never print, quote, commit, or summarize secret values. Refer to variable names,
  file paths, and redacted prefixes only when needed.
- Treat `.env`, credentials, tokens, private keys, cookies, auth headers,
  database URLs, and personal/private data as sensitive by default.
- If a secret may have been exposed to git, logs, chat, or a third-party tool,
  rotation is the fix; deletion alone is not enough.
- Prefer least privilege: narrow scopes, short lifetimes, environment injection,
  and project-local permissions over broad/global access.
- Do not weaken permissions, disable hooks, bypass auth, or expose protected paths
  without explicit user confirmation.

## Workflow

1. Classify the asset: secret, credential, auth flow, permission boundary,
   private data, or suspected leak.
2. Minimize exposure: avoid reading full values; inspect metadata, keys, paths,
   and redacted forms where possible.
3. Determine impact: where the value is stored, logged, committed, transmitted,
   or consumed.
4. Recommend containment: remove from unsafe location, rotate/revoke, update
   ignore/config, and verify no new exposure.
5. Route implementation to the relevant `dev-*` skill; keep secret handling here.

## Commit / Log Safety

- Before commit, inspect staged paths for obvious sensitive files.
- If a secret is already in history, stop and ask before history rewriting;
  route mechanics to `dev-git-rescue` after rotation guidance.
- Redact command output in reports. Evidence should prove the check ran without
  revealing the protected value.

## Related Skills

- `dev-git` for safe staging/committing once sensitive material is excluded.
- `dev-git-rescue` for history repair after confirmed leakage.
- `debug-root-cause` for auth/permission failures with a repro loop.

---
name: tool-cementic
description: Use when the task involves cementic, the local semantic search CLI: indexing directories, searching, managing collections/revisions, or the extract/chunk/embed pipeline.
---

# Skill: cementic

cementic watches directories, extracts/chunks/embeds documents (PDF/Markdown/text) into Postgres (pgvector + vectorscale), and serves semantic search over versioned pipeline revisions — old revisions stay searchable while new ones build.

## Rules

- If `command -v cementic` fails, use the configured checkout/activation path if one is known; otherwise ask the user for the cementic checkout instead of searching arbitrary directories.
- On a genuinely fresh Postgres (no schema yet), `status`/`search` fail with `relation "..." does not exist` — this is expected, not a bug. Table creation (`create_tables()`) only happens inside `cementic start`'s worker paths (`pipeline_worker.py`/`source_watcher.py`), never in read-only commands. Use `cementic start` for bootstrap only after the user chooses the directory and collection to watch/index.
- Postgres must be reachable before most commands work. If the named container already exists and you have host container-engine access, start it directly — `podman start cementic-postgres` (or `docker start`). Use `docker/podman compose up` only to create the service when the container/service is absent.
- If you can't reach Postgres *and* can't start it yourself — e.g. you're running in a container/sandbox that doesn't have access to the host's podman/systemd — do not try to work around it (nested container tooling inside a sandbox is often broken in ways that are hard to diagnose from inside). Instead, ask the user to check whether it's already running as a persistent service (`systemctl --user status cementic-postgres`) or to start it themselves from a normal host shell. Network access to an already-running Postgres typically works fine even when the container engine itself doesn't (e.g. a sandbox that shares the host network namespace but not `/run/user`) — so DB-dependent commands (`search`, `start`, `collection *`) work once Postgres is up; only the container/service lifecycle step may be blocked. No-DB commands (`chunk`, `embedding status`, `config show/init/path`) are unaffected either way.
- Postgres credentials are fixed into the container at creation time, not read fresh from config — an existing container's actual password can differ from the `cementic`/`cementic` compose defaults (e.g. if it was created manually or predates a config change). If commands fail with "password authentication failed," route credential handling through `dev-security`; inspect only redacted environment/config output and do not print passwords into chat or logs.
- Config precedence: defaults < config file < `CEMENTIC_*` env vars < CLI flags. File resolution: `$CEMENTIC_CONFIG` > `./cementic.toml` > `~/.config/cementic/config.toml`.
- `search` only queries a collection's **active** revision — a brand-new collection has none until `collection promote`.
- `collection promote` blocks if the ready revision has any failed docs/chunks; `-f/--force` overrides.
- `stop` only stops the source watcher and pipeline worker; the shared embedding daemon is deliberately left running (stop it with `cementic embedding stop`), and Postgres is never managed by cementic.
- Use `--json` on `status` / `doctor` for parseable output; `config show` prints JSON already.
- `cementic doctor` is the read-only readiness check (Postgres reachability, embedding runtime, config) — run it before debugging any of those by hand.
- `extract | chunk | embed` piped together is the no-database debug path for inspecting what would be stored.
- Boundary: use cementic for full-text semantic retrieval/indexing. Use `tool-pzi` for BibTeX metadata, citekeys, and library maintenance; combine them only when both full text and citation metadata are requested.

## Workflow

**First-time setup:**
```bash
cementic doctor                    # read-only readiness diagnostics
systemctl --user status cementic-postgres   # check if it's already running as a service
# if the named container exists and you have host container-engine access:
podman start cementic-postgres
# if no service/container exists yet (no checkout needed):
cementic init postgres ~/cementic-postgres && docker/podman compose up -d  # run compose in that dir
cementic config init               # writes ~/.config/cementic/config.toml
cementic config show               # verify effective config (merged, redacted)
```

**Index a directory:**
```bash
cementic start ~/papers --collection papers
cementic status -c papers -v       # per-file progress
cementic status --json             # machine-readable overview
```

**Search:**
```bash
cementic search "transformer inference"
cementic search "graph theory" -n 5 -c math papers
```

**Manage collections/revisions:**
```bash
cementic collection list
cementic collection revisions papers
cementic collection promote papers           # switch search to the ready revision
cementic collection promote papers --force   # override failed-item block
cementic collection reindex papers           # rebuild ANN index after changing [index] config
cementic collection remove papers --force
```

**Debug the pipeline without a database:**
```bash
cementic extract paper.pdf | cementic chunk | cementic embed
```

**Embedding runtime (llama.cpp daemon):**
```bash
cementic embedding start
cementic embedding status
cementic embedding stop
```

**Stop background work:**
```bash
cementic stop
cementic stop --force
```

## Related Skills

- `dev-python` for working on cementic's own source, tests, and packaging (as distinct from using the CLI).
- `tool-pzi` for bibliographic metadata/citekeys rather than full-text search.
- `dev-security` for database credentials or sensitive indexed content.

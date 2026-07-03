---
name: tool-cementic
description: Use when the task involves cementic, the local semantic search CLI: indexing directories, searching, managing collections/revisions, or the extract/chunk/embed pipeline.
---

# Skill: cementic

cementic watches directories, extracts/chunks/embeds documents (PDF/Markdown/text) into Postgres (pgvector + vectorscale), and serves semantic search over versioned pipeline revisions — old revisions stay searchable while new ones build.

## Rules

- `cementic` may only be on `PATH` inside the project's dev checkout (e.g. an editable install activated via direnv/venv when `cd`'d into the source tree) — if `command -v cementic` fails, try `cd`-ing into the cementic project directory before concluding it isn't installed.
- On a genuinely fresh Postgres (no schema yet), `status`/`search` fail with `relation "..." does not exist` — this is expected, not a bug. Table creation (`create_tables()`) only happens inside `cementic start`'s worker paths (`pipeline_worker.py`/`source_watcher.py`), never in read-only commands. Run `cementic start <any-directory>` once first to bootstrap the schema.
- Postgres must be reachable before most commands work. If you have working host container-engine access, start it directly — `podman start cementic-postgres` (or `docker start`) — rather than `compose up`, which can stall if the port's already bound and it mistakes an auth failure for "still starting."
- If you can't reach Postgres *and* can't start it yourself — e.g. you're running in a container/sandbox that doesn't have access to the host's podman/systemd — do not try to work around it (nested container tooling inside a sandbox is often broken in ways that are hard to diagnose from inside). Instead, ask the user to check whether it's already running as a persistent service (`systemctl --user status cementic-postgres`) or to start it themselves from a normal host shell. Network access to an already-running Postgres typically works fine even when the container engine itself doesn't (e.g. a sandbox that shares the host network namespace but not `/run/user`) — so DB-dependent commands (`search`, `start`, `collection *`) work once Postgres is up; only the container/service lifecycle step may be blocked. No-DB commands (`chunk`, `embedding status`, `config show/init/path`) are unaffected either way.
- Postgres credentials are fixed into the container at creation time, not read fresh from config — an existing container's actual password can differ from the `cementic`/`cementic` compose defaults (e.g. if it was created manually or predates a config change). If commands fail with "password authentication failed," check what the container was actually created with (`podman inspect cementic-postgres --format '{{.Config.Env}}'`) rather than assuming the default, and point `CEMENTIC_DB_URL`/`CEMENTIC_DB_PASSWORD` at that.
- Config precedence: defaults < config file < `CEMENTIC_*` env vars < CLI flags. File resolution: `$CEMENTIC_CONFIG` > `./cementic.toml` > `~/.config/cementic/config.toml`.
- `search` only queries a collection's **active** revision — a brand-new collection has none until `collection promote`.
- `collection promote` blocks if the ready revision has any failed docs/chunks; `-f/--force` overrides.
- `stop` only stops the source-watcher/pipeline-worker/embedding server — it does not manage Postgres.
- Use `--json` on `status` / `config show` for parseable output.
- `extract | chunk | embed` piped together is the no-database debug path for inspecting what would be stored.

## Workflow

**First-time setup:**
```bash
systemctl --user status cementic-postgres   # check if it's already running as a service
# if not, and you have host container-engine access:
podman start cementic-postgres     # or: docker/podman compose up -d
cementic config init               # writes ~/.config/cementic/config.toml
cementic config show               # verify effective config (merged, redacted)
```

**Index a directory:**
```bash
cementic start ~/papers --collection research
cementic status -c research -v     # per-file progress
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
cementic collection revisions research
cementic collection promote research           # switch search to the ready revision
cementic collection promote research --force   # override failed-item block
cementic collection remove research --force
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

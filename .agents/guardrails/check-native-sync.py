#!/usr/bin/env python3
"""Drift check between the shared policy and Claude's own permission layers.

`sensitive-paths.json` is what the guardrails hook enforces for BOTH agents;
`.claude/settings.json` is what Claude enforces natively for itself. They are
hand-maintained duplicates of one intent, so they drift, and each direction
drifts into a different fault:

  policy -> settings   a path the hook denies that Claude's typed tools do not,
                       so a Read or Edit slips past where a Bash command would
                       not.
  settings -> policy   a rule Claude enforces that the shared policy has never
                       heard of, which leaves PI uncovered — pi has no native
                       permission layer, only this hook. Five live examples,
                       all found 2026-09-07: ~/.git-credentials,
                       ~/.git-credential-cache, ~/.local/share/keyrings,
                       ~/.local/share/mail and ~/.mozilla. Three
                       ~/.config/renv rules also outlived the directory they
                       named, which nothing noticed.

Checks each LAYER, not merely that the path is mentioned somewhere. An earlier
version matched the whole file as a substring and passed while an Edit rule was
deleted, because the same path still appeared under denyWrite — a check that
cannot see the loss it exists for is worse than none, since it reads as
assurance.

Deliberately NOT required: a denyWrite entry per machinery path. Twelve of them
are stow symlinks (~/.bashrc, ~/.config/zsh, …) whose targets under ~/dotfiles
are pinned; a write through the link lands on the pinned source, so demanding
both forms would fail on correct configuration.
"""
import json
import sys
from pathlib import Path

root = Path(sys.argv[1] if len(sys.argv) > 1 else ".")
policy = json.loads((root / ".agents/guardrails/sensitive-paths.json").read_text())
settings = json.loads((root / ".claude/settings.json").read_text())

credentials = policy.get("credentials", [])
machinery = policy.get("machinery", [])
if not credentials or not machinery:
    sys.exit("native-sync: sensitive-paths.json declares no guarded paths")

deny = settings.get("permissions", {}).get("deny", [])
filesystem = settings.get("sandbox", {}).get("filesystem", {})
deny_read = set(filesystem.get("denyRead", []))
problems = []


def denied(tool: str, path: str) -> bool:
    return f"{tool}({path})" in deny or f"{tool}({path}/**)" in deny


for path in credentials:
    if not denied("Read", path):
        problems.append(f"credential has no Read() deny in settings.json: {path}")
    if path not in deny_read:
        problems.append(f"credential is not in sandbox denyRead: {path}")

for path in machinery:
    if not denied("Edit", path):
        problems.append(f"machinery path has no Edit() deny in settings.json: {path}")

# The reverse direction: anything Claude denies under $HOME should be a path the
# shared policy knows, or pi is unprotected where claude is protected.
guarded = set(credentials) | set(machinery)
rules = {r[r.index("(") + 1 : -1].removesuffix("/**") for r in deny if r.startswith(("Read(", "Edit("))}
rules |= set(filesystem.get("denyWrite", [])) | deny_read
for rule in sorted(rules):
    # A rule that still holds a wildcard here cannot be compared against the
    # shared policy at all: that policy lists literal paths, so `~/**/.env` is
    # absent from it however complete it is, and demanding a match would report
    # a hole that does not exist. The `/**` suffix form is already normalised
    # away above; what reaches this point is an embedded wildcard. pi is not
    # left behind by the skip, because those paths are covered for both agents
    # by the segment guard in core.ts (`.env`, `.env.*`, `.git/hooks`) rather
    # than by a path list.
    if "*" in rule:
        continue
    if rule.startswith("~/") and rule not in guarded:
        problems.append(f"settings.json denies a path the shared policy omits: {rule}")

for p in problems:
    print(f"native permission drift: {p}", file=sys.stderr)
sys.exit(1 if problems else 0)

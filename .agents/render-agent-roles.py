#!/usr/bin/env python3
"""Render platform agent files from canonical role bodies and headers.

The role set is read from the source tree, not listed here: a role is a body in
.agents/roles, and a platform renders it when .agents/role-headers/<platform>
holds a header for it (pi has no `build` header, so pi gets no `build` agent).
--check also fails on a body no platform renders, a header with no body, and a
rendered file with no source, since each is a role the render would skip.
"""
from __future__ import annotations

import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BODIES = ROOT / ".agents/roles"
HEADERS = ROOT / ".agents/role-headers"
PLATFORMS = {
    "claude": ROOT / ".claude/agents",
    "pi": ROOT / ".config/pi/agent/agents",
}


def names(directory: Path) -> set[str]:
    return {path.stem for path in directory.glob("*.md")}


def rendered(platform: str, role: str) -> str:
    header = (HEADERS / platform / f"{role}.md").read_text().rstrip()
    body = (BODIES / f"{role}.md").read_text().lstrip()
    return f"{header}\n\n{body}"


def targets() -> tuple[dict[Path, str], list[str]]:
    out: dict[Path, str] = {}
    problems: list[str] = []
    bodies = names(BODIES)
    headed: set[str] = set()
    for platform, directory in PLATFORMS.items():
        roles = names(HEADERS / platform)
        headed |= roles
        for role in sorted(roles - bodies):
            problems.append(f"role-headers/{platform}/{role}.md has no body in .agents/roles")
        for role in sorted(roles & bodies):
            out[directory / f"{role}.md"] = rendered(platform, role)
        for stale in sorted(names(directory) - roles):
            problems.append(f"{(directory / f'{stale}.md').relative_to(ROOT)} has no source role")
    for role in sorted(bodies - headed):
        problems.append(f".agents/roles/{role}.md has no header, so no platform renders it")
    return out, problems


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    expected_files, problems = targets()
    drift = []
    for target, expected in expected_files.items():
        if args.check:
            if not target.is_file() or target.read_text() != expected:
                drift.append(target.relative_to(ROOT))
        else:
            target.write_text(expected)
    for target in drift:
        print(f"agent file drift: {target}")
    for problem in problems:
        print(f"agent role drift: {problem}")
    return 1 if drift or problems else 0


if __name__ == "__main__":
    raise SystemExit(main())

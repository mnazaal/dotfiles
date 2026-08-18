#!/usr/bin/env python3
"""Render platform agent files from canonical role bodies, headers, and prompts."""
from __future__ import annotations

import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROLES = "brainstormer build docs-verify eval-review idea-critic plan research-strategist second-brain writer-critic".split()
PLATFORMS = {
    "claude": (ROOT / ".claude/agents", ROLES),
    "opencode": (ROOT / ".config/opencode/agents", ROLES),
    "pi": (ROOT / ".config/pi/agent/agents", [role for role in ROLES if role not in {"build", "plan"}]),
}
def rendered(platform: str, role: str) -> str:
    header = (ROOT / ".agents/role-headers" / platform / f"{role}.md").read_text().rstrip()
    body = (ROOT / ".agents/roles" / f"{role}.md").read_text().lstrip()
    return f"{header}\n\n{body}"


def targets() -> dict[Path, str]:
    out: dict[Path, str] = {}
    for platform, (directory, roles) in PLATFORMS.items():
        for role in roles:
            out[directory / f"{role}.md"] = rendered(platform, role)
    return out


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    drift = []
    for target, expected in targets().items():
        if args.check:
            if target.read_text() != expected:
                drift.append(target.relative_to(ROOT))
        else:
            target.write_text(expected)
    if drift:
        for target in drift:
            print(f"agent file drift: {target}")
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

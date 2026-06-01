#!/usr/bin/env python3
"""Block unresolved implementation language from app and test sources."""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
SCAN_ROOTS = [ROOT / "GradeDraft", ROOT / "GradeDraftTests"]
PATTERNS = [
    re.compile(r"\bTODO\b", re.IGNORECASE),
    re.compile(r"\bFIXME\b", re.IGNORECASE),
    re.compile(r"\bplaceholder\b", re.IGNORECASE),
    re.compile(r"\bmock\b", re.IGNORECASE),
]

# Keep exceptions exact and rare. Add only source-truth educational copy or test
# fixture language that must use one of the blocked words.
ALLOWLIST: set[tuple[str, int]] = set()
CURRICULUM_RESOURCE_ALLOWLIST = {
    "GradeDraft/Resources/JSON/curriculum_catalog_acara_v9.json",
    "GradeDraft/Resources/JSON/curriculum_catalog_acara_v9_manifest.json",
    "GradeDraft/Resources/JSON/curriculum_catalog_acara_v9_summary.json",
}


def main() -> int:
    failures: list[str] = []
    for root in SCAN_ROOTS:
        for path in root.rglob("*"):
            if not path.is_file() or path.suffix not in {".swift", ".json", ".plist", ".xcprivacy"}:
                continue
            rel = path.relative_to(ROOT).as_posix()
            if rel in CURRICULUM_RESOURCE_ALLOWLIST:
                # Generated official curriculum text legitimately contains words
                # such as "mock", "todo" in Spanish, and numeric phrases that
                # collide with unresolved-implementation terms. The generator
                # and catalog validator provide the release guardrail here.
                continue
            try:
                lines = path.read_text(encoding="utf-8").splitlines()
            except UnicodeDecodeError:
                continue
            for lineno, line in enumerate(lines, start=1):
                if (rel, lineno) in ALLOWLIST:
                    continue
                for pattern in PATTERNS:
                    if pattern.search(line):
                        failures.append(f"{rel}:{lineno}: matched {pattern.pattern!r}: {line.strip()}")

    if failures:
        print("Bad implementation strings found in GradeDraft source/tests:")
        print("\n".join(failures))
        return 1
    print("No unresolved implementation strings found in GradeDraft source/tests.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

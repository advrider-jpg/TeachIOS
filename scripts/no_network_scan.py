#!/usr/bin/env python3
"""Fail if obvious network code enters the local-only GradeDraft app."""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCAN_SUFFIXES = {".swift", ".plist", ".pbxproj", ".xcprivacy", ".json", ".yml", ".yaml"}
IGNORE_DIRS = {".git", "DerivedData", ".build", ".swiftpm"}

PATTERNS = [
    re.compile(r"\bURLSession\b"),
    re.compile(r"\bNSURLConnection\b"),
    re.compile(r"\bNetwork\."),
    re.compile(r"\bNWConnection\b"),
    re.compile(r"\bNWPathMonitor\b"),
    re.compile(r"https?://", re.IGNORECASE),
    re.compile(r"Firebase", re.IGNORECASE),
    re.compile(r"Amplitude", re.IGNORECASE),
    re.compile(r"Mixpanel", re.IGNORECASE),
    re.compile(r"Sentry", re.IGNORECASE),
    re.compile(r"Analytics", re.IGNORECASE),
]

ALLOWLIST = {
    pathlib.Path("README.md"),
    pathlib.Path("docs/OFFLINE_CAPABILITY.md"),
    pathlib.Path("docs/ARCHITECTURE.md"),
    pathlib.Path("docs/TEST_PLAN.md"),
    pathlib.Path("scripts/no_network_scan.py"),
}
PACKAGE_DOCS_ALLOWLIST = {
    pathlib.Path("docs/DEPENDENCIES.md"),
    pathlib.Path("docs/OSS_REVIEW.md"),
}
PBX_REPO_PATTERN = re.compile(r"^\s*repositoryURL\s*=")

failures: list[str] = []
for path in ROOT.rglob("*"):
    if any(part in IGNORE_DIRS for part in path.parts):
        continue
    if not path.is_file():
        continue
    rel = path.relative_to(ROOT)
    if rel in ALLOWLIST:
        continue
    if path.suffix not in SCAN_SUFFIXES:
        continue
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        continue
    for lineno, line in enumerate(text.splitlines(), start=1):
        if path.suffix == ".pbxproj" and PBX_REPO_PATTERN.search(line):
            continue
        if path in PACKAGE_DOCS_ALLOWLIST and "github.com/" in line:
            continue
        for pattern in PATTERNS:
            if pattern.search(line):
                failures.append(f"{rel}:{lineno}: matched {pattern.pattern!r}: {line.strip()}")

if failures:
    print("Network/off-device guardrail failed:\n")
    print("\n".join(failures))
    sys.exit(1)

print("No obvious network/off-device code found.")

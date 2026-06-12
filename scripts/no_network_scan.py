#!/usr/bin/env python3
"""Fail if obvious network code enters the local-only GradeDraft app."""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[1]
SCAN_SUFFIXES = {".swift", ".plist", ".pbxproj", ".xcprivacy", ".json", ".yml", ".yaml"}
IGNORE_DIRS = {".git", "DerivedData", ".build", ".swiftpm"}
IGNORE_PREFIXES = {
    pathlib.Path("docs/release"),
}

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
CURRICULUM_PROVENANCE_ALLOWLIST = {
    pathlib.Path("GradeDraft/Resources/JSON/curriculum_catalog_acara_v9.json"),
    pathlib.Path("GradeDraft/Resources/JSON/curriculum_catalog_acara_v9_manifest.json"),
    pathlib.Path("GradeDraft/Resources/JSON/curriculum_catalog_acara_v9_summary.json"),
}
PBX_REPO_PATTERN = re.compile(r"^\s*repositoryURL\s*=")
APPLE_PLIST_DTD_PATTERN = re.compile(r"https?://www\.apple\.com/DTDs/PropertyList-1\.0\.dtd")

failures: list[str] = []
for path in ROOT.rglob("*"):
    if any(part in IGNORE_DIRS for part in path.parts):
        continue
    if not path.is_file():
        continue
    rel = path.relative_to(ROOT)
    if rel in ALLOWLIST:
        continue
    if any(rel == prefix or prefix in rel.parents for prefix in IGNORE_PREFIXES):
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
        if path.suffix in {".plist", ".xcprivacy"} and APPLE_PLIST_DTD_PATTERN.search(line):
            continue
        if rel in PACKAGE_DOCS_ALLOWLIST and "github.com/" in line:
            continue
        if rel in CURRICULUM_PROVENANCE_ALLOWLIST:
            # These generated resources may contain official provenance URLs and
            # ordinary curriculum vocabulary that collides with product-blocked
            # analytics/network terms. Runtime Swift code remains scanned below.
            continue
        for pattern in PATTERNS:
            if pattern.search(line):
                failures.append(f"{rel}:{lineno}: matched {pattern.pattern!r}: {line.strip()}")

if failures:
    print("Network/off-device guardrail failed:\n")
    print("\n".join(failures))
    sys.exit(1)

print("No obvious network/off-device code found.")

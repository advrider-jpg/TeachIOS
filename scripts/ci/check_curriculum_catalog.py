#!/usr/bin/env python3
"""Validate the committed Australian Curriculum catalog resources."""
from __future__ import annotations

import importlib.util
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
GENERATOR = ROOT / "scripts" / "curriculum" / "build_acara_curriculum_catalog.py"


def load_generator():
    spec = importlib.util.spec_from_file_location("gradedraft_curriculum_generator", GENERATOR)
    if spec is None or spec.loader is None:
        raise RuntimeError("Could not load curriculum catalog generator")
    module = importlib.util.module_from_spec(spec)
    sys.modules[spec.name] = module
    spec.loader.exec_module(module)
    return module


def main() -> int:
    module = load_generator()
    failures = list(module.validate_files())
    pbxproj = ROOT / "GradeDraft.xcodeproj" / "project.pbxproj"
    text = pbxproj.read_text(encoding="utf-8") if pbxproj.exists() else ""
    for resource in [
        "curriculum_catalog_acara_v9.json",
        "curriculum_catalog_acara_v9_index.json",
        "curriculum_catalog_acara_v9_manifest.json",
        "curriculum_catalog_acara_v9_summary.json",
    ]:
        if resource not in text:
            failures.append(f"Xcode project does not include bundled curriculum resource {resource}")
    for shard in sorted((ROOT / "GradeDraft" / "Resources" / "JSON" / "CurriculumShards").glob("*.json")):
        if shard.name not in text:
            failures.append(f"Xcode project does not include bundled curriculum shard {shard.name}")
    if failures:
        print("Curriculum catalog validator failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1
    print("Curriculum catalog validator passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

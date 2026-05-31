#!/usr/bin/env python3
"""Guard the GradeDraft CI workflow against accidental weakening."""
from __future__ import annotations

import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
WORKFLOW = ROOT / ".github" / "workflows" / "swift.yml"


def require(condition: bool, failures: list[str], message: str) -> None:
    if not condition:
        failures.append(message)


def job_block(text: str, job_name: str) -> str:
    lines = text.splitlines()
    start: int | None = None
    for index, line in enumerate(lines):
        if line == f"  {job_name}:":
            start = index + 1
            break
    if start is None:
        return ""
    block: list[str] = []
    for line in lines[start:]:
        if re.match(r"^  [A-Za-z0-9_-]+:\s*$", line):
            break
        block.append(line)
    return "\n".join(block)


def main() -> int:
    text = WORKFLOW.read_text(encoding="utf-8")
    failures: list[str] = []
    required_jobs = [
        "static-policy",
        "workflow-lint",
        "swiftlint",
        "xcode-unit-tests",
        "screenshot-smoke",
        "release-build",
        "ci-summary",
    ]

    require("name: GradeDraft CI" in text, failures, "Primary workflow must be named GradeDraft CI.")
    require(re.search(r"^permissions:\n  contents: read", text, re.MULTILINE) is not None, failures, "Workflow must use permissions: contents: read.")
    require(re.search(r"^concurrency:", text, re.MULTILINE) is not None, failures, "Workflow must define concurrency.")
    require("macos-latest" not in text, failures, "Apple jobs must not use macos-latest.")
    require("runs-on: macos-26" in text, failures, "Apple jobs must use an explicit macos-26 runner.")
    require("scripts/no_network_scan.py" in text, failures, "No-network guardrail must run directly.")
    require("scripts/export_hardening_scan.py" in text, failures, "Export-hardening guardrail must run directly.")
    require("scripts/ci/bad_string_scan.py" in text, failures, "Bad string scan must run from a script.")
    require("scripts/ci/check_native_ui_refactor.py" in text, failures, "Native UI refactor guardrail must run.")
    require("scripts/ci/check_xcode_project_membership.py" in text, failures, "Xcode project membership scan must run.")
    require("scripts/ci/check_ci_contract.py" in text, failures, "CI contract scan must run.")
    require("scripts/ci/select_xcode.sh" in text, failures, "Xcode selection must use the shared script.")
    require("scripts/ci/select_ios_simulator.py" in text, failures, "Simulator selection must use the shared script.")
    require("actionlint .github/workflows/*.yml" in text, failures, "Workflow lint must run actionlint.")

    for job in required_jobs:
        block = job_block(text, job)
        require(bool(block), failures, f"Missing required job: {job}.")
        require("timeout-minutes:" in block, failures, f"Job {job} must define timeout-minutes.")

    unit = job_block(text, "xcode-unit-tests")
    screenshot = job_block(text, "screenshot-smoke")
    release = job_block(text, "release-build")
    require("continue-on-error: true" not in unit, failures, "Deterministic Xcode tests must not use broad continue-on-error.")
    require("-skip-testing:GradeDraftTests/GradeDraftScreenshotTests" in unit, failures, "Deterministic Xcode tests must skip screenshot tests.")
    require("ARCHS=arm64" in unit, failures, "Deterministic Xcode tests must pin simulator builds to arm64.")
    require("-only-testing:GradeDraftTests/GradeDraftScreenshotTests" in screenshot, failures, "Screenshot job must only run screenshot tests.")
    require("ARCHS=arm64" in screenshot, failures, "Screenshot tests must pin simulator builds to arm64.")
    require("CODE_SIGNING_ALLOWED=NO" in release, failures, "Release build must disable signing for CI.")
    require("configuration Release" in release or "-configuration Release" in release, failures, "Release build must use Release configuration.")

    artifact_tokens = [
        "actions/upload-artifact@v4",
        ".xcresult",
        "xcode-logs",
        "screenshots/*.png",
        "xcode-unit-tests-output",
        "xcode-screenshot-smoke-output",
        "xcode-release-build-output",
    ]
    for token in artifact_tokens:
        require(token in text, failures, f"Workflow must upload artifact/log token: {token}.")

    if failures:
        print("CI contract guardrail failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1
    print("CI contract guardrail passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env python3
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[2]
SCREEN_DIR = ROOT / "GradeDraft" / "UI" / "Screens"
UI_DIR = ROOT / "GradeDraft" / "UI"

failures: list[str] = []
forbidden = ["GroupedListCard", "EmptyState", "TopLevelHeader", "DeepWorkflowHeader"]

for path in SCREEN_DIR.glob("*.swift"):
    text = path.read_text(encoding="utf-8")
    for token in forbidden:
        if token in text:
            failures.append(f"{path.relative_to(ROOT)}: forbidden token {token}")

scroll_allowed = {"ReviewScannedTextScreen.swift"}
# Match the `ScrollView` container type only. A word boundary avoids false positives on
# `ScrollViewReader`/`ScrollViewProxy`, which coordinate scrolling within a native List/Form
# (the proxy lets a row scroll a Form section into view) and are not root scroll containers.
scrollview_pattern = re.compile(r"\bScrollView\b")
for path in SCREEN_DIR.glob("*.swift"):
    text = path.read_text(encoding="utf-8")
    if scrollview_pattern.search(text) and path.name not in scroll_allowed:
        failures.append(f"{path.relative_to(ROOT)}: root ScrollView is not allowed after native UI refactor")

list_required = ["HomeScreen.swift", "AssignmentsScreen.swift", "ClassesScreen.swift", "ReviewScreen.swift"]
form_required = [
    "ClassDetailRosterScreen.swift",
    "AssignmentOverviewScreen.swift",
    "RubricInstructionsScreen.swift",
    "AIReadinessScreen.swift",
    "AIPacketPreviewScreen.swift",
    "StudentWorkScreen.swift",
    "FinalReviewScreen.swift",
    "ExportsRestoreScreen.swift",
    "SettingsAboutLocalPrivacyScreen.swift",
]

for filename in list_required:
    text = (SCREEN_DIR / filename).read_text(encoding="utf-8")
    if not re.search(r"\bList\s*\{", text):
        failures.append(f"{filename}: expected native List")
    if ".listStyle(.insetGrouped)" not in text and "gradeDraftNativeGroupedList" not in text:
        failures.append(f"{filename}: expected inset grouped list styling")

for filename in form_required:
    text = (SCREEN_DIR / filename).read_text(encoding="utf-8")
    if not re.search(r"\bForm\s*\{", text):
        failures.append(f"{filename}: expected native Form")

review_scanned = (SCREEN_DIR / "ReviewScannedTextScreen.swift").read_text(encoding="utf-8")
if not re.search(r"\b(List|Form)\s*\{", review_scanned):
    failures.append("ReviewScannedTextScreen.swift: expected native List or Form")

ui_text = "\n".join(path.read_text(encoding="utf-8") for path in UI_DIR.rglob("*.swift"))
if "ContentUnavailableView" not in ui_text:
    failures.append("Expected ContentUnavailableView somewhere in UI layer")

required_searchable = ["AssignmentsScreen.swift", "ReviewScreen.swift"]
for filename in required_searchable:
    text = (SCREEN_DIR / filename).read_text(encoding="utf-8")
    if ".searchable" not in text:
        failures.append(f"{filename}: expected searchable modifier")

rows_text = (UI_DIR / "DesignSystem" / "Rows.swift").read_text(encoding="utf-8")
if "chevron.right" in rows_text:
    failures.append("Rows.swift: native NavigationLink rows must not draw manual chevrons")

snapshot_tests = ROOT / "GradeDraftTests" / "NativeUIRefactorSnapshotTests.swift"
if snapshot_tests.exists():
    snapshot_text = snapshot_tests.read_text(encoding="utf-8")
    required_screen_instantiations = [
        "HomeScreen(",
        "AssignmentsScreen(",
        "ClassesScreen(",
        "ReviewScreen(",
        "AssignmentOverviewScreen(",
        "StudentWorkScreen(",
        "ReviewScannedTextScreen(",
        "FinalReviewScreen(",
        "ExportsRestoreScreen(",
        "SettingsAboutLocalPrivacyScreen(",
    ]
    for token in required_screen_instantiations:
        if token not in snapshot_text:
            failures.append(f"NativeUIRefactorSnapshotTests.swift: expected real screen instantiation {token}")
    if "UIHostingController" not in snapshot_text:
        failures.append("NativeUIRefactorSnapshotTests.swift: expected hosted SwiftUI screen snapshots")
    if "nativeSnapshot(screen:" in snapshot_text:
        failures.append("NativeUIRefactorSnapshotTests.swift: manual checklist snapshots are not allowed")
else:
    failures.append("GradeDraftTests/NativeUIRefactorSnapshotTests.swift is required")

if failures:
    print("Native UI refactor check failed:")
    for failure in failures:
        print(f"- {failure}")
    sys.exit(1)

print("Native UI refactor check passed.")

#!/usr/bin/env python3
"""Static production-readiness checks that do not require Xcode."""
from __future__ import annotations

import json
import pathlib
import plistlib
import re
import struct
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
failures: list[str] = []


def fail(message: str) -> None:
    failures.append(message)


def read(path: pathlib.Path) -> str:
    return path.read_text(encoding="utf-8", errors="ignore")


# 1. Placeholder identity must not survive in production configuration surfaces.
for rel in ["GradeDraft.xcodeproj/project.pbxproj", "GradeDraft/Resources/Info.plist"]:
    path = ROOT / rel
    if path.exists() and "com.example" in read(path):
        fail(f"{rel} still contains com.example bundle identifier text.")

# 2. Required release files.
required_files = [
    "Config/Shared.xcconfig",
    "Config/Debug.xcconfig",
    "Config/Release.xcconfig",
    "GradeDraft/Resources/Info.plist",
    "GradeDraft/Resources/PrivacyInfo.xcprivacy",
    "GradeDraft/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json",
    "GradeDraft/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png",
    "GradeDraft/Resources/JSON/curriculum_catalog_acara_v9.json",
    "GradeDraft/Resources/JSON/curriculum_catalog_acara_v9_index.json",
    "GradeDraft/Resources/JSON/curriculum_catalog_acara_v9_manifest.json",
    "GradeDraft/Resources/JSON/curriculum_catalog_acara_v9_summary.json",
    "docs/release/PRODUCTION_READINESS_CHECKLIST.md",
    "docs/release/APP_STORE_METADATA.md",
    "docs/release/PRIVACY_REVIEW.md",
    "docs/release/MANUAL_QA_PLAN.md",
    "docs/release/MANUAL_QA_RESULTS.md",
    "docs/release/TESTFLIGHT_NOTES.md",
    "docs/release/APP_REVIEW_NOTES.md",
    "docs/release/RELEASE_BLOCKERS.md",
    "docs/release/RELEASE_STATUS.md",
]
for rel in required_files:
    if not (ROOT / rel).exists():
        fail(f"Missing required production-readiness file: {rel}")

curriculum_shards = sorted((ROOT / "GradeDraft/Resources/JSON/CurriculumShards").glob("*.json"))
if len(curriculum_shards) < 18:
    fail("Bundled Australian Curriculum resources must include source-key item shards.")
for shard in curriculum_shards:
    if shard.stat().st_size > 5_000_000:
        fail(f"Curriculum shard {shard.name} is larger than 5 MB; split the bundled catalog into smaller bounded shards.")

# 3. Package locking is required for release readiness.
resolved_candidates = list(ROOT.glob("**/Package.resolved"))
if not resolved_candidates:
    fail("No Package.resolved found. Run Xcode package resolution on macOS/Xcode and commit the generated file before release readiness can pass.")

# 4. Info.plist protected-resource keys.
info_path = ROOT / "GradeDraft/Resources/Info.plist"
if info_path.exists():
    info = plistlib.loads(info_path.read_bytes())
    for key in ["NSCameraUsageDescription", "NSPhotoLibraryUsageDescription"]:
        value = str(info.get(key, "")).strip()
        if not value:
            fail(f"Info.plist missing non-empty {key}.")
    source = "\n".join(path.read_text(encoding="utf-8", errors="ignore") for path in (ROOT / "GradeDraft").rglob("*.swift"))
    if "LAContext" in source or "LocalAuthentication" in source:
        if not str(info.get("NSFaceIDUsageDescription", "")).strip():
            fail("Info.plist missing NSFaceIDUsageDescription while LocalAuthentication/LAContext is used.")

# 5. Privacy manifest structure.
privacy_path = ROOT / "GradeDraft/Resources/PrivacyInfo.xcprivacy"
if privacy_path.exists():
    privacy = plistlib.loads(privacy_path.read_bytes())
    if privacy.get("NSPrivacyTracking") is not False:
        fail("Privacy manifest must explicitly set NSPrivacyTracking to false unless tracking is legally reviewed.")
    if privacy.get("NSPrivacyTrackingDomains") not in ([], None):
        fail("Privacy manifest contains tracking domains; GradeDraft should not track users.")
    if not isinstance(privacy.get("NSPrivacyCollectedDataTypes", []), list):
        fail("NSPrivacyCollectedDataTypes must be an array.")
    if not isinstance(privacy.get("NSPrivacyAccessedAPITypes", []), list):
        fail("NSPrivacyAccessedAPITypes must be an array.")
    source = "\n".join(path.read_text(encoding="utf-8", errors="ignore") for path in (ROOT / "GradeDraft").rglob("*.swift"))
    if "UserDefaults" in source:
        accessed = privacy.get("NSPrivacyAccessedAPITypes", [])
        has_user_defaults_reason = any(
            entry.get("NSPrivacyAccessedAPIType") == "NSPrivacyAccessedAPICategoryUserDefaults"
            and "CA92.1" in entry.get("NSPrivacyAccessedAPITypeReasons", [])
            for entry in accessed
            if isinstance(entry, dict)
        )
        if not has_user_defaults_reason:
            fail("Swift source uses UserDefaults but PrivacyInfo.xcprivacy does not declare NSPrivacyAccessedAPICategoryUserDefaults reason CA92.1.")

# 6. Release support/contact surfaces must either be final or explicitly block readiness.
release_text_paths = [
    "docs/release/APP_STORE_METADATA.md",
    "docs/release/APP_REVIEW_NOTES.md",
    "docs/release/SUPPORT_PAGE_COPY.md",
    "docs/release/support_site/pages/contact.html",
]
for rel in release_text_paths:
    path = ROOT / rel
    if not path.exists():
        continue
    text = read(path)
    for token in ["placeholder", "replace@example.com", "https://markforme.app"]:
        if token.lower() in text.lower():
            fail(f"{rel} contains unresolved release support/contact value: {token}")
    for token in ["not configured", "release blocked", "must be configured before release"]:
        if token in text.lower():
            fail(f"{rel} explicitly says release support/contact is not configured: {token}")

release_doc_root = ROOT / "docs/release"
if release_doc_root.exists():
    for path in release_doc_root.rglob("*"):
        if path.suffix.lower() not in {".md", ".html", ".json", ".txt"}:
            continue
        rel = str(path.relative_to(ROOT)).replace("\\", "/")
        text = read(path).lower()
        for token in ["replace before release", "replace before submission", "replace contact details", "placeholders to replace"]:
            if token in text:
                fail(f"{rel} contains unresolved release placeholder text: {token}")

# 7. Manual QA evidence must not be an unrun placeholder for release readiness.
manual_qa_path = ROOT / "docs/release/MANUAL_QA_RESULTS.md"
if manual_qa_path.exists():
    manual_qa_text = read(manual_qa_path).lower()
    if "no simulator" in manual_qa_text or "not run" in manual_qa_text or "unavailable" in manual_qa_text:
        fail("docs/release/MANUAL_QA_RESULTS.md records unrun manual QA; release readiness requires dated simulator/device evidence.")

# 8. Asset catalog and project wiring.
pbxproj = ROOT / "GradeDraft.xcodeproj/project.pbxproj"
if pbxproj.exists():
    text = read(pbxproj)
    if "ASSETCATALOG_COMPILER_APPICON_NAME" not in text or "AppIcon" not in text:
        fail("Xcode project must set ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon.")
    for token in ["Assets.xcassets", "PrivacyInfo.xcprivacy", "curriculum_catalog_acara_v9.json", "curriculum_catalog_acara_v9_index.json", "LocalDataProtection.swift", "CurriculumBrowserScreen.swift"]:
        if token not in text:
            fail(f"Xcode project must reference {token}.")
    if "SnapshotTesting" in text:
        app_target_match = re.search(r'name = "?MarkForMe"?;.*?packageProductDependencies = \((.*?)\);', text, re.S)
        if app_target_match and "SnapshotTesting" in app_target_match.group(1):
            fail("SnapshotTesting must not be linked into the app target.")

icon = ROOT / "GradeDraft/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"
if icon.exists():
    data = icon.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        fail("AppIcon-1024.png is not a PNG file.")
    elif len(data) > 24:
        width, height = struct.unpack(">II", data[16:24])
        if (width, height) != (1024, 1024):
            fail(f"AppIcon-1024.png must be 1024x1024, got {(width, height)}.")

# 9. Dependency docs include every current Swift package.
package_names = ["GRDB.swift", "swift-markdown", "TPPDF", "ZIPFoundation", "swift-snapshot-testing"]
for rel in ["docs/DEPENDENCIES.md", "docs/OSS_REVIEW.md"]:
    path = ROOT / rel
    if not path.exists():
        fail(f"Missing dependency review doc: {rel}")
        continue
    text = read(path).lower()
    for package in package_names:
        if package.lower() not in text:
            fail(f"{rel} does not mention {package}.")

# 10. Network/analytics hard stop in app source.
for path in (ROOT / "GradeDraft").rglob("*.swift"):
    text = path.read_text(encoding="utf-8", errors="ignore")
    for token in ["URLSession", "Firebase", "Amplitude", "Mixpanel", "Sentry", "RevenueCat", "Telemetry", "Analytics"]:
        if re.search(rf"\b{re.escape(token)}\b", text):
            fail(f"Forbidden network/analytics token {token!r} appears in {path.relative_to(ROOT)}")

if failures:
    print("Production static readiness check failed:")
    for failure in failures:
        print(f"- {failure}")
    sys.exit(1)

print("Production static readiness check passed.")

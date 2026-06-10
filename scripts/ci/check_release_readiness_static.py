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
    "GradeDraft/Resources/JSON/curriculum_catalog_acara_v9_manifest.json",
    "GradeDraft/Resources/JSON/curriculum_catalog_acara_v9_summary.json",
    "docs/release/PRODUCTION_READINESS_CHECKLIST.md",
    "docs/release/APP_STORE_METADATA.md",
    "docs/release/PRIVACY_REVIEW.md",
    "docs/release/MANUAL_QA_PLAN.md",
    "docs/release/MANUAL_QA_RESULTS.md",
    "docs/release/TESTFLIGHT_NOTES.md",
    "docs/release/APP_REVIEW_NOTES.md",
]
for rel in required_files:
    if not (ROOT / rel).exists():
        fail(f"Missing required production-readiness file: {rel}")

# 3. Package locking or explicit Xcode-unavailable release blocker.
resolved_candidates = list(ROOT.glob("**/Package.resolved"))
resolution_blocker = ROOT / "docs" / "release" / "PACKAGE_RESOLUTION_PENDING.md"
if not resolved_candidates and not resolution_blocker.exists():
    fail("No Package.resolved found and no explicit package-resolution blocker document exists.")

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
    collected_data_types = privacy.get("NSPrivacyCollectedDataTypes", [])
    if not isinstance(collected_data_types, list):
        fail("NSPrivacyCollectedDataTypes must be an array.")
    elif collected_data_types:
        fail("NSPrivacyCollectedDataTypes must remain empty for the current local-only/Data Not Collected privacy posture.")
    accessed_api_types = privacy.get("NSPrivacyAccessedAPITypes", [])
    if not isinstance(accessed_api_types, list):
        fail("NSPrivacyAccessedAPITypes must be an array.")
        accessed_api_types = []
    reasons_by_type = {
        entry.get("NSPrivacyAccessedAPIType"): set(entry.get("NSPrivacyAccessedAPITypeReasons", []))
        for entry in accessed_api_types
        if isinstance(entry, dict)
    }
    required_reasons = {
        "NSPrivacyAccessedAPICategoryUserDefaults": "CA92.1",
        "NSPrivacyAccessedAPICategoryFileTimestamp": "C617.1",
    }
    for api_type, reason in required_reasons.items():
        if reason not in reasons_by_type.get(api_type, set()):
            fail(f"Privacy manifest missing required reason {reason} for {api_type}.")

# 6. Asset catalog and project wiring.
pbxproj = ROOT / "GradeDraft.xcodeproj/project.pbxproj"
if pbxproj.exists():
    text = read(pbxproj)
    if "ASSETCATALOG_COMPILER_APPICON_NAME" not in text or "AppIcon" not in text:
        fail("Xcode project must set ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon.")
    for token in ["Assets.xcassets", "PrivacyInfo.xcprivacy", "curriculum_catalog_acara_v9.json", "LocalDataProtection.swift", "CurriculumBrowserScreen.swift"]:
        if token not in text:
            fail(f"Xcode project must reference {token}.")
    if "SnapshotTesting" in text:
        app_target_match = re.search(r'name = "?Mark My Work"?;.*?packageProductDependencies = \((.*?)\);', text, re.S)
        if app_target_match and "SnapshotTesting" in app_target_match.group(1):
            fail("SnapshotTesting must not be linked into the app target.")

icon_set = ROOT / "GradeDraft/Resources/Assets.xcassets/AppIcon.appiconset"
icon = icon_set / "AppIcon-1024.png"
if icon.exists():
    data = icon.read_bytes()
    if not data.startswith(b"\x89PNG\r\n\x1a\n"):
        fail("AppIcon-1024.png is not a PNG file.")
    elif len(data) > 24:
        width, height = struct.unpack(">II", data[16:24])
        if (width, height) != (1024, 1024):
            fail(f"AppIcon-1024.png must be 1024x1024, got {(width, height)}.")

contents_path = icon_set / "Contents.json"
if contents_path.exists():
    icon_contents = json.loads(contents_path.read_text(encoding="utf-8"))
    image_entries = icon_contents.get("images", [])
    required_icon_slots = {
        ("iphone", "20x20", "2x"), ("iphone", "20x20", "3x"),
        ("iphone", "29x29", "2x"), ("iphone", "29x29", "3x"),
        ("iphone", "40x40", "2x"), ("iphone", "40x40", "3x"),
        ("iphone", "60x60", "2x"), ("iphone", "60x60", "3x"),
        ("ipad", "20x20", "1x"), ("ipad", "20x20", "2x"),
        ("ipad", "29x29", "1x"), ("ipad", "29x29", "2x"),
        ("ipad", "40x40", "1x"), ("ipad", "40x40", "2x"),
        ("ipad", "76x76", "1x"), ("ipad", "76x76", "2x"),
        ("ipad", "83.5x83.5", "2x"),
        ("ios-marketing", "1024x1024", "1x"),
    }
    actual_icon_slots = {(entry.get("idiom"), entry.get("size"), entry.get("scale")) for entry in image_entries}
    for slot in sorted(required_icon_slots - actual_icon_slots):
        fail(f"App icon catalog missing required slot {slot}.")
    for entry in image_entries:
        filename = entry.get("filename")
        if not filename:
            fail(f"App icon slot lacks filename: {entry}")
            continue
        image_path = icon_set / filename
        if not image_path.exists():
            fail(f"App icon file missing: {filename}")
            continue
        data = image_path.read_bytes()
        if len(data) > 24 and data.startswith(b"\x89PNG\r\n\x1a\n"):
            width, height = struct.unpack(">II", data[16:24])
            size = entry.get("size", "0x0").split("x", 1)[0]
            scale = entry.get("scale", "1x").removesuffix("x")
            try:
                expected_pixels = int(float(size) * int(scale))
            except ValueError:
                expected_pixels = None
            if expected_pixels and (width, height) != (expected_pixels, expected_pixels):
                fail(f"{filename} has dimensions {(width, height)} but icon slot {entry} requires {expected_pixels}x{expected_pixels}.")

# 7. Dependency docs include every current Swift package.
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

# 8. Sensitive handoff and clipboard hardening.
app_routing = ROOT / "GradeDraft/AppRouting.swift"
app_intents = ROOT / "GradeDraft/AppIntents/GradeDraftAppIntents.swift"
for rel_path in [app_routing, app_intents]:
    if rel_path.exists() and "payloadText" in read(rel_path):
        fail(f"{rel_path.relative_to(ROOT)} must not define or persist Shortcut student-work payloadText.")
if app_intents.exists() and "AppLaunchSensitivePayloadStore.saveText" not in read(app_intents):
    fail("AddPastedStudentWorkIntent must use file-backed sensitive payload handoff.")
for path in (ROOT / "GradeDraft").rglob("*.swift"):
    text = path.read_text(encoding="utf-8", errors="ignore")
    if "UIPasteboard.general.string" in text:
        fail(f"Use expiring local-only pasteboard items instead of UIPasteboard.general.string in {path.relative_to(ROOT)}")

# 9. Network/analytics hard stop in app source.
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

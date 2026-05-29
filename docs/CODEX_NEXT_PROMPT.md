# Codex Next Validation Prompt

Use this prompt for the next macOS/Xcode validation pass after applying `GradeDraft_all_features_completion_v3.patch`.

## Goal

Validate the source-implemented GradeDraft v3 feature set on Apple tooling without expanding product scope. Keep the local-only posture: no cloud AI, remote OCR, backend URL, analytics SDK, account login, telemetry, subscriptions, hosted assets, Firebase, RevenueCat, or server API.

## Context

The patch implements source-level support for PDF export, ZIP/archive export, PDF import, side-by-side OCR review, per-line OCR evidence linking, bounding-box traceability, Markdown rubric import, normalized GRDB persistence, offline curriculum mapping, roster workflows, and backup/restore UI.

Runtime validation still requires Xcode because this environment does not launch the iOS app, run XCTest, render PDFKit/UIKit output, exercise Vision/VisionKit capture, or call Foundation Models APIs.

## Required validation steps on macOS/Xcode

1. Apply the patch from the repository root with `patch -p1 < GradeDraft_all_features_completion_v3.patch`.
2. Open `GradeDraft.xcodeproj` and confirm the app and test targets include the new service files.
3. Build the app target.
4. Build and run the unit-test target.
5. Confirm PDFKit import, UIKit PDF export, Vision/VisionKit OCR, SwiftUI file import/share sheets, and Foundation Models availability gates compile against the installed SDK.
6. Run a simulator/device smoke flow for PDF import, OCR review, evidence linking, final approval, student PDF export, teacher audit ZIP export, roster import, curriculum mapping, full backup, and restore conflict choices.
7. Preserve teacher-confirmation gating and export sensitivity warnings throughout any fixes.

## Scope guardrails

Do not add hosted services, remote model calls, network curriculum downloads, account systems, analytics, telemetry, subscription SDKs, or external asset hosting. Do not alter `docs/GRADING_CONTENT_SOURCE_OF_TRUTH.md` except typo-level corrections. Keep student-facing export content separated from teacher-audit content.

# Test Plan

## Source guardrails

Run:

```bash
python3 scripts/no_network_scan.py
```

The script searches Swift, plist, package, and project files for obvious network usage such as `URLSession`, remote URL literals, network framework APIs, and common analytics SDK strings.

## Unit tests included in v2

- Deterministic totals ignore model-written totals.
- Empty rubric blocks grading.
- Empty student text blocks grading.
- JSON extraction handles markdown wrapping and braces inside strings.
- OCR quality summary flags low-confidence text.
- Draft validator clamps out-of-range points.
- Missing evidence forces teacher review.
- Markdown export prefers final review over model draft.

## Manual tests

1. Launch in airplane mode.
2. Create a new assignment.
3. Apply the 4-point short-answer rubric template.
4. Paste student text and draft a grade on a compatible physical device.
5. Confirm that a simulator or unsupported device shows local AI unavailable and no cloud option.
6. Scan a printed paragraph and confirm OCR extraction.
7. Add a low-quality image and confirm low-confidence OCR is visible.
8. Finalize a draft and confirm the UI distinguishes final review from model draft.
9. Prepare a Markdown report and confirm sharing is explicit.
10. Delete an assignment and confirm local persistence updates.

## Shipping review

Before release:

- Inspect all dependencies for networking.
- Confirm `PrivacyInfo.xcprivacy` remains accurate.
- Run packet capture with local networking disabled.
- Confirm no crash/analytics SDKs collect student data.
- Confirm exported reports are created only by explicit teacher action.
- Add UI tests for assignment creation, template application, OCR text paste, draft-unavailable state, finalization, and export.

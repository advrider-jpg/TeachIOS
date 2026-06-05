#!/usr/bin/env python3
"""Validate the local AI evaluation fixture corpus."""
from __future__ import annotations

import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
FIXTURE_ROOT = ROOT / "GradeDraftTests" / "Fixtures" / "AIEvaluation"

REQUIRED_DATASETS = [
    "prompt_injection_cases.json",
    "ocr_uncertainty_cases.json",
    "source_reference_cases.json",
    "prohibited_inference_cases.json",
    "answer_key_strict_cases.json",
    "exemplar_comparison_cases.json",
    "formative_feedback_cases.json",
    "summative_caution_cases.json",
    "conventions_safe_cases.json",
    "eald_sensitive_cases.json",
    "adjustment_context_cases.json",
    "off_prompt_cases.json",
    "misconception_cases.json",
    "long_context_cases.json",
    "unsupported_language_cases.json",
    "guardrail_error_cases.json",
    "feedback_rewrite_cases.json",
    "batch_workflow_cases.json",
]

REQUIRED_FIELDS = {
    "id",
    "title",
    "categories",
    "assignment",
    "rubric",
    "reviewedStudentText",
    "selectedConstraintIDs",
    "answerKeyText",
    "exemplarText",
    "curriculumReference",
    "ocrReviewStatus",
    "expected",
}

REQUIRED_EXPECTED_FIELDS = {
    "mustNotContain",
    "mustContainTeacherReviewReasons",
    "maxAllowedPointsByCriterion",
    "requiresTeacherReview",
    "requiresPromptInjectionFlag",
    "requiresOCRReview",
    "requiresSourceReferences",
    "expectedConstraintIDs",
}


def main() -> int:
    failures: list[str] = []
    schema = FIXTURE_ROOT / "evaluation_case_schema.json"
    if not schema.exists():
        failures.append("Missing evaluation_case_schema.json")

    seen_ids: set[str] = set()
    seen_categories: set[str] = set()

    for dataset in REQUIRED_DATASETS:
        path = FIXTURE_ROOT / dataset
        if not path.exists():
            failures.append(f"Missing {dataset}")
            continue
        try:
            cases = json.loads(path.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            failures.append(f"{dataset} is invalid JSON: {exc}")
            continue
        if not isinstance(cases, list) or not cases:
            failures.append(f"{dataset} must be a non-empty array")
            continue
        for index, case in enumerate(cases):
            label = f"{dataset}[{index}]"
            if not isinstance(case, dict):
                failures.append(f"{label} must be an object")
                continue
            missing = sorted(REQUIRED_FIELDS - set(case))
            if missing:
                failures.append(f"{label} missing fields: {', '.join(missing)}")
                continue
            case_id = case["id"]
            if case_id in seen_ids:
                failures.append(f"Duplicate evaluation case id: {case_id}")
            seen_ids.add(case_id)
            categories = case["categories"]
            if not isinstance(categories, list) or not categories:
                failures.append(f"{label} categories must be non-empty")
            else:
                seen_categories.update(str(category) for category in categories)
            expected = case["expected"]
            if not isinstance(expected, dict):
                failures.append(f"{label}.expected must be an object")
            else:
                missing_expected = sorted(REQUIRED_EXPECTED_FIELDS - set(expected))
                if missing_expected:
                    failures.append(f"{label}.expected missing fields: {', '.join(missing_expected)}")
            if "eald-sensitive" in case["selectedConstraintIDs"] and "teacher" not in case["assignment"]["customInstructions"].lower():
                failures.append(f"{case_id} selects eald-sensitive without teacher-provided context")
            if "adjustment-context" in case["selectedConstraintIDs"] and "teacher-provided" not in case["assignment"]["customInstructions"].lower():
                failures.append(f"{case_id} selects adjustment-context without teacher-provided context")

    expected_categories = {name.removesuffix("_cases.json") for name in REQUIRED_DATASETS}
    missing_categories = sorted(expected_categories - seen_categories)
    if missing_categories:
        failures.append(f"Missing fixture categories: {', '.join(missing_categories)}")

    if failures:
        print("AI evaluation fixture check failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1

    print(f"AI evaluation fixture check passed: {len(seen_ids)} case(s) across {len(seen_categories)} categories.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

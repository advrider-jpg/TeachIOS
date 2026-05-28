# Australian Curriculum extraction package for GradeDraft / TeachIOS

Prepared: 2026-05-28

This package extracts and synthesises content from the public Australian Curriculum website that is relevant to a proposed local-first iOS/iPadOS teacher grading assistant for Australian teachers.

## Scope

The target app is a teacher-controlled rubric-assisted grading assistant. It scans, imports, or accepts pasted student work; extracts text where applicable; requires teacher review of uncertain OCR; applies a rubric, answer key, achievement standard, exemplar, and/or teacher instructions; produces a proposed criterion-by-criterion score with evidence, explanation, uncertainty flags, and draft feedback; and requires teacher final approval.

## Copyright and extraction note

This package is not a wholesale mirror of the Australian Curriculum website. It extracts relevant product requirements, short source-backed notes, app implications, and implementation-ready mappings. Where official wording is necessary, it is kept brief and source-attributed. For the actual curriculum content, the app should integrate with official downloadable or machine-readable sources subject to ACARA/Education Services Australia terms and licensing.

## Package contents

| File | Purpose |
|---|---|
| `00_source_inventory.md` | Source URLs, relevance ratings, and extraction scope. |
| `01_curriculum_structure.md` | Three dimensions, learning areas, content descriptions, achievement standards, elaborations, downloads, MRAC. |
| `02_assessment_reporting_work_samples.md` | Planning/teaching/assessment/reporting, achievement standards, annotated work samples, on-balance judgement implications. |
| `03_formative_assessment.md` | Formative assessment model, design framework, evidence capture, responsive teaching implications. |
| `04_student_diversity_and_adjustments.md` | Diversity, disability, gifted/talented, EAL/D implications for grading and app safety. |
| `05_learning_area_market_map.md` | Learning areas/subjects and how they map to app modes and deferrals. |
| `06_machine_readable_curriculum_integration.md` | MRAC, downloads, content ingestion strategy, data model. |
| `07_app_requirements_for_australian_teachers.md` | Product requirements derived from ACARA content. |
| `08_data_model_schema_implications.md` | Data objects and JSON schema implications. |
| `09_product_positioning_and_copy.md` | Australian-market copy, claims to make, claims to avoid. |
| `10_implementation_backlog.md` | Build backlog, acceptance criteria, and research gaps. |
| `SOURCES.md` | Source list with URLs and notes. |

## Highest-level findings

1. The app should align itself with **content descriptions**, **achievement standards**, **work samples**, and teacher-controlled judgement rather than claiming independent grading authority.
2. The curriculum is explicitly implemented through state/territory and sector policies, so the app must support jurisdiction-specific configuration instead of assuming one uniform reporting rule.
3. ACARA’s work-sample model strongly supports the app’s evidence-based design: focus on what is evident in the student work, not unsupported assumptions about time, effort, or support.
4. Formative assessment materials support an app design centred on curriculum alignment, manageable evidence capture, actionable feedback, and responsive teaching decisions.
5. Student diversity materials require strong safeguards against inferring disability, English proficiency, ability, support level, intent, effort, or context from student work alone.
6. The Machine-readable Australian Curriculum is strategically important for future structured curriculum alignment, searchable content, and standard-linked rubric templates.

## Recommended product stance

Use this language:

> A local-first iPad app that helps Australian teachers draft evidence-linked, curriculum-aligned feedback and score suggestions for teacher review.

Avoid this language:

> Automatically grades Australian Curriculum work.

The second formulation overclaims both pedagogically and jurisdictionally.

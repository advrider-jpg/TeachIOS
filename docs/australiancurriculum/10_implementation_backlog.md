# 10 — Implementation backlog and acceptance criteria

## Phase 1 — Australian market configuration

### Features

- Australian English default.
- Jurisdiction and sector setting.
- Learning area/subject/year-level fields.
- Content description and achievement-standard reference fields.
- Australian Curriculum Version 9.0 source note.

### Acceptance criteria

- App can create an assignment with learning area, subject, year level, jurisdiction, and sector.
- App does not claim official curriculum ingestion unless MRAC/download import is implemented.
- UI uses Australian terminology.

## Phase 2 — Curriculum-linked rubric workflow

### Features

- Teacher can paste content description.
- Teacher can paste achievement-standard aspect.
- App can draft rubric criteria from teacher-provided curriculum text.
- Teacher must approve/edit criteria.
- Rubric criteria have stable IDs.

### Acceptance criteria

- No grading without rubric/standard.
- Model output cannot invent extra official curriculum references.
- Teacher can distinguish official pasted content from teacher-created rubric text.

## Phase 3 — Evidence-first formative mode

### Features

- Formative focus setup: focus, aim, timing, evidence.
- Feedback draft emphasises next steps.
- Teacher can save next teaching decision.
- Group summary later.

### Acceptance criteria

- Feedback includes evidence and next step.
- App does not present formative output as a final summative grade by default.

## Phase 4 — Work-sample-inspired standard judgement

### Features

- Teacher can attach exemplar/work sample references.
- App compares student work only against teacher-selected rubric/exemplar notes.
- App flags if evidence does not address all aspects of the standard.

### Acceptance criteria

- App never infers creation conditions such as time/support.
- App can note that a student sample does not address a criterion.

## Phase 5 — MRAC/download ingestion

### Features

- Import official machine-readable curriculum data.
- Store version, checksum, source URL.
- Browse/search learning areas and content descriptions offline.
- Link assignments/rubrics to official identifiers.

### Acceptance criteria

- Import is read-only and source-attributed.
- Failed import does not mutate existing data.
- Official content is visually distinguished from teacher-created content.

## Phase 6 — Student diversity safeguards

### Features

- Teacher-provided adjustment notes.
- EAL/D-sensitive content/language mode.
- Private notes excluded from student reports.
- Trait-inference validator.

### Acceptance criteria

- Model output that infers disability, effort, EAL/D status, giftedness, demographic traits, or support level is blocked or flagged.
- Teacher controls all adjustment context.
- Student-facing reports do not expose private adjustment notes.

## Phase 7 — Exports

### Features

- Student feedback PDF/Markdown.
- Teacher audit PDF/Markdown.
- CSV gradebook export.
- Archive export.

### Acceptance criteria

- Student export excludes private teacher notes.
- Teacher audit export includes source and AI/final distinction.
- CSV hardens formula-like strings.
- Export includes jurisdiction/reporting caveat.

## Phase 8 — Future modes

### Handwriting

Only assistive OCR. Teacher confirmation required.

### Diagrams/labels

Teacher-tagged regions required.

### Posters/models

Evidence organisation and feedback only; no autonomous visual grading.

### Senior secondary

Requires jurisdiction-specific research and high-stakes assessment caution.

## Research gaps

- Exact ACARA/MRAC licensing terms for app bundling/import.
- Jurisdiction-specific reporting requirements.
- Whether individual schools would permit teacher-owned local tools.
- Required privacy disclosures for Australian student data.
- OCR reliability on Australian classroom samples.
- Teacher willingness to review OCR and AI evidence.

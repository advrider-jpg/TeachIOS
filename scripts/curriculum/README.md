# Australian Curriculum catalogue generator

`build_acara_curriculum_catalog.py` normalizes Australian Curriculum Version 9.0 source material into one read-only SQLite file, `GradeDraft/Resources/Curriculum/curriculum_acara_v9.sqlite`, which is bundled with the app.

Tables:

- `source`: one row per curriculum source (learning area, general capability, cross-curriculum priority) with its version, licence and the ACARA attribution and non-endorsement text, stored once per source.
- `item`: one row per curriculum item, with code, title, description, learning area, subject, year level or band, strand, the official source URL, provenance, and `altLabels`, `parentIDs`, `childIDs` and `tags` as JSON arrays. Rows are inserted sorted by `id`.
- `itemSearch`: an FTS5 full-text index over `item` (code, title, description, strand, tags).

Commands:

```bash
python3 scripts/curriculum/build_acara_curriculum_catalog.py --refresh
python3 scripts/curriculum/build_acara_curriculum_catalog.py --refresh --workbook-only
python3 scripts/curriculum/build_acara_curriculum_catalog.py --check
python3 scripts/ci/check_curriculum_catalog.py
```

`--refresh` prefers the official MRAC JSON-LD source URLs listed in the script and falls back to the repository's official workbook (`docs/australiancurriculum/curriculum-workbook.xlsx`). `--check` rebuilds from the workbook into a temporary file and compares the rows of `source` and `item` with the committed file (not the bytes); regenerate with `--refresh --workbook-only` if it reports a difference. `scripts/ci/check_curriculum_catalog.py` validates the committed file: every source has items, every `parentIDs`/`childIDs` entry exists, and the full-text index covers every item.

The iOS app never runs these scripts and never downloads curriculum data at runtime. `CurriculumCatalogService` opens the bundled file read-only and searches it on demand.

# Australian Curriculum catalog generator

`build_acara_curriculum_catalog.py` normalizes Australian Curriculum Version 9.0 source material into bundled GradeDraft JSON resources.

Commands:

```bash
python3 scripts/curriculum/build_acara_curriculum_catalog.py --refresh
python3 scripts/curriculum/build_acara_curriculum_catalog.py --check
python3 scripts/curriculum/build_acara_curriculum_catalog.py --print-summary
```

`--refresh` prefers the official MRAC JSON-LD source URLs listed in the script. When the maintenance environment cannot reach those sources and the repository-local official workbook exists, the script records an explicit workbook fallback in the generated manifest and summary. The iOS app never runs this script and never downloads curriculum data at runtime.

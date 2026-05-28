# 06 — Machine-readable curriculum and content-ingestion strategy

## 1. Official machine-readable source

ACARA publishes the Australian Curriculum Version 9.0 as machine-readable files. The site states these files can be used to import the curriculum into a database. The MRAC page points to RDF/XML, JSON-LD, and SPARQL formats.

The Scootle MRAC details page lists machine-readable downloads by:

- learning area;
- general capability;
- cross-curriculum priority.

## 2. MRAC learning areas

The MRAC details page lists Version 9 learning-area files for:

- The Arts;
- English;
- Health and Physical Education;
- Humanities and Social Sciences;
- Languages;
- Mathematics;
- Science;
- Technologies.

The MRAC HTML pages indicate large concept sets. Examples observed:

| Learning area | Concepts shown on MRAC HTML page | Last updated |
|---|---:|---|
| English | 1,357 | 22 April 2024 |
| Mathematics | 1,563 | 22 April 2024 |
| Science | 1,360 | 22 April 2024 |

The MRAC landing page says files were updated 7 June 2024.

## 3. MRAC general capabilities

The MRAC details page lists these general capabilities:

- Critical and Creative Thinking;
- Digital Literacy;
- Ethical Understanding;
- Intercultural Understanding;
- Literacy;
- Numeracy;
- Personal and Social capability.

## 4. MRAC cross-curriculum priorities

The MRAC details page lists:

- Sustainability;
- Aboriginal and Torres Strait Islander Histories and Cultures;
- Asia and Australia’s engagement with Asia.

## 5. App integration architecture

Do not manually hard-code curriculum content in Swift. Instead:

```text
MRAC/download ingestion
→ curriculum import parser
→ local curriculum database
→ search/index
→ teacher-selected standards/content descriptions
→ rubric/assessment builder
```

## 6. Suggested local schema

```sql
curriculum_sources
- id
- name
- url
- format
- version
- retrieved_at
- checksum
- licence_note

curriculum_nodes
- id
- source_id
- external_uri
- code
- title
- description
- node_type
- learning_area
- subject
- year_level
- band
- strand
- substrand
- parent_id
- raw_json

curriculum_relationships
- id
- source_node_id
- target_node_id
- relationship_type

curriculum_tags
- id
- node_id
- dimension
- tag
```

## 7. Import safety requirements

- Preserve official identifiers/URIs.
- Store source version and retrieval date.
- Store checksum.
- Keep imported curriculum read-only unless teacher creates local custom copies.
- Do not silently edit official content.
- Allow teacher-created local rubrics to reference official content.
- Clearly distinguish official curriculum content from teacher-created rubric content.

## 8. MVP approach

For the first Australian MVP:

1. Do not ship the entire MRAC database until licensing/size/update strategy is confirmed.
2. Include a small local placeholder schema and manual curriculum-reference fields.
3. Build the app so MRAC ingestion can be added later without refactoring.
4. Allow teacher-pasted content descriptions and achievement-standard extracts.
5. Add official MRAC import as Phase 2.

## 9. Future MRAC-powered features

- Browse by learning area/year/subject.
- Search content descriptions.
- Select achievement-standard aspects.
- Auto-generate draft rubric criteria from content description verbs and achievement-standard language.
- Show general capabilities and cross-curriculum-priority connections.
- Attach official codes to grading packets.
- Create jurisdiction-specific curriculum mappings.
- Maintain offline curriculum cache.

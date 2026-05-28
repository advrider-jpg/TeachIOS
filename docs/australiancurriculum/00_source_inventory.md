# 00 — Source inventory

## Method

I reviewed the public Australian Curriculum website pages most relevant to a local-first iOS teacher grading assistant, including the F–10 curriculum overview, curriculum dimensions, learning areas, assessment/reporting guidance, implementation guidance, resources, work samples, formative assessment pages, student diversity pages, downloads, and machine-readable curriculum pages.

This is an extraction-and-synthesis package. It does not attempt to reproduce the full curriculum corpus verbatim.

## Core sources reviewed

| Source | URL | Relevance | Key extraction |
|---|---|---:|---|
| Australian Curriculum home | https://www.australiancurriculum.edu.au/ | High | Version 9.0 framing and the national expectation-setting role. |
| F–10 Curriculum overview | https://www.australiancurriculum.edu.au/f-10-curriculum/f-10-curriculum-overview | High | Version 9.0 changes, implementation framing, curriculum purpose. |
| Why do we have an Australian Curriculum? | https://www.australiancurriculum.edu.au/help/f-10-curriculum-overview/why-do-we-have-an-australian-curriculum | High | Purpose, teacher audience, first 11 years of schooling, state/territory implementation. |
| Three dimensions | https://www.australiancurriculum.edu.au/help/f-10-curriculum-overview/the-three-dimensions-of-the-australian-curriculum | High | Learning areas, general capabilities, cross-curriculum priorities; content descriptions and achievement standards. |
| Planning, teaching, assessing and reporting | https://www.australiancurriculum.edu.au/help/f-10-curriculum-overview/planning--teaching--assessing-and-reporting | Critical | How teachers use content descriptions, achievement standards, elaborations, and work samples. |
| Implementation | https://www.australiancurriculum.edu.au/help/f-10-curriculum-overview/implementation-of-the-australian-curriculum0 | High | Jurisdiction/sector control of implementation timeline and delivery. |
| Learning areas | https://www.australiancurriculum.edu.au/help/learning-areas | Critical | Eight learning areas and subjects; structure for app templates. |
| Downloads | https://www.australiancurriculum.edu.au/downloads | High | Word downloads and full curriculum Excel download. |
| MRAC page | https://www.australiancurriculum.edu.au/machine-readable-australian-curriculum | Critical | Machine-readable files for database import. |
| Scootle MRAC details | https://www.scootle.edu.au/ec/p/mrac_details | Critical | RDF/XML, JSON-LD, SPARQL curriculum vocabularies by learning area, general capability, and priority. |
| Work samples | https://www.australiancurriculum.edu.au/resources/work-samples | Critical | Evidence of student learning, annotated and reviewed by teachers/experts; standard judgement patterns. |
| Resources | https://www.australiancurriculum.edu.au/resources | Medium | Teacher implementation resources, work samples, curriculum connections, formative assessment. |
| Curriculum connections | https://www.australiancurriculum.edu.au/resources/curriculum-connections | Medium | Cross-dimensional planning themes. |
| Formative assessment | https://www.australiancurriculum.edu.au/resources/formative-assessment | Critical | Purposeful assessment design and evidence gathering. |
| Understanding formative assessment | https://www.australiancurriculum.edu.au/resources/formative-assessment/understanding-formative-assessment | Critical | Design/practice, goals/criteria, actionable feedback. |
| Designing formative assessment | https://www.australiancurriculum.edu.au/resources/formative-assessment/designing-formative-assessment | Critical | Formative focus, aim, timing, evidence; assessment types. |
| Embedding formative assessment | https://www.australiancurriculum.edu.au/resources/formative-assessment/embedding-formative-assessment | Critical | Plan → design → collect evidence → analyse → responsive teaching decisions. |
| Student diversity | https://www.australiancurriculum.edu.au/student-diversity | Critical | Inclusive design, equitable access, diverse student backgrounds. |
| Planning for diversity | https://www.australiancurriculum.edu.au/student-diversity/planning-for-diversity | Critical | CASE model: Curriculum, Abilities, Standards, Evaluation. |
| Students with disability | https://www.australiancurriculum.edu.au/student-diversity/students-with-disability | Critical | Reasonable adjustment, consultation, multiple access modes. |
| Gifted/talented students | https://www.australiancurriculum.edu.au/student-diversity/gifted-and-talented-students | High | Adjustment above enrolled year level, pre-assessment, formative assessment. |
| EAL/D students | https://www.australiancurriculum.edu.au/student-diversity/eal-d-students | Critical | SAE, language proficiency, differentiated assessment, language vs content distinction. |
| Senior secondary curriculum | https://www.australiancurriculum.edu.au/senior-secondary-curriculum | Medium | Senior subjects exist but link to Version 8.4; jurisdiction assessment complexity. |

## What was treated as relevant

The following content was extracted because it directly affects app design:

- curriculum structure and dimensions;
- learning areas and subject groupings;
- content descriptions;
- achievement standards;
- level descriptions;
- content elaborations;
- work samples;
- formative assessment design;
- evidence collection and interpretation;
- student diversity and reasonable adjustments;
- EAL/D assessment considerations;
- machine-readable curriculum and downloads;
- jurisdiction/sector implementation differences;
- reporting and achievement-standard use.

## What was not extracted in full

- Every individual content description and achievement standard. These should be ingested from official downloads/MRAC rather than manually copied into static app files.
- Work-sample PDFs or student artifacts. These should be treated as external official references and potential test inspiration, not copied into the app.
- Third-party jurisdiction resources linked from ACARA. They are noted as product requirements for later jurisdiction configuration.

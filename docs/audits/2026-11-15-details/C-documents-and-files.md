# Area C — Document and data pipelines (MarkForMe / GradeDraft)

Reviewer scope: OCR, PDF import, document scanner bridge, OCR data shape, PDF/Markdown/CSV/ZIP export, backup/restore, Markdown rubric parser, roster CSV import, curriculum catalogue and its generator, export warning/report template catalogues. Repo state: `C:\TeachIOS` at `cd64e9d`, read-only, reasoned from source (no build possible on Windows).

Stated reasons checked against: `docs/ARCHITECTURE.md` and `docs/ledgers/DECISIONS_LEDGER.md` (D001 local ZIP/PDF writing, D004 PDF import, D005 evidence bounding boxes, D006 curriculum, D007/D013 restore).

Severity counts: **Critical 0 · High 6 · Medium 10 · Low 4** (20 findings)

---

### C-01 — High — The whole 75 MB curriculum catalogue is decoded on the main thread at app launch; the "sharding" does nothing
- Area / files: `GradeDraft/GradeDraftViewModel.swift:27`; `GradeDraft/Services/CurriculumCatalogService.swift:11-49, 19-25, 152-176, 291-324`; `GradeDraft/Resources/JSON/` (index 22.4 MB, `CurriculumShards/` 53 MB, 37 shard files, 24,662 items); `scripts/curriculum/build_acara_curriculum_catalog.py:40, 725-752`; `GradeDraft/Services/LocalJSONStore.swift:345`
- What it is now and why it was probably done this way: A Python script turns the ACARA v9 source files into a small catalogue "shell", a search index and 37 "bounded" JSON shards (≤3 MB each, `MAX_SHARD_BYTES`). The docs say this keeps lookups bounded. The aim was presumably to avoid one huge JSON file and to make search fast.
- Why it is a problem: The app never loads a shard on its own. `loadBundledCatalog` decodes the shell, then loops over **every** shard and rebuilds the full 24,662-item array (lines 36-48). The 22 MB index is then decoded as a second copy (lines 20-25), and it repeats the searchable text that is already in the shards. The index stores `shardName`/`shardItemIndex` for loading shards on demand, but nothing uses them. The index also stores per-shard `sha256` (line 296), which is never checked. All of this happens the first time anything touches `localCatalog`. That is the view model's stored property initialiser (`@Published var curriculumCatalog = CurriculumCatalogService.localCatalog`), so it runs on the main actor while `ContentView` builds the view model at launch. Decoding about 75 MB of JSON with `JSONDecoder` takes seconds on an iPhone, and the app is unresponsive meanwhile. This risks the launch watchdog on older devices and holds two copies of the catalogue in memory permanently. Every item also repeats a ~500-character `sourceAttribution` string and the licence text, roughly 12 MB of duplication. The app ships about 75 MB of bundled JSON to every teacher.
- Evidence:
  - `GradeDraftViewModel.swift:27` `@Published var curriculumCatalog: CurriculumCatalog = CurriculumCatalogService.localCatalog`
  - `CurriculumCatalogService.swift:37` `let shards = try index.shards.flatMap { shard in let decoded = try loadBundledShard(...)`
  - `CurriculumCatalogService.swift:241` builds the search rows from the full decoded index. `shardName`/`shardItemIndex` (lines 301-302) are decoded and never read.
- Recommended fix: Make the generator emit one read-only SQLite file, `curriculum_acara_v9.sqlite`, with an `items` table and an FTS5 virtual table over code, title, description, strand and tags. Open it with GRDB, which the app already depends on, via `DatabaseQueue(path:configuration:)` with `configuration.readonly = true` from the bundle. Load items by ID or search with `MATCH` and ranking. Store the attribution and licence text once in a `sources` table. This deletes the shell/index/shard JSON, `BundledCurriculumIndex`, `BundledCurriculumShard`, `CurriculumCatalogSearchIndex`, the shard-count checks and the in-memory catalogue property. Search becomes ranked and word-based instead of a substring scan over about 12 MB of text on every keystroke. GRDB FTS5 docs: https://github.com/groue/GRDB.swift/blob/master/Documentation/FullTextSearch.md. If SQLite is rejected, the minimum fix is to make the catalogue lazy and off the main actor and to load a shard only when an item from it is needed.
- Effort: M. Risk: the teacher-imported catalogue path also uses `CurriculumCatalog` in memory and needs a separate small store or table. The Python script and its tests must be rewritten.
- Confidence: High for the load path and file sizes, which were measured. The decode time is an estimate (Medium) because it was not profiled on a device.

### C-02 — High — Lines from digital PDFs get invented highlight boxes that are drawn upside-down or off the page and exported as "evidence"
- Area / files: `GradeDraft/Services/OCRService.swift:101-124`; `GradeDraft/UI/DesignSystem/OCRComponents.swift:101-111, 122`; `GradeDraft/GradeDraftViewModel+StudentWorkImport.swift:287-292`; `GradeDraft/GradeDraftViewModel+OCRReviewEvidence.swift:167`; `GradeDraft/Services/LocalJSONStore.swift:464-466`
- What it is now and why it was probably done this way: When a PDF page has a text layer, `PDFImportPlanner.digitalDocument` splits `page.string` on newlines and gives line *n* a made-up rectangle, `x 0.02, y n×0.035, w 0.96, h 0.03`. The data model requires a bounding box (`OCRLine.boundingBox` is not optional), so the code filled one in.
- Why it is a problem: The overlay treats `y` as Vision's bottom-left origin (`topLeftY = 1 - y - height`). Line 1 of a digital PDF is therefore drawn at the **bottom** of the page image, the order is reversed, and from line 29 onward (`y > 1`) the box is drawn above the image. Teachers see confident-looking highlights on the wrong text. Those fake coordinates are then stored in evidence references and printed in the Teacher Record ("bbox: x:0.0200 y:0.9800 …"). D005 says the boxes give "traceability", but here they are fabricated, which breaks the repo's own "no fake behaviour" rule.
- Evidence:
  - `OCRService.swift:111` `boundingBox: NormalizedRect(x: 0.02, y: CGFloat(lineIndex) * 0.035, width: 0.96, height: 0.03)`
  - `OCRComponents.swift:104` `let topLeftY = 1 - normalizedRect.y - normalizedRect.height`
- Recommended fix: Use PDFKit's real line geometry. For each page, call `page.selection(for: page.bounds(for: .mediaBox))?.selectionsByLine()`. For each line selection, take `.string` and `.bounds(for: page)`, then divide by the media box to get a normalised bottom-left rectangle, which is the same convention Vision uses. Both APIs are in PDFKit (`PDFSelection.selectionsByLine()`, `PDFSelection.bounds(for:)`) on iOS 11 and later. This replaces the newline split and the invented rectangle. Where no geometry exists (pasted text), make `boundingBox` optional and show no highlight rather than a fake one.
- Effort: S–M. Risk: GRDB columns `bbox_*` are already nullable for evidence but not for OCR lines, so it needs a small migration.
- Confidence: High.

### C-03 — High — Any text layer makes a PDF page "digital", given confidence 1.0, so scanner-made text skips the low-confidence gate
- Area / files: `GradeDraft/Services/OCRService.swift:95-99, 110, 126-152`; `GradeDraft/Models/GradeDraftOCRModels.swift:179-200` (`markingAllLinesConfirmed`); `GradeDraft/GradeDraftViewModel+StudentWorkImport.swift:65-70, 97, 113`
- What it is now and why it was probably done this way: A page with *any* non-whitespace text is treated as digital and is not OCR'd (`pageIndexesNeedingOCR` only picks pages whose text is empty). Every digital line is given `confidence: 1.0`. The idea (D004) is that embedded text is exact, so OCR is only a fallback.
- Why it is a problem: Most school copiers and scanning apps produce "searchable PDFs", which are scanned images carrying the scanner's own OCR text layer, often poor on handwriting. Those pages are classed as digital, so the app's Vision OCR never runs. The scanner's guesses are stored as 100%-confidence lines, and the "confirm all" action (`markingAllLinesConfirmed`, which confirms every line at or above 0.70) confirms them in one tap. This bypasses AGENTS.md's Definition-of-Done rule that "Low-confidence OCR lines require explicit teacher line-level action". A page with only a printed header ("Name: ____ Page 1") and a handwritten body is also classed as digital, so the handwriting is silently dropped. Password-protected PDFs are not detected either: `PDFDocument(url:)` succeeds, `isLocked` is never checked, and the import "succeeds" with empty or blank pages.
- Evidence:
  - `OCRService.swift:97` `.filter { $0.element.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }`
  - `OCRService.swift:110` `confidence: 1.0,`
  - `StudentWorkImport.swift:65` `guard let document = PDFDocument(url: url) else {`, with no `isLocked` check.
- Recommended fix: (1) Classify a page as digital only if its text layer covers the page meaningfully, for example a minimum character count and selection bounds covering most of the text area. Otherwise run Vision on it, and when both exist keep Vision's lines and confidence. (2) Do not invent a confidence for text-layer lines. Store a distinct origin ("PDF text layer"), and either require per-line confirmation or exclude those lines from bulk confirm. (3) Check `document.isLocked` and fail openly with "This PDF is password-protected".
- Effort: M. Risk: changes the per-page heuristic, so fixtures need mixed PDFs.
- Confidence: High for the code path. The share of school PDFs that carry scanner text layers is industry knowledge, not measured here.

### C-04 — High — A failed "Replace local" restore deletes the teacher's original files, then says everything was rolled back
- Area / files: `GradeDraft/Export/BundleExportService.swift:426-452`; `GradeDraft/GradeDraftViewModel+BackupRestore.swift:141-149, 213, 220-225`; `GradeDraft/GradeDraftViewModel+StudentWorkImport.swift:294-300`
- What it is now and why it was probably done this way: Restore extracts source files first, then commits the database snapshot (D013). If anything fails, it deletes the files it just extracted and reloads the store. That rollback is correct for new paths.
- Why it is a problem: With `replaceLocal`, conflicting assignments keep the same assignment ID and therefore the same `Sources/<id>/page-…png` paths. The extractor **deletes the existing local file** (`removeItem` at line 441) before extracting the backup copy, and keeps no copy of it. If extraction of a later entry fails, the catch block (448-450) removes the restored files. If `store.replaceLocalDataSnapshot` fails, `cleanupRestoredSourceFiles` removes them too. Either way the teacher's original scans at those paths are gone. The local assignment records are "rolled back" and now point to missing files, and the app tells the teacher: "Restore failed. Local data and original files were rolled back to their previous state." That message is false, which breaks the repo's fail-openly rule, and student originals are lost.
- Evidence:
  - `BundleExportService.swift:441` `if fileManager.fileExists(atPath: item.destination.path) { try fileManager.removeItem(at: item.destination) }`
  - `GradeDraftViewModel+BackupRestore.swift:224` `statusMessage = "Restore failed. Local data and original files were rolled back to their previous state."`
- Recommended fix: Extract every entry into a staging folder inside Application Support first. After the database commit succeeds, swap each staged file into place with `FileManager.replaceItemAt(_:withItemAt:backupItemName:options:)`, which is atomic per file and can keep a backup copy. On any failure, delete only the staging folder; originals are never touched before the commit. This also removes the need for `cleanupRestoredSourceFiles`.
- Effort: S–M. Risk: low; needs a test that injects a failure after a replace.
- Confidence: High.

### C-05 — High — PDF reports use the phone's light/dark text colours, so exporting in Dark Mode can give white text on a white page
- Area / files: `GradeDraft/Export/PDFExportService.swift:120, 135, 153, 155, 164, 224, 238-248`
- What it is now and why it was probably done this way: The text attributes use `UIColor.label`, `.secondaryLabel` and `.tertiaryLabel`, the usual choices for on-screen text. The fallback renderer uses `UIFont.preferredFont(forTextStyle:)` (Dynamic Type).
- Why it is a problem: These are *dynamic* colours. They are resolved against the current trait collection when drawn, so a teacher whose phone is in Dark Mode can get near-white text in the PDF. This is a well-known `UIGraphicsPDFRenderer`/Core Text pitfall. The Dynamic Type fonts in the fallback mean the PDF's font size changes with the teacher's accessibility text-size setting, which contradicts the architecture's "deterministic local PDF rendering".
- Evidence:
  - `PDFExportService.swift:120` `appendInlineRuns(content, baseFont: font, color: .label, ...)`
  - `PDFExportService.swift:239` `.font: UIFont.preferredFont(forTextStyle: .title2), .foregroundColor: UIColor.label`
- Recommended fix: Use fixed print colours (`UIColor.black`, or `UIColor.label.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))`) and fixed point sizes. Better, wrap rendering in `UITraitCollection(userInterfaceStyle: .light).performAsCurrent { … }`. Add a snapshot test that renders in dark style. This becomes part of C-06 if the renderer is replaced.
- Effort: S.
- Confidence: Medium. Dynamic colour resolution in a PDF context is documented UIKit behaviour, but it was not reproduced on a device here.

### C-06 — Medium — Two PDF renderers, both re-parsing the Markdown by hand; TPPDF is stale; a silent fallback hides failures; Letter paper for an Australian app
- Area / files: `GradeDraft/Export/PDFExportService.swift:1-308` (all); `GradeDraft/Content/RegionalSettingsCatalog.swift:16-28` (Australia/en_AU)
- What it is now and why it was probably done this way: The report is first built as a Markdown string (C-07). The PDF service then re-parses that string *line by line by hand* (`#` headings, `>` quotes, `- ` bullets, `**` bold) into TPPDF blocks. If TPPDF throws, a second hand-written `UIGraphicsPDFRenderer` path strips the Markdown and prints plain lines. The comment says this is so that "a report is always produced".
- Why it is a problem:
  1. It is a third, private Markdown dialect (besides swift-markdown, which the app already ships, and the report builder's own conventions). Nested lists, numbered lists, tables, links and escaped characters are not handled.
  2. TPPDF's last stable release is 2.6.1 (Nov 2024), with only 3.0.0 alphas since, which makes it a stale dependency for one screen of output.
  3. The fallback swallows the error (`catch { try renderPlainPDF(...) }`). The teacher gets a visibly worse PDF with no message, which breaks the fail-openly rule.
  4. Both renderers hard-code US Letter (`.usLetter`, 612×792). The app targets Australian teachers (en_AU, ACARA), who print on A4, so every page is rescaled or clipped.
  5. The report layout is hand-coded: fixed point sizes, spacing and margins.
- Evidence:
  - `PDFExportService.swift:64` `let document = PDFDocument(format: .usLetter)`
  - `PDFExportService.swift:51-55` `} catch { // Robustness: never fail ... try renderPlainPDF(...)`
  - `PDFExportService.swift:193` `let segments = text.components(separatedBy: "**")`
- Recommended fix: Use one Apple-native renderer and drop TPPDF.
  - Build an `NSAttributedString` from a structured report model (see C-07), or from the swift-markdown AST.
  - Hand it to `UISimpleTextPrintFormatter(attributedText:)` inside a `UIPrintPageRenderer` subclass, whose `drawHeaderForPage`/`drawFooterForPage` draw the title and "Page n of m". Set `paperRect`/`printableRect` to A4 (595×842 pt), or derive the paper size from the locale.
  - Write the pages with `UIGraphicsPDFRenderer`. Pagination, line breaking and widows are handled by UIKit's print system (iOS 4.2+, fully local).
  - Alternatives considered: SwiftUI `ImageRenderer` renders one fixed-size page per call, so flowing multi-page reports need manual splitting, which is worse. `WKWebView.createPDF` produces one tall unpaginated page and pulls WebKit (a web content process) into a no-network app, which is also worse.
  - This deletes `renderStyledPDFData`, `styledBlock`, `headingLevel`, `bulletContent`, `appendInlineRuns`, `renderPlainPDF` and `markdownStripped` (about 250 lines) and the TPPDF package.
- Effort: M. Risk: PDF snapshot baselines change.
- Confidence: High.

### C-07 — Medium — Reports are concatenated Markdown strings with no escaping, so student or teacher text can turn into headings and bullets; dates print as raw UTC
- Area / files: `GradeDraft/Services/LocalJSONStore.swift:282-591` (`MarkdownReportBuilder`, which sits in the "JSON store" file); specifically 291, 305, 363, 368, 378, 389, 440, 477, 488-503
- What it is now and why it was probably done this way: `MarkdownReportBuilder` appends string fragments (`"## …\n"`, `"- Score: …"`) and interpolates teacher and student text directly. It was the quickest way to get one artefact usable as both the Markdown export and the PDF input.
- Why it is a problem:
  1. **No escaping.** Reviewed student text or feedback that starts a line with `#`, `-`, `>`, `1.` or contains `**` becomes a heading, bullet, quote or bold in the Markdown export, and in the PDF through C-06's line parser. For example, a student line "# of apples = 12" becomes a heading, and "- 3 = 5" becomes a bullet. The student's words are shown with structure they never wrote.
  2. **Dates** are interpolated as `"\(generatedAt)"`, `"\(record.createdAt)"` and `"\(event.timestamp)"`, which print `2026-11-15 03:12:00 +0000` (UTC, developer format) in a teacher-facing record. A new `DateFormatter` is also built per header (488-491).
  3. The builder lives inside `LocalJSONStore.swift`, which hides it from anyone looking in `Export/`.
- Evidence:
  - `LocalJSONStore.swift:368` `output.append(assignment.reviewedStudentText.isEmpty ? ... : "\(assignment.reviewedStudentText)\n")`
  - `LocalJSONStore.swift:305` `output.append("\n**Report generated:** \(generatedAt)\n")`
  - `LocalJSONStore.swift:477` `output.append("- \(event.timestamp): ...`
- Recommended fix: Introduce a small structured `ReportDocument` (sections → headings, key/value rows, paragraphs, lists, quoted student text) built once from `AssignmentRecord`. Render it to (a) Markdown, putting user text through CommonMark backslash-escaping of leading block markers and inline `*`/`_`/`` ` ``, or putting reviewed student text in an indented or fenced block; (b) `NSAttributedString` for the PDF (C-06); (c) the in-app export preview. Format dates with `Date.FormatStyle` (`.formatted(date: .abbreviated, time: .shortened)` in the device locale). Move the builder to `Export/`.
- Effort: M (pairs with C-06).
- Confidence: High.

### C-08 — Medium — `ReportTemplateCatalog` is dead "source of truth" content that the real reports do not use
- Area / files: `GradeDraft/Content/ReportTemplateCatalog.swift:1-170`; only used by `GradeDraftTests/GradeDraftContentCatalogTests.swift:343-357`
- What it is now and why it was probably done this way: It holds mustache-style templates (`{{assignmentTitle}}`, `{{#criteria}}…{{/criteria}}`) for student and teacher reports, including a "Formative feedback" report, copied from a content specification document.
- Why it is a problem: No production code renders these templates. The real reports come from `MarkdownReportBuilder`, which uses different headings ("### Student feedback" vs the template's "### Feedback") and has no formative report at all. Tests lint the template copy, so the content looks verified, but teachers never see it. It is a second source of truth that has drifted, which is theatre.
- Evidence: `grep ReportTemplateCatalog` finds only its own file and one test file.
- Recommended fix: Delete `ReportTemplateCatalog` and its tests, and make the C-07 `ReportDocument` builder the single source. If the owner wants the formative report, that is a feature to build, not a template to keep.
- Effort: S.
- Confidence: High.

### C-09 — Medium — The Markdown rubric parser is half AST and half line-by-line text matching, and the two halves disagree
- Area / files: `GradeDraft/Rubrics/MarkdownRubricParser.swift:138-144, 237-336, 338-353, 393-399`
- What it is now and why it was probably done this way: The header comment says it is "driven by the swift-markdown AST", and `collectRows` does walk the `Document`. But `candidateRows` *also* runs two raw-text passes over the same input (`pipeTableRows`, `explicitListRows`, with their own `#`/`|`/`- `/`\d+.` detection) and then de-duplicates the combined rows by a string key. This was probably a patch for cases the AST walk missed, such as the group heading on list rows.
- Why it is a problem: The raw passes ignore Markdown context. A table or list inside a fenced code block or HTML comment is still picked up as criteria. A line the AST treats as part of a paragraph is treated as a list item. The de-dup key mixes `explicitID` computed from the raw text (with `**`) and from plain text, so one criterion can produce two rows. The second is then dropped with a misleading "Duplicate criterion ignored" warning shown to the teacher, and the group title from the raw pass is lost when the AST row wins. `markdownPlain` re-implements emphasis stripping by deleting `**`/`__`/`` ` `` characters, which also mangles legitimate content such as `__init__`. The swift-markdown requirement floor is 0.2.0 (latest 0.9.0), and the comment at 180-182 works around an API gap of that old version.
- Evidence:
  - `MarkdownRubricParser.swift:141-143` `rows.append(contentsOf: pipeTableRows(fromRawMarkdown: text)); rows.append(contentsOf: explicitListRows(fromRawMarkdown: text)); return deduplicatedRows(rows)`
- Recommended fix: Make it AST-only. Track the current heading while walking (as `collectRows` already can), read list items from `ListItem` children, and read tables from `Markdown.Table.head/body` (already done in `collectTableRows`). Use `PlainTextConvertibleMarkup.plainText` (swift-markdown 0.9.0, https://github.com/swiftlang/swift-markdown) instead of `markdownPlain`. Delete `pipeTableRows`, `explicitListRows`, `rawHeadingTitle`, `rawListItem`, `isPipeTableLine`, `splitPipeRow`, `isPipeDelimiterRow`, `deduplicatedRows` and `markdownPlain` (about 130 lines). Raise the swift-markdown floor to 0.9.0.
- Effort: S–M. Risk: rubric fixtures may rely on the raw passes. Run the rubric tests and add a fenced-code fixture.
- Confidence: High.

### C-10 — High — Importing a roster CSV whose header row has two blank or duplicate column names crashes the app
- Area / files: `GradeDraft/Services/RosterImportService.swift:37-39`
- What it is now and why it was probably done this way: Header names are lower-cased, spaces removed, and put in a dictionary with `Dictionary(uniqueKeysWithValues:)`.
- Why it is a problem: `uniqueKeysWithValues` **traps (crashes the app)** on duplicate keys. Spreadsheets exported from Excel or Google Sheets often carry trailing empty columns (`displayName,localIdentifier,,`) or a repeated header ("Notes", "notes"). Both produce duplicate keys, so the app crashes when the teacher previews the roster, before any review step. This is a crash triggered by ordinary teacher input.
- Evidence: `RosterImportService.swift:39` `let headerIndex: [String: Int] = Dictionary(uniqueKeysWithValues: lowerHeaders.enumerated().map { ... })`
- Recommended fix: Use `Dictionary(_:uniquingKeysWith: { first, _ in first })`, skip empty header cells, and report duplicate headers as a warning row. Add a test with `"displayName,localIdentifier,,\nAda,1,,"`.
- Effort: S.
- Confidence: High.

### C-11 — Medium — Roster import only understands exact header names and UTF-8 text, so ordinary school exports silently go wrong
- Area / files: `GradeDraft/UI/Screens/ClassDetailRosterScreen.swift:313-324`; `GradeDraft/Services/RosterImportService.swift:38, 42-44, 54-57`; `GradeDraft/GradeDraftViewModel+StudentWorkImport.swift:274-285` (`readTextFile`)
- What it is now and why it was probably done this way: A header row is recognised only if it contains `displayName`, `localIdentifier` or `className` (spaces optional). Otherwise row 1 is imported as a student. Files are read with `String(contentsOf:encoding: .utf8)`.
- Why it is a problem:
  1. Excel's "CSV UTF-8" adds a byte-order mark. The first header then reads `\u{FEFF}displayname`, header detection fails, and the header row becomes a student called "displayName". Only a warning line indicates this.
  2. Excel's default "CSV (Comma delimited)" on Windows is Windows-1252. Any name with an accent (Zoë, José) makes the UTF-8 read throw, and the import fails.
  3. School system exports (Compass, Sentral and similar) use headers like "First Name", "Surname", "Student Code". These are not recognised, so "First Name" is imported as a student and columns are mapped by position.
  4. `readTextFile` hand-rolls a UTF-8-then-UTF-16 guess.
- Evidence:
  - `ClassDetailRosterScreen.swift:319` `rosterCSV = try String(contentsOf: url, encoding: .utf8)`
  - `RosterImportService.swift:38` `let hasHeader = lowerHeaders.contains("displayname") || ...`
- Recommended fix: Read with `String(contentsOf:usedEncoding:)` (Foundation detects the BOM and the encoding), fall back to `.windowsCP1252`, and strip a leading `\u{FEFF}`. Accept common synonyms (first/given name + surname/family name → display name; student code/ID → local identifier). Better, add a column-mapping step in the import preview so the teacher picks which column is the name, since the preview UI already exists.
- Effort: S (encoding) / M (column mapping).
- Confidence: High for encoding and header logic. Medium for the exact header names that Australian school systems use.

### C-12 — Medium — Keep the hand-written CSV code, but it has gaps: an incomplete formula guard, no Excel BOM, "7.0"-style scores, AI draft scores in the gradebook total, dead and duplicated code
- Area / files: `GradeDraft/Export/CSVCodec.swift:1-108`; `GradeDraft/Export/CSVExportService.swift:4-21, 62, 73-83, 119-130`; `GradeDraft/GradeDraftViewModel+Export.swift:65-79, 96-112`; `GradeDraft/Export/ExportPolicy.swift:342-349`
- What it is now and why it was probably done this way: SwiftCSV was removed and replaced by about 100 lines of writer and parser plus `SpreadsheetSafety`, which prefixes `'` to cells starting with `= + - @`.
- Is hand-writing justified? Yes, mostly. The package candidates are weak:
  - **CodableCSV** (dehesa/CodableCSV): last release 0.6.7, "Xcode 13 support", i.e. 2021, with open PRs unmerged. Effectively unmaintained. https://github.com/dehesa/CodableCSV/releases
  - Apple's **TabularData** (`DataFrame(contentsOfCSVFile:)`, iOS 15+) is maintained and local, but it infers column types (a student code "00123" becomes 123) unless every column's type is declared up front, which is awkward for teacher-supplied rosters with unknown headers.
  - Formula neutralisation is app policy that no CSV library provides anyway.
  - **Verdict:** keep the small codec, but fix the following.
- Why it is a problem (the fixes):
  1. OWASP's CSV-injection guidance also lists tab (`\t`) and carriage return (`\r`) as leading characters to neutralise. They are missing from `dangerousFormulaPrefixes`.
  2. No UTF-8 BOM is written, so Excel on Windows (common in schools) opens the file as ANSI and garbles accented student names. Rows end with `\n`, not RFC 4180's CRLF.
  3. Scores are written with `String(totalScore)`, which gives `7.0` and `12.5`. The app already has `GradeTotals.formatted`.
  4. `exportTotals` writes the **AI draft score** (or an in-progress final score) into `total_score` when no approved final review exists. There is a `final_status` column and a draft warning (`gradebookExportContainsDraftState`), but a gradebook import keyed on `total_score` will take unreviewed suggestions as grades. That cuts against "not an autonomous grader".
  5. `CSVExportService.writeCSV` is dead code (no callers). `exportCSVGradebook` and `exportClassGradebookCSV` are near-identical copies. The parser's `case "\r"` branch is unreachable because CR is normalised first (and that normalisation also rewrites CRs inside quoted fields).
- Evidence:
  - `CSVExportService.swift:4` `private static let dangerousFormulaPrefixes: Set<Character> = ["=", "+", "-", "@"]`
  - `CSVExportService.swift:62` `String(totalScore),`
  - `CSVExportService.swift:124-126` `if let draft = assignment.latestDraft { return (draft.totalScore, draft.maxScore) }`
- Recommended fix: Add `\t` and `\r` to the prefixes; write `"\u{FEFF}"` plus CRLF rows; format scores with `GradeTotals.formatted`; leave `total_score` empty unless the final review is approved and current, putting draft totals, if wanted at all, in a separate clearly named `draft_suggestion_total` column; delete `writeCSV` and merge the two export functions; drop the dead `\r` branch.
- Effort: S.
- Confidence: High.

### C-13 — Medium — Backups store each record up to three times, uncompressed, via a temporary file per entry, and restore re-reads the archive three or four times
- Area / files: `GradeDraft/Export/BundleExportService.swift:92, 137, 180, 193-205, 216-234, 240-257, 287-298, 565, 584-590`; `GradeDraft/GradeDraftViewModel+BackupRestore.swift:140-146`
- What it is now and why it was probably done this way: The full backup writes `database_export.json` (everything), **and** `assignments.json`, **and** separate `source_inputs.json`, `evidence_refs.json`, `audit_events.json`, `export_records.json`, `curriculum_mappings.json` and `ocr_documents.json`. Every one of these is already inside each `AssignmentRecord`. The intent was presumably a "readable" archive and a fallback if one file is missing.
- Why it is a problem:
  1. Restore reads only `database_export.json`, falling back to `assignments.json`. The other files are never read, and they double or triple the backup size and the data exposed if a backup leaks.
  2. ZIPFoundation's `addEntry` defaults to `compressionMethod: .none`, so the pretty-printed JSON and PNG/PDF sources are stored **uncompressed**. No call passes `.deflate`.
  3. Every JSON blob is written to a temp file and re-added (`addDataWithoutInventory`). Sensitive JSON briefly sits in `tmp/` unprotected, when ZIPFoundation can add from memory.
  4. A confirmed restore runs `previewRestore` (full decode), then `prepareBackupRestore`, which calls `previewRestore` again (another full decode) and `readBackupDatabaseExport` again. That is four full decodes of a file that can hold 50 MB of JSON, on the main actor.
  5. All three writers use the failable `Archive(url:accessMode:)`, which throws away the real error. ZIPFoundation 0.9.17 added throwing initialisers. The package floor is 0.9.0, while 0.9.18 fixed a path-escape vulnerability, and there is no committed `Package.resolved`.
- Evidence:
  - `BundleExportService.swift:195-196` adds both `database_export.json` and `assignments.json`
  - `BundleExportService.swift:565` `try archive.addEntry(with: safeName, fileURL: fileURL)` (no compression argument)
  - `BundleExportService.swift:293` `_ = try previewRestore(from: url, ...)` then 298 `let databaseExport = try readBackupDatabaseExport(from: url)`
- Recommended fix: Write one `database_export.json` plus `manifest.json`, `archive_inventory.json` and `sources/`. Pass `compressionMethod: .deflate`. Use `addEntry(with:type:uncompressedSize:compressionMethod:provider:)` for in-memory data. Use `try Archive(url:accessMode:)`. Decode once and pass the result from preview to confirm, guarded by the staged-file check. Raise the ZIPFoundation floor to 0.9.20 and commit `Package.resolved`. ZIPFoundation: https://github.com/weichsel/ZIPFoundation/releases. Keep ZIP rather than Apple Archive for the *teacher archive*, because teachers must open it on a school Windows PC; Apple Archive (`.aar`) cannot be opened there without extra tools. For the *full backup*, which only MarkForMe reads back, Apple Archive with Apple Encrypted Archive (`AppleArchive` framework, iOS 15+) would add encryption at rest for a file that leaves the device. See Questions.
- Effort: S–M. Risk: restore must keep reading existing backups only if the owner wants compatibility (pre-production; see C-20).
- Confidence: High for the code. Medium that the failable initialiser is formally marked deprecated; the throwing initialiser's existence since 0.9.17 is confirmed.

### C-14 — Medium — Heavy file work runs on the main actor: every PDF page rendered at 2× and held in memory, PNG for photos, restore extraction, catalogue decode
- Area / files: `GradeDraft/GradeDraftViewModel+StudentWorkImport.swift:6 (@MainActor), 81-82, 97-111, 218-266`; `GradeDraft/GradeDraftViewModel+BackupRestore.swift:6, 134-226`; `GradeDraft/GradeDraftViewModel+Export.swift` (all exports synchronous on main)
- What it is now and why it was probably done this way: The import, export and restore pipelines are extensions on the `@MainActor` view model for simplicity. Only the Vision call is `async`.
- Why it is a problem:
  1. `renderPDFPages` renders **every** page at 2× into `UIImage`s and keeps them all before writing (an A4 page at 2× is about 8 MB decoded, so a 30-page PDF is about 240 MB), including pages that already have digital text. This invites memory termination on iPhone.
  2. Each page and each camera scan is then re-encoded as **PNG** (`image.pngData()`), typically 5–20 MB per 12-megapixel photo, for photographic content.
  3. PDF rendering, PNG encoding, file copies, ZIP creation and extraction, and SHA/FNV hashing all run synchronously on the main thread, so the UI freezes, the "working" spinner cannot animate, and cancellation is impossible.
  4. `imageWidth`/`imageHeight` are recorded from `UIImage.size` (points, not pixels).
- Evidence:
  - `StudentWorkImport.swift:98` `let images = try renderPDFPages(document)`, holding all pages
  - `StudentWorkImport.swift:226` `guard let data = image.pngData() else {`
  - `StudentWorkImport.swift:6` `@MainActor extension GradeDraftViewModel {`
- Recommended fix: Move the pipelines into a non-main `actor` (for example `SourceImportService`) and have the view model only publish progress. Process one page at a time: render → write → OCR if needed → release. Use `PDFPage.thumbnail(of:for:)` or a `CGContext` render per page, and encode with ImageIO (`CGImageDestinationCreateWithURL` with `UTType.heic` or `.jpeg` at about 0.8 quality), which is about 5–10× smaller than PNG. Record pixel dimensions from the `CGImage`. Run ZIP and restore work in the same background service and support `Task` cancellation.
- Effort: M. Risk: actor isolation changes; tests that call these synchronously need `await`.
- Confidence: High for main-actor placement and memory arithmetic. Not profiled on a device.

### C-15 — Medium — OCR uses the older `VNRecognizeTextRequest`; newer Swift Vision requests (iOS 18) and document-structure recognition (iOS 26) are unused
- Area / files: `GradeDraft/Services/OCRService.swift:29-91`; `GradeDraft/Views/DocumentScannerView.swift:1-60`
- What it is now and why it was probably done this way: `VNRecognizeTextRequest` (accurate mode, language correction) is wrapped in `withCheckedThrowingContinuation` with a synchronous `handler.perform`. Lines are ordered by a custom comparator. This is the classic pre-2024 pattern and supports the iOS 17 deployment target.
- Why it is a problem:
  1. Apple's Swift-native `RecognizeTextRequest` (iOS 18+) is `async` and `Sendable` natively, which would remove the continuation and the `perform` that blocks a thread.
  2. `RecognizeDocumentsRequest` (iOS 26+, WWDC25 session 272) returns a `DocumentObservation` with **paragraphs, lists and tables**, with bounding regions and reading order. That fits student essays (correct paragraph order instead of a hand-made row sort) and worksheets/tables, and the app already requires iOS 26 for its AI path. https://developer.apple.com/documentation/vision/recognizedocumentsrequest
  3. The custom `sortedReadingOrder` comparator uses a tolerance ("same row if y within max height"), which is not a strict weak ordering. Swift's `sort` can then return inconsistent orders for slanted handwriting, mixing words between lines.
  4. No `recognitionLanguages` or `automaticallyDetectsLanguage` setting is used, so EAL/D students' non-English work gets English language correction applied.
- Evidence:
  - `OCRService.swift:35` `let request = VNRecognizeTextRequest { request, error in`
  - `OCRService.swift:84-90` tolerance-based comparator
- Recommended fix: Behind `if #available(iOS 26, *)`, use `RecognizeDocumentsRequest` and map paragraphs → lines (keeping per-line bounding regions and confidence) in the document's own reading order. Keep `VNRecognizeTextRequest` only for iOS 17–25, or drop it entirely if the owner raises the minimum to iOS 26 (see Questions). Replace the comparator with Vision's ordering. Set `automaticallyDetectsLanguage = true`, or let the teacher pick a language. Keep `VNDocumentCameraViewController` for capture: it is still the right tool for page scanning (VisionKit's `DataScannerViewController` is for live text, not page capture). The Coordinator could be `@MainActor` instead of `@unchecked Sendable` (`DocumentScannerView.swift:24`).
- Effort: M. Risk: confidence semantics may differ between requests, so the 0.70 threshold (`GradeDraftOCRModels.swift` `lowConfidenceThreshold`) needs re-calibration on real handwriting.
- Confidence: High for API existence (Apple docs and WWDC25). Medium for the quality gain on handwriting, which was not tested.

### C-16 — Medium — "File protection hardening" sets the default protection class (so does nothing), and sensitive exports pile up in `tmp/` and `Documents/` forever
- Area / files: `GradeDraft/Security/LocalDataProtection.swift:68-75`; `GradeDraft/Export/ExportFileHardening.swift:32-36`; `GradeDraft/GradeDraftViewModel+Export.swift:247-250`; `GradeDraft/Export/BundleExportService.swift:76-82, 107-110`; `GradeDraft/GradeDraftViewModel+RoutingStatus.swift:109-113`; no `.entitlements` file in the repo
- What it is now and why it was probably done this way: Every export and source file gets `FileProtectionType.completeUntilFirstUserAuthentication` and `isExcludedFromBackup`. Exports go to `tmp/`, except the teacher archive ZIP, which goes to `Documents/MarkForMeExports/`.
- Why it is a problem:
  1. `completeUntilFirstUserAuthentication` is already iOS's default class for app files, and there is no Data Protection entitlement raising it. The "hardening" therefore changes nothing; only the backup exclusion has an effect, and setting it on files in `tmp/`, which is never backed up, is a no-op too.
  2. `clearPreparedExport()` only clears the published URL. It never deletes the file. Teacher Records with private notes, full backups and gradebooks stay in `tmp/` until iOS purges it, and teacher archives in `Documents/MarkForMeExports/` are never deleted.
  3. Exports go to two different places for no reason.
- Evidence:
  - `LocalDataProtection.swift:71` `[.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]`
  - `RoutingStatus.swift:109-113` `func clearPreparedExport() { exportURL = nil; exportKind = nil; preparedExportArtifact = nil }`
- Recommended fix: Use `.complete` for exports and source images, which are never needed while the device is locked since there is no background work. Leave the GRDB database at its current class, because SQLite WAL needs care under `.complete`. Write all exports to one `tmp/Exports/` folder, delete the prepared file after the share sheet finishes or when a new export is prepared, and empty the folder at launch. Move the teacher archive there too. Optionally add the Data Protection entitlement (`com.apple.developer.default-data-protection = NSFileProtectionComplete`).
- Effort: S.
- Confidence: High.

### C-17 — Low — Re-importing student work leaves the old page images on disk and keeps evidence pointing at deleted scanned-text lines; the original PDF folder is not protected
- Area / files: `GradeDraft/GradeDraftViewModel+StudentWorkImport.swift:34-44, 76-81, 138-148`
- What it is now: A new scan, photo or PDF replaces `assignment.sourceInputs` and `ocrDocument`, but the previous `Sources/<id>/page-*.png` files are only removed by "Clear student work" or deleting the assignment. `evidenceReferences` are not reset, so they keep pointing at OCR line IDs that no longer exist. The staleness fingerprint may flag this, but the references stay. The `original/` folder is created with plain `createDirectory` before the parent is prepared, and the copied PDF is never passed to `protectSensitiveFile`.
- Why it is a problem: Unreferenced student images stay on the device and are excluded from backups and archives, so they are invisible to the teacher. Evidence can reference deleted lines.
- Evidence: `StudentWorkImport.swift:35` `assignment.sourceInputs = sourceRefs`, with no cleanup of previous sources. `:77` `try fileManager.createDirectory(at: originalFolder, withIntermediateDirectories: true)`.
- Recommended fix: After a successful save, delete the previous source files and clear or flag evidence for the old OCR document. Prepare `Sources/<id>/` with `LocalDataProtection.prepareSensitiveDirectory` before copying the PDF.
- Effort: S.
- Confidence: High for files. Medium for evidence impact, because staleness logic elsewhere was not traced end to end.

### C-18 — Low — The photo picker takes one photo, so multi-page handwritten work cannot be imported from Photos
- Area / files: `GradeDraft/UI/Screens/StudentWorkScreen.swift:68, 150, 256-266`
- What it is now: `PhotosPicker(selection: $selectedPhoto, matching: .images)` with a single `PhotosPickerItem?`. Each pick replaces all sources.
- Why it is a problem: A three-page essay photographed on the phone has to be re-scanned with the camera; picking photos one at a time only keeps the last page.
- Recommended fix: `PhotosPicker(selection: $items, maxSelectionCount: 20, selectionBehavior: .ordered, matching: .images)` and pass all images to `applyPhotoImages`. These are SwiftUI APIs from iOS 16/17.
- Effort: S.
- Confidence: High.

### C-19 — Low — File fingerprints use a non-cryptographic hash over whole-file reads, and the "backup changed after preview" check guards the app's own temp file
- Area / files: `GradeDraft/GradeDraftViewModel+StudentWorkImport.swift:82, 90-91, 238-239`; `GradeDraft/GradeDraftViewModel+BackupRestore.swift:60, 78-82, 228-231`; `GradeDraft/Export/BundleExportService.swift:361-375`
- What it is now: Source digests, manifest hashes and the restore staging check use `StableFingerprint` (FNV-1a 64-bit, `digestAlgorithm: "fnv1a64"`), reading whole files into `Data`. The manifest's `contentHashes` are never verified on restore.
- Why it is a problem: The Teacher Record presents these as integrity digests, but FNV-1a is not collision-resistant. Reading 100 MB files fully into memory to hash them is wasteful. The staged-backup check compares a file the app itself copied into its own sandbox, so it protects against nothing realistic, and the manifest hashes are written but never checked. Both are theatre.
- Recommended fix: Use CryptoKit `SHA256` with incremental `update(data:)` over a `FileHandle` for real digests. Verify manifest hashes on restore, or stop writing them. Drop the staged-file re-fingerprint, or keep the decoded preview instead (C-13).
- Effort: S.
- Confidence: High.

### C-20 — Low — A "legacy JSON" restore path and duplicated preview code survive in a pre-production app
- Area / files: `GradeDraft/GradeDraftViewModel+BackupRestore.swift:54-58, 117-132, 150-166`; `GradeDraft/GradeDraftViewModel+StudentWorkImport.swift:206-216`; `GradeDraft/Export/BundleExportService.swift:84-86 (writeBundle alias), 226-233 (assignments.json fallback)`; `ExportsRestoreScreen.swift:220` (importer accepts `.json, .zip, .item`)
- What it is now: Restore accepts a bare `[AssignmentRecord]` JSON (the "legacy" format) with its own preview builder, duplicated twice. `writeBundle` is an unused alias of `writeTeacherAuditArchive`, and `readBackupDatabaseExport` falls back to old-layout files.
- Why it is a problem: Extra restore paths mean extra untested attack surface, since this is untrusted teacher-supplied input, plus duplicated code. The app has not shipped, so no teacher has legacy backups.
- Recommended fix: If the owner confirms no compatibility is needed, delete the legacy JSON path, the `assignments.json` fallback and `writeBundle`, and restrict the importer to `.zip`.
- Effort: S.
- Confidence: High (owner decision needed).

---

## Keep (good as is)
- **Restore path safety** (`BundleExportService.swift:650-682`, `SourcePathSafety`, lines 714-733): rejects absolute paths, `..`, backslashes, symlinks and entries outside Application Support, enforces per-entry size caps (50 MB JSON, 100 MB source) and checks for duplicate critical entries. This is solid work; keep it when refactoring C-04 and C-13.
- **Student report vs Teacher Record separation** (D002): the student Markdown only includes approved, current final reviews (`LocalJSONStore.swift:287`). Keep the rule when C-07 restructures the builder.
- **ZIP for teacher archives**: correct for interoperability with school Windows PCs. ZIPFoundation is maintained (0.9.20, Sep 2025).
- **`VNDocumentCameraViewController`** for page capture, **`fileImporter`**, **`PhotosPicker`** and **`ShareLink(item: URL)`** with a warning-gated confirmation: all modern SwiftUI/VisionKit APIs. There is no need for `UIActivityViewController`.
- **Export filenames contain no student names** (`ExportFileHardening.swift:4-13`, POSIX UTC stamp + 8-character ID): privacy-safe. See the question below about usability.
- **Hand-written CSV codec** in principle: small, tested, and it quotes every cell. A package would not add value (C-12).
- **`PDFImportPlanner`** as pure, testable page-merge logic. Its heuristic needs fixing (C-03), but the separation is right.
- **The curriculum generator recording provenance and licence per source**: the attribution content is right; only its storage format is wrong (C-01).

## Out of area
- `StableFingerprint` (FNV-1a) is also used for the grading-packet fingerprint and export-record fingerprints across the app. Review it under the persistence/AI areas.
- `GradeDraftViewModel` is a single `ObservableObject` with about 25 `@Published` properties, including the 24,662-item catalogue (C-01). The migration to `@Observable` belongs to the UI/architecture area.
- Dependency floors (GRDB capped at 6.x, swift-markdown 0.2.0, TPPDF) and the missing `Package.resolved` are noted above only where they affect this area.

## Questions for the owner
1. **Minimum iOS version:** raise the deployment target from iOS 17 to iOS 26 (the AI path already requires 26)? This lets OCR use `RecognizeDocumentsRequest` alone and deletes the older Vision path (C-15).
2. **Full backup encryption:** should the full backup, which contains every student's work and private notes and is shared through Files/AirDrop, be password-encrypted with Apple Encrypted Archive (readable only by MarkForMe), while the teacher archive stays a plain ZIP for school PCs (C-13)?
3. **Gradebook CSV totals:** should `total_score` be blank until the teacher approves the final review, with any AI draft total in a separately named column or omitted (C-12)?
4. **Paper size:** A4 only (Australian schools), or follow the device region (C-06)?
5. **Export filenames:** keep anonymous names (`MarkForMe-StudentPDF-20261115-031200-1A2B3C4D.pdf`), or include the student's name for student-facing PDFs, which teachers hand out to many students, while keeping teacher-only files anonymous?
6. **Legacy backups:** confirm that no pre-existing JSON backups need restoring, so the legacy restore path can be deleted (C-20).
7. **Device-backup exclusion:** student scans are excluded from iCloud/iTunes device backup by design. If the device is lost, the only copy is a manual full backup. Is that the intended trade-off?

Sources (web checks): [Apple — RecognizeDocumentsRequest](https://developer.apple.com/documentation/vision/recognizedocumentsrequest), [WWDC25 session 272](https://developer.apple.com/videos/play/wwdc2025/272/), [Apple — recognize tables within a document](https://developer.apple.com/documentation/vision/recognize-tables-within-a-document), [CodableCSV releases](https://github.com/dehesa/CodableCSV/releases), [ZIPFoundation releases](https://github.com/weichsel/ZIPFoundation/releases), [GRDB full-text search](https://github.com/groue/GRDB.swift/blob/master/Documentation/FullTextSearch.md).

#!/usr/bin/env python3
"""Build and validate the bundled GradeDraft Australian Curriculum catalog.

The preferred maintenance path downloads official MRAC JSON-LD files and
normalizes them into app-bundled JSON. This Linux implementation also supports a
local official workbook fallback because the uploaded repo already contains the
Australian Curriculum workbook under docs/australiancurriculum and this execution
environment has no outbound DNS access from the working tree. The fallback is
recorded explicitly in the generated manifest and summary; it is not used by the
app at runtime.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import html
import json
import pathlib
import re
import sys
import urllib.error
import urllib.request
import zipfile
import xml.etree.ElementTree as ET
from dataclasses import dataclass
from typing import Any
from urllib.parse import quote

ROOT = pathlib.Path(__file__).resolve().parents[2]
CACHE_DIR = ROOT / ".build" / "curriculum-cache"
RESOURCE_DIR = ROOT / "GradeDraft" / "Resources" / "JSON"
CATALOG_PATH = RESOURCE_DIR / "curriculum_catalog_acara_v9.json"
MANIFEST_PATH = RESOURCE_DIR / "curriculum_catalog_acara_v9_manifest.json"
SUMMARY_PATH = RESOURCE_DIR / "curriculum_catalog_acara_v9_summary.json"
WORKBOOK_PATH = ROOT / "docs" / "australiancurriculum" / "curriculum-workbook.xlsx"
SCRIPT_NAME = "scripts/curriculum/build_acara_curriculum_catalog.py"
SOURCE_VERSION = "Australian Curriculum Version 9.0 / MRAC 2024-04"
FILES_UPDATED = "2024-06-07"
SCHEMA_VERSION = "1.0.0"
CATALOG_ID = "acara-australian-curriculum-v9-mrac-2024-04"
LICENSE_NAME = "CC BY 4.0, subject to Australian Curriculum website terms and excluded materials"
NON_ENDORSEMENT = (
    "Australian Curriculum references are provided as local reference aids only. "
    "Confirm requirements with your school, sector, and jurisdiction before reporting. "
    "MarkForMe does not claim ACARA endorsement, certification, compliance, or reporting approval."
)
ICIP_WARNING = (
    "Some Australian Curriculum material relates to Aboriginal and Torres Strait Islander Histories and Cultures "
    "and may involve Indigenous Cultural and Intellectual Property considerations. Use, adaptation, and publication "
    "must respect applicable cultural protocols and permissions."
)
ATTRIBUTION = (
    "© Australian Curriculum, Assessment and Reporting Authority (ACARA) 2010 to present, unless otherwise indicated. "
    "This material was downloaded from the Australian Curriculum website or machine-readable Australian Curriculum "
    "source files and was normalized for offline reference display in MarkForMe. ACARA does not endorse MarkForMe. "
    "ACARA has not authorized MarkForMe, and MarkForMe is not affiliated with or sponsored by ACARA."
)


@dataclass(frozen=True)
class SourceDefinition:
    key: str
    kind: str
    name: str
    path: str

    @property
    def source_version(self) -> str:
        return f"MRAC/2024/04/{self.path}"

    @property
    def jsonld_url(self) -> str:
        return f"https://vocabulary.curriculum.edu.au/MRAC/2024/04/{self.path}/export/MRAC/2024/04/{self.path}.jsonld"


SOURCES: list[SourceDefinition] = [
    SourceDefinition("LA_ART", "learningArea", "The Arts", "LA/ART"),
    SourceDefinition("LA_ENG", "learningArea", "English", "LA/ENG"),
    SourceDefinition("LA_HPE", "learningArea", "Health and Physical Education", "LA/HPE"),
    SourceDefinition("LA_HASS", "learningArea", "Humanities and Social Sciences", "LA/HASS"),
    SourceDefinition("LA_LAN", "learningArea", "Languages", "LA/LAN"),
    SourceDefinition("LA_MAT", "learningArea", "Mathematics", "LA/MAT"),
    SourceDefinition("LA_SCI", "learningArea", "Science", "LA/SCI"),
    SourceDefinition("LA_TEC", "learningArea", "Technologies", "LA/TEC"),
    SourceDefinition("GC_CCT", "generalCapability", "Critical and Creative Thinking", "GC/CCT"),
    SourceDefinition("GC_DL", "generalCapability", "Digital Literacy", "GC/DL"),
    SourceDefinition("GC_EU", "generalCapability", "Ethical Understanding", "GC/EU"),
    SourceDefinition("GC_IU", "generalCapability", "Intercultural Understanding", "GC/IU"),
    SourceDefinition("GC_L", "generalCapability", "Literacy", "GC/L"),
    SourceDefinition("GC_N", "generalCapability", "Numeracy", "GC/N"),
    SourceDefinition("GC_PSC", "generalCapability", "Personal and Social capability", "GC/PSC"),
    SourceDefinition("CCP_S", "crossCurriculumPriority", "Sustainability", "CCP/S"),
    SourceDefinition("CCP_A_TSI", "crossCurriculumPriority", "Aboriginal and Torres Strait Islander Histories and Cultures", "CCP/A_TSI"),
    SourceDefinition("CCP_AA", "crossCurriculumPriority", "Asia and Australia's engagement with Asia", "CCP/AA"),
]

SOURCE_BY_KEY = {source.key: source for source in SOURCES}
LEARNING_AREA_KEY = {
    "the arts": "LA_ART",
    "english": "LA_ENG",
    "health and physical education": "LA_HPE",
    "humanities and social sciences": "LA_HASS",
    "languages": "LA_LAN",
    "mathematics": "LA_MAT",
    "science": "LA_SCI",
    "technologies": "LA_TEC",
}
GENERAL_CAPABILITY_KEY = {
    "critical and creative thinking": "GC_CCT",
    "digital literacy": "GC_DL",
    "ethical understanding": "GC_EU",
    "intercultural understanding": "GC_IU",
    "literacy": "GC_L",
    "numeracy": "GC_N",
    "personal and social capability": "GC_PSC",
}
PRIORITY_KEY = {
    "sustainability": "CCP_S",
    "aboriginal and torres strait islander histories and cultures": "CCP_A_TSI",
    "asia and australia's engagement with asia": "CCP_AA",
    "asia and australia’s engagement with asia": "CCP_AA",
}

REQUIRED_SOURCE_KEYS = {source.key for source in SOURCES}
SEED_IDS = {"AC-ENG-Y7-RESPOND", "AC-MATH-Y6-REASON", "AC-HASS-Y8-SOURCE"}
NS = {"m": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}


def utcnow() -> str:
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_text(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def clean_html(value: Any) -> str:
    if value is None:
        return ""
    text = str(value)
    text = re.sub(r"<\s*br\s*/?>", "\n", text, flags=re.I)
    text = re.sub(r"</\s*p\s*>", "\n", text, flags=re.I)
    text = re.sub(r"<[^>]+>", " ", text)
    text = html.unescape(text)
    text = re.sub(r"\s+", " ", text).strip()
    return text


def compact(value: Any) -> str:
    return clean_html(value)


def stable_item_id(source_key: str, external_uri: str) -> str:
    digest = hashlib.sha256(external_uri.encode("utf-8")).hexdigest()[:16]
    return f"acara-v9-{source_key.lower().replace('_', '-')}-{digest}"


def external_uri(source_key: str, code: str, suffix: str = "") -> str:
    source = SOURCE_BY_KEY[source_key]
    token = quote((code or suffix or source_key).strip(), safe="")
    return f"{source.jsonld_url}#{token}"


def normalize_year(value: str) -> tuple[str, str]:
    text = compact(value)
    lowered = text.lower()
    if not text:
        return "", ""
    if "foundation" in lowered and "year" in lowered:
        return "Foundation", ""
    match = re.search(r"years?\s+(\d+)\s*(?:and|to|-)\s*(\d+)", lowered)
    if match:
        return "", f"Years {match.group(1)}–{match.group(2)}"
    match = re.search(r"year\s+(\d+)", lowered)
    if match:
        return f"Year {match.group(1)}", ""
    match = re.search(r"level\s+(\d+)\s*\(\s*foundation\s*\)", lowered)
    if match:
        return "Foundation", ""
    match = re.search(r"levels?\s+(\d+)\s*(?:and|to|-)\s*(\d+)", lowered)
    if match:
        return "", f"Levels {match.group(1)}–{match.group(2)}"
    if "f-10" in lowered or "f–10" in lowered:
        return "", "F–10"
    if "f-2" in lowered or "f–2" in lowered:
        return "", "F–2"
    return text, ""


def classify_item(text_parts: list[str], code: str = "") -> str:
    text = " ".join([*text_parts, code]).lower()
    if "achievement standard" in text:
        return "achievement-standard"
    if "content description" in text or re.search(r"\bac9[a-z0-9]+\b", text):
        return "content-description"
    if "sub-strand" in text or "substrand" in text:
        return "substrand"
    if "strand" in text:
        return "strand"
    if "general capability" in text or code.startswith(("CCT", "DL", "EU", "IU", "LIT", "N", "PSC")):
        return "capability"
    if "cross-curriculum" in text or "priority" in text or code.startswith(("A_TSI", "SUST", "AA")):
        return "priority"
    return "concept"


def source_object(source: SourceDefinition, retrieved_at: str, sha: str, mode: str) -> dict[str, Any]:
    return {
        "id": source.key,
        "name": source.name,
        "version": SOURCE_VERSION,
        "provenance": f"{mode}. Normalized for local MarkForMe search and mapping.",
        "localPath": "",
        "importedAt": retrieved_at,
        "kind": source.kind,
        "sourceVersion": source.source_version,
        "jsonldURL": source.jsonld_url,
        "retrievedAt": retrieved_at,
        "sha256": sha,
        "licenseName": LICENSE_NAME,
    }


def item_object(
    *,
    source_key: str,
    code: str,
    title: str,
    short_description: str,
    learning_area: str,
    subject: str,
    year_level: str = "",
    band: str = "",
    strand: str = "",
    substrand: str = "",
    organizer: str = "",
    item_type: str = "concept",
    alt_labels: list[str] | None = None,
    tags: list[str] | None = None,
    uri_suffix: str = "",
) -> dict[str, Any]:
    source = SOURCE_BY_KEY[source_key]
    safe_code = compact(code) or sha256_text("|".join([title, short_description, uri_suffix]))[:12]
    uri = external_uri(source_key, safe_code, uri_suffix)
    item_id = stable_item_id(source_key, uri)
    display_title = compact(title) or safe_code
    display_description = compact(short_description)
    all_tags = sorted(set(filter(None, [*(tags or []), source.kind, item_type, learning_area, subject, year_level, band, strand, substrand])))
    return {
        "id": item_id,
        "source": source.name,
        "version": SOURCE_VERSION,
        "learningArea": compact(learning_area),
        "subject": compact(subject),
        "yearLevel": compact(year_level),
        "strand": compact(strand),
        "organizer": compact(organizer),
        "itemType": item_type,
        "code": safe_code,
        "title": display_title,
        "shortDescription": display_description,
        "sourceURL": uri,
        "provenance": f"Normalized from {source.source_version}; official source file URL is preserved.",
        "externalURI": uri,
        "sourceKey": source_key,
        "sourceName": source.name,
        "sourceVersion": source.source_version,
        "catalogKind": source.kind,
        "band": compact(band),
        "substrand": compact(substrand),
        "altLabels": sorted(set(filter(None, [compact(v) for v in alt_labels or []]))),
        "parentIDs": [],
        "childIDs": [],
        "tags": all_tags,
        "isOfficial": True,
        "isEditable": False,
        "licenseName": LICENSE_NAME,
        "sourceAttribution": ATTRIBUTION,
    }


def read_shared_strings(zf: zipfile.ZipFile) -> list[str]:
    try:
        root = ET.fromstring(zf.read("xl/sharedStrings.xml"))
    except KeyError:
        return []
    values: list[str] = []
    for si in root.findall("m:si", NS):
        parts: list[str] = []
        for t in si.findall(".//m:t", NS):
            parts.append(t.text or "")
        values.append("".join(parts))
    return values


def workbook_sheets(zf: zipfile.ZipFile) -> dict[str, str]:
    workbook = ET.fromstring(zf.read("xl/workbook.xml"))
    rels = ET.fromstring(zf.read("xl/_rels/workbook.xml.rels"))
    rel_by_id: dict[str, str] = {}
    for rel in rels:
        rid = rel.attrib.get("Id")
        target = rel.attrib.get("Target", "")
        if rid:
            rel_by_id[rid] = target
    sheets: dict[str, str] = {}
    for sheet in workbook.findall(".//m:sheet", NS):
        name = sheet.attrib.get("name", "")
        rid = sheet.attrib.get("{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id")
        target = rel_by_id.get(rid or "", "")
        if target:
            sheets[name] = "xl/" + target.lstrip("/")
    return sheets


def cell_text(cell: ET.Element, shared: list[str]) -> str:
    cell_type = cell.attrib.get("t")
    if cell_type == "s":
        value = cell.find("m:v", NS)
        if value is None or value.text is None:
            return ""
        try:
            return shared[int(value.text)]
        except (ValueError, IndexError):
            return ""
    if cell_type == "inlineStr":
        return "".join(t.text or "" for t in cell.findall(".//m:t", NS))
    value = cell.find("m:v", NS)
    return value.text if value is not None and value.text is not None else ""


def column_index(cell_ref: str) -> int:
    letters = re.sub(r"\d", "", cell_ref)
    index = 0
    for char in letters:
        index = index * 26 + (ord(char.upper()) - 64)
    return index - 1


def read_sheet_rows(zf: zipfile.ZipFile, path: str, shared: list[str]) -> list[list[str]]:
    root = ET.fromstring(zf.read(path))
    rows: list[list[str]] = []
    for row in root.findall(".//m:sheetData/m:row", NS):
        values: list[str] = []
        for cell in row.findall("m:c", NS):
            idx = column_index(cell.attrib.get("r", "A1"))
            while len(values) <= idx:
                values.append("")
            values[idx] = cell_text(cell, shared)
        rows.append(values)
    return rows


def row_dict(headers: list[str], row: list[str]) -> dict[str, str]:
    return {headers[i]: compact(row[i]) if i < len(row) else "" for i in range(len(headers))}


def build_from_workbook(generated_at: str) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    if not WORKBOOK_PATH.exists():
        raise FileNotFoundError(f"Missing workbook fallback: {WORKBOOK_PATH.relative_to(ROOT)}")
    workbook_bytes = WORKBOOK_PATH.read_bytes()
    workbook_sha = sha256_bytes(workbook_bytes)
    items: dict[str, dict[str, Any]] = {}
    per_source: dict[str, int] = {source.key: 0 for source in SOURCES}
    with zipfile.ZipFile(WORKBOOK_PATH) as zf:
        shared = read_shared_strings(zf)
        sheets = workbook_sheets(zf)

        # Learning areas and content descriptions.
        rows = read_sheet_rows(zf, sheets["Learning areas"], shared)
        headers = rows[0]
        for row in rows[1:]:
            r = row_dict(headers, row)
            area = r.get("Learning Area", "")
            source_key = LEARNING_AREA_KEY.get(area.lower())
            if not source_key:
                continue
            code = r.get("Code", "")
            level = r.get("Level", "")
            year, band = normalize_year(level)
            subject = r.get("Subject", "") or area
            strand = r.get("Strand", "")
            substrand = r.get("Sub-Strand", "")
            content = r.get("Content Description", "")
            elaboration = r.get("Elaboration", "")
            level_description = r.get("Level Description", "")
            topics = r.get("Topics", "")
            if not code and not any([content, elaboration, level_description, strand, substrand]):
                continue
            title = content or elaboration or substrand or strand or level_description or subject or code
            description = content or elaboration or level_description or substrand or strand
            text_parts = [area, subject, level, strand, substrand, content, elaboration, topics]
            item_type = classify_item(text_parts, code)
            if elaboration and not content:
                item_type = "elaboration"
            if level_description and not content and not elaboration and level:
                item_type = "concept"
            item = item_object(
                source_key=source_key,
                code=code,
                title=title,
                short_description=description,
                learning_area=area,
                subject=subject,
                year_level=year,
                band=band,
                strand=strand,
                substrand=substrand,
                organizer=topics,
                item_type=item_type,
                alt_labels=[level, topics],
                tags=["workbook-fallback"],
            )
            items[item["id"]] = item
            per_source[source_key] += 1

        # Achievement standards.
        rows = read_sheet_rows(zf, sheets["Achievement standards"], shared)
        headers = rows[0]
        for offset, row in enumerate(rows[1:], start=1):
            r = row_dict(headers, row)
            area = r.get("Learning Area", "")
            source_key = LEARNING_AREA_KEY.get(area.lower())
            standard = r.get("Achievement Standard", "")
            if not source_key or not standard:
                continue
            subject = r.get("Subject", "") or area
            year, band = normalize_year(r.get("Level", ""))
            code = f"AS-{source_key}-{sha256_text('|'.join([subject, r.get('Level', ''), standard]))[:10].upper()}"
            title = f"Achievement standard — {subject} {r.get('Level', '')}".strip()
            item = item_object(
                source_key=source_key,
                code=code,
                title=title,
                short_description=standard,
                learning_area=area,
                subject=subject,
                year_level=year,
                band=band,
                item_type="achievement-standard",
                tags=["achievement-standard", "workbook-fallback"],
                uri_suffix=f"achievement-standard-{offset}",
            )
            items[item["id"]] = item
            per_source[source_key] += 1

        # Cross-curriculum priorities.
        rows = read_sheet_rows(zf, sheets["Cross-curriculum priorities"], shared)
        headers = rows[0]
        for row in rows[1:]:
            r = row_dict(headers, row)
            priority = r.get("Cross-Curriculum Priority", "")
            source_key = PRIORITY_KEY.get(priority.lower())
            if not source_key:
                continue
            code = r.get("Code", "")
            title = r.get("Organising idea indicator", "") or r.get("Organising ideas title", "") or priority or code
            description = r.get("Description", "") or r.get("Organising idea indicator", "")
            if not code and not title:
                continue
            item = item_object(
                source_key=source_key,
                code=code,
                title=title,
                short_description=description,
                learning_area="Cross-curriculum priorities",
                subject=priority,
                item_type="priority",
                organizer=r.get("Organising ideas title", ""),
                tags=["cross-curriculum-priority", "workbook-fallback"],
            )
            items[item["id"]] = item
            per_source[source_key] += 1

        # General capabilities.
        rows = read_sheet_rows(zf, sheets["General capabilities"], shared)
        headers = rows[0]
        for row in rows[1:]:
            r = row_dict(headers, row)
            capability = r.get("General Capability", "")
            source_key = GENERAL_CAPABILITY_KEY.get(capability.lower())
            if not source_key:
                continue
            code = r.get("Code", "")
            title = r.get("Indicator", "") or r.get("Sub-Element", "") or r.get("Element", "") or capability or code
            description = r.get("Description", "") or r.get("Indicator", "")
            year, band = normalize_year(r.get("Level", ""))
            if not code and not title:
                continue
            item = item_object(
                source_key=source_key,
                code=code,
                title=title,
                short_description=description,
                learning_area="General capabilities",
                subject=capability,
                year_level=year,
                band=band,
                strand=r.get("Element", ""),
                substrand=r.get("Sub-Element", ""),
                item_type="capability",
                tags=["general-capability", "workbook-fallback"],
            )
            items[item["id"]] = item
            per_source[source_key] += 1

    source_mode = "Official Australian Curriculum workbook fallback used because MRAC JSON-LD source refresh could not run in this environment"
    source_sha = {source.key: sha256_text(f"{source.key}:{workbook_sha}") for source in SOURCES}
    sources = [source_object(source, generated_at, source_sha[source.key], source_mode) for source in SOURCES]
    catalog_items = sorted(
        items.values(),
        key=lambda i: (i["catalogKind"], i["learningArea"], i["subject"], i["yearLevel"], i["band"], i["code"], i["title"], i["id"]),
    )
    catalog = base_catalog(generated_at, sources, catalog_items)
    manifest = base_manifest(generated_at, sources, per_source, source_mode)
    manifest["workbookFallback"] = {
        "path": WORKBOOK_PATH.relative_to(ROOT).as_posix(),
        "sha256": workbook_sha,
        "rationale": "Network access for MRAC JSON-LD download was unavailable in the implementation environment; the committed app catalog was normalized from the official Australian Curriculum workbook already present in the repository.",
    }
    summary = base_summary(generated_at, catalog, per_source, source_mode)
    return catalog, manifest, summary


def flatten_values(value: Any) -> list[str]:
    if value is None:
        return []
    if isinstance(value, str):
        return [value]
    if isinstance(value, list):
        values: list[str] = []
        for item in value:
            values.extend(flatten_values(item))
        return values
    if isinstance(value, dict):
        if "@value" in value:
            return [str(value.get("@value", ""))]
        if "value" in value:
            return [str(value.get("value", ""))]
        if "@id" in value:
            return [str(value.get("@id", ""))]
    return [str(value)]


def jsonld_value(node: dict[str, Any], *names: str) -> str:
    keys = []
    for name in names:
        keys.extend([name, f"skos:{name}", f"http://www.w3.org/2004/02/skos/core#{name}"])
    for key in keys:
        values = [clean_html(v) for v in flatten_values(node.get(key))]
        values = [v for v in values if v]
        if values:
            return values[0]
    return ""


def download_sources() -> dict[str, bytes]:
    CACHE_DIR.mkdir(parents=True, exist_ok=True)
    downloaded: dict[str, bytes] = {}
    errors: list[str] = []
    for source in SOURCES:
        target = CACHE_DIR / f"{source.key}.jsonld"
        try:
            with urllib.request.urlopen(source.jsonld_url, timeout=45) as response:
                data = response.read()
            target.write_bytes(data)
            downloaded[source.key] = data
        except (urllib.error.URLError, TimeoutError, OSError) as error:
            if target.exists():
                data = target.read_bytes()
                downloaded[source.key] = data
            else:
                errors.append(f"{source.key}: {error}")
    if errors and downloaded:
        raise RuntimeError("MRAC JSON-LD refresh was partial; refusing mixed-source generation:\n" + "\n".join(errors))
    if errors:
        raise RuntimeError("MRAC JSON-LD refresh unavailable:\n" + "\n".join(errors))
    return downloaded


def build_from_jsonld(blobs: dict[str, bytes], generated_at: str) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    items: dict[str, dict[str, Any]] = {}
    per_source: dict[str, int] = {source.key: 0 for source in SOURCES}
    source_sha = {key: sha256_bytes(data) for key, data in blobs.items()}
    for source in SOURCES:
        payload = json.loads(blobs[source.key].decode("utf-8"))
        graph = payload.get("@graph") if isinstance(payload, dict) else None
        if not isinstance(graph, list):
            raise RuntimeError(f"{source.key} did not contain a JSON-LD @graph array")
        for node in graph:
            if not isinstance(node, dict):
                continue
            uri = node.get("@id")
            if not isinstance(uri, str) or not uri.startswith(("http://", "https://")):
                continue
            code = jsonld_value(node, "notation") or pathlib.PurePosixPath(uri).name
            title = jsonld_value(node, "prefLabel", "label") or code
            description = jsonld_value(node, "definition", "description")
            item_type = classify_item([json.dumps(node.get("@type", "")), title, description, code, jsonld_value(node, "inScheme")], code)
            year, band = normalize_year(" ".join([title, code, description]))
            item = item_object(
                source_key=source.key,
                code=code,
                title=title,
                short_description=description,
                learning_area=source.name if source.kind == "learningArea" else ("General capabilities" if source.kind == "generalCapability" else "Cross-curriculum priorities"),
                subject=source.name,
                year_level=year,
                band=band,
                item_type=item_type,
                alt_labels=flatten_values(node.get("altLabel")) + flatten_values(node.get("skos:altLabel")),
                tags=["jsonld"],
            )
            # Preserve the official node URI rather than the source URL fragment generated by item_object.
            item["externalURI"] = uri
            item["sourceURL"] = uri
            item["id"] = stable_item_id(source.key, uri)
            items[item["id"]] = item
            per_source[source.key] += 1
    source_mode = "Machine Readable Australian Curriculum Version 9.0 JSON-LD source"
    sources = [source_object(source, generated_at, source_sha[source.key], source_mode) for source in SOURCES]
    catalog_items = sorted(
        items.values(),
        key=lambda i: (i["catalogKind"], i["learningArea"], i["subject"], i["yearLevel"], i["band"], i["code"], i["title"], i["id"]),
    )
    catalog = base_catalog(generated_at, sources, catalog_items)
    manifest = base_manifest(generated_at, sources, per_source, source_mode)
    summary = base_summary(generated_at, catalog, per_source, source_mode)
    return catalog, manifest, summary


def base_catalog(generated_at: str, sources: list[dict[str, Any]], items: list[dict[str, Any]]) -> dict[str, Any]:
    return {
        "schemaVersion": SCHEMA_VERSION,
        "catalogID": CATALOG_ID,
        "displayName": "Australian Curriculum Version 9.0 reference catalog",
        "sourceVersion": SOURCE_VERSION,
        "filesUpdated": FILES_UPDATED,
        "generatedAt": generated_at,
        "generatedBy": SCRIPT_NAME,
        "licenseName": LICENSE_NAME,
        "attributionText": ATTRIBUTION,
        "nonEndorsementWarning": NON_ENDORSEMENT,
        "icipWarning": ICIP_WARNING,
        "warning": NON_ENDORSEMENT,
        "sources": sources,
        "items": items,
        "relationships": [],
        "tags": [],
    }


def base_manifest(generated_at: str, sources: list[dict[str, Any]], per_source: dict[str, int], mode: str) -> dict[str, Any]:
    return {
        "schemaVersion": SCHEMA_VERSION,
        "catalogID": CATALOG_ID,
        "sourceVersion": SOURCE_VERSION,
        "filesUpdated": FILES_UPDATED,
        "generatedAt": generated_at,
        "generatedBy": SCRIPT_NAME,
        "sourceMode": mode,
        "requiredSourceKeys": sorted(REQUIRED_SOURCE_KEYS),
        "sources": [
            {
                "id": source["id"],
                "kind": source["kind"],
                "name": source["name"],
                "jsonldURL": source["jsonldURL"],
                "sourceVersion": source["sourceVersion"],
                "sha256": source["sha256"],
                "itemCount": per_source.get(source["id"], 0),
            }
            for source in sources
        ],
        "resourceChecksums": {},
    }


def base_summary(generated_at: str, catalog: dict[str, Any], per_source: dict[str, int], mode: str) -> dict[str, Any]:
    items = catalog["items"]
    kind_counts: dict[str, int] = {}
    area_counts: dict[str, int] = {}
    for item in items:
        kind_counts[item["itemType"]] = kind_counts.get(item["itemType"], 0) + 1
        area_counts[item["learningArea"]] = area_counts.get(item["learningArea"], 0) + 1
    return {
        "schemaVersion": SCHEMA_VERSION,
        "catalogID": CATALOG_ID,
        "generatedAt": generated_at,
        "generatedBy": SCRIPT_NAME,
        "sourceMode": mode,
        "sourceCount": len(catalog["sources"]),
        "itemCount": len(items),
        "officialItemCount": sum(1 for item in items if item.get("isOfficial") is True),
        "sourceCounts": dict(sorted(per_source.items())),
        "itemTypeCounts": dict(sorted(kind_counts.items())),
        "learningAreaCounts": dict(sorted(area_counts.items())),
        "lowerOfficialParsedCountRationale": "",
    }


def write_json(path: pathlib.Path, data: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes((json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode("utf-8"))


def generate(refresh_jsonld: bool) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    generated_at = utcnow()
    if refresh_jsonld:
        try:
            blobs = download_sources()
            return build_from_jsonld(blobs, generated_at)
        except RuntimeError as error:
            print(str(error), file=sys.stderr)
            print("Falling back to local official curriculum workbook.", file=sys.stderr)
    return build_from_workbook(generated_at)


def validate_loaded(catalog: dict[str, Any], manifest: dict[str, Any], summary: dict[str, Any]) -> list[str]:
    failures: list[str] = []
    for key in ["schemaVersion", "catalogID", "displayName", "sourceVersion", "generatedAt", "generatedBy", "licenseName", "attributionText", "nonEndorsementWarning", "icipWarning", "sources", "items"]:
        if key not in catalog:
            failures.append(f"Catalog missing top-level key {key}")
    source_keys = {source.get("id") for source in catalog.get("sources", [])}
    missing = sorted(REQUIRED_SOURCE_KEYS - source_keys)
    if missing:
        failures.append("Catalog missing required sources: " + ", ".join(missing))
    if len(catalog.get("sources", [])) < 18:
        failures.append("Catalog contains fewer than 18 required sources")
    items = catalog.get("items", [])
    item_count = len(items) if isinstance(items, list) else 0
    lower_rationale = str(summary.get("lowerOfficialParsedCountRationale", "")).strip()
    if item_count < 5000 and not lower_rationale:
        failures.append(f"Catalog contains {item_count} items; expected at least 5000 or a documented lower official parsed count rationale")
    per_source_count = {key: 0 for key in REQUIRED_SOURCE_KEYS}
    for item in items:
        source_key = item.get("sourceKey", "")
        if source_key in per_source_count:
            per_source_count[source_key] += 1
        if item.get("isOfficial") is True and item.get("isEditable") is True:
            failures.append(f"Official item is editable: {item.get('id')}")
        if item.get("isOfficial") is True:
            uri = str(item.get("externalURI", ""))
            if not uri.startswith(("http://", "https://")):
                failures.append(f"Official item missing external URI: {item.get('id')}")
            if "ACARA" not in str(item.get("sourceAttribution", "")):
                failures.append(f"Official item missing ACARA attribution: {item.get('id')}")
    for key, count in sorted(per_source_count.items()):
        if count <= 0:
            failures.append(f"Required source has no parsed items: {key}")
    for source in catalog.get("sources", []):
        if not re.fullmatch(r"[a-f0-9]{64}", str(source.get("sha256", ""))):
            failures.append(f"Source {source.get('id')} missing SHA-256")
    warning = " ".join([str(catalog.get("warning", "")), str(catalog.get("nonEndorsementWarning", "")), str(catalog.get("attributionText", ""))]).lower()
    if "does not claim" not in warning and "not affiliated" not in warning:
        failures.append("Catalog warning lacks non-endorsement copy")
    for prohibited in ["endorsed by acara", "certified by acara", "approved by acara", "official gradedraft", "jurisdiction-compliant reporting"]:
        if prohibited in warning:
            failures.append(f"Catalog copy contains prohibited phrase: {prohibited}")
    if set(manifest.get("requiredSourceKeys", [])) != REQUIRED_SOURCE_KEYS:
        failures.append("Manifest requiredSourceKeys does not match the required source set")
    if int(summary.get("itemCount", 0)) != item_count:
        failures.append("Summary itemCount does not match catalog items")
    seed_only = item_count <= len(SEED_IDS) and all(item.get("id") in SEED_IDS for item in items)
    if seed_only:
        failures.append("Catalog is still seed-only")
    return failures


def validate_files() -> list[str]:
    failures: list[str] = []
    for path in [CATALOG_PATH, MANIFEST_PATH, SUMMARY_PATH]:
        if not path.exists():
            failures.append(f"Missing generated resource: {path.relative_to(ROOT)}")
    if failures:
        return failures
    try:
        catalog = json.loads(CATALOG_PATH.read_text(encoding="utf-8"))
        manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
        summary = json.loads(SUMMARY_PATH.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        return [f"Generated JSON did not decode: {error}"]
    failures.extend(validate_loaded(catalog, manifest, summary))
    # Verify committed checksum metadata after reading all resources.
    actual = {
        CATALOG_PATH.name: sha256_bytes(CATALOG_PATH.read_bytes()),
        SUMMARY_PATH.name: sha256_bytes(SUMMARY_PATH.read_bytes()),
    }
    recorded = manifest.get("resourceChecksums", {})
    for required_name in actual:
        if required_name not in recorded:
            failures.append(f"Manifest missing checksum for {required_name}")
    for name, checksum in recorded.items():
        if name not in actual:
            failures.append(f"Manifest records unsupported self-referential or unknown checksum for {name}")
            continue
        if actual[name] != checksum:
            failures.append(f"Manifest checksum mismatch for {name}")
    return failures


def command_refresh(args: argparse.Namespace) -> int:
    catalog, manifest, summary = generate(refresh_jsonld=not args.workbook_only)
    # Write once without resource checksums, compute, then write manifest with final checksums.
    write_json(CATALOG_PATH, catalog)
    write_json(SUMMARY_PATH, summary)
    manifest["resourceChecksums"] = {
        CATALOG_PATH.name: sha256_bytes(CATALOG_PATH.read_bytes()),
        SUMMARY_PATH.name: sha256_bytes(SUMMARY_PATH.read_bytes()),
    }
    write_json(MANIFEST_PATH, manifest)
    print(f"Wrote {CATALOG_PATH.relative_to(ROOT)} with {len(catalog['items'])} items from {len(catalog['sources'])} sources.")
    return 0


def command_check() -> int:
    failures = validate_files()
    if failures:
        print("Curriculum catalog check failed:")
        for failure in failures:
            print(f"- {failure}")
        return 1
    print("Curriculum catalog check passed.")
    return 0


def command_print_summary() -> int:
    if not SUMMARY_PATH.exists():
        print("No generated summary found. Run --refresh first.", file=sys.stderr)
        return 1
    summary = json.loads(SUMMARY_PATH.read_text(encoding="utf-8"))
    print(json.dumps(summary, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--refresh", action="store_true", help="download/cache MRAC JSON-LD when available and regenerate bundled resources")
    group.add_argument("--check", action="store_true", help="validate committed generated resources without network")
    group.add_argument("--print-summary", action="store_true", help="print generated catalog summary")
    parser.add_argument("--workbook-only", action="store_true", help="regenerate from the local official workbook without attempting MRAC JSON-LD download")
    args = parser.parse_args()
    if args.refresh:
        return command_refresh(args)
    if args.check:
        return command_check()
    return command_print_summary()


if __name__ == "__main__":
    raise SystemExit(main())

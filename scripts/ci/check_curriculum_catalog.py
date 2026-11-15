#!/usr/bin/env python3
"""Validate the bundled Australian Curriculum SQLite catalogue."""
from __future__ import annotations

import json
import pathlib
import sqlite3
import sys

ROOT = pathlib.Path(__file__).resolve().parents[2]
DB_PATH = ROOT / "GradeDraft" / "Resources" / "Curriculum" / "curriculum_acara_v9.sqlite"


def validate(connection: sqlite3.Connection) -> list[str]:
    failures: list[str] = []
    sources = connection.execute("SELECT id, attribution FROM source").fetchall()
    if not sources:
        failures.append("Table `source` is empty")
    for source_id, attribution in sources:
        count = connection.execute("SELECT count(*) FROM item WHERE sourceID = ?", (source_id,)).fetchone()[0]
        if count <= 0:
            failures.append(f"Source {source_id} has no items")
        if "ACARA" not in attribution:
            failures.append(f"Source {source_id} is missing ACARA attribution")
    orphans = connection.execute("SELECT count(*) FROM item WHERE sourceID NOT IN (SELECT id FROM source)").fetchone()[0]
    if orphans:
        failures.append(f"{orphans} item(s) reference a source that does not exist")

    ids = {row[0] for row in connection.execute("SELECT id FROM item")}
    for item_id, parents, children in connection.execute("SELECT id, parentIDs, childIDs FROM item"):
        for column, raw in (("parentIDs", parents), ("childIDs", children)):
            try:
                referenced = json.loads(raw)
            except json.JSONDecodeError:
                failures.append(f"Item {item_id} has invalid JSON in {column}")
                continue
            for other in referenced:
                if other not in ids:
                    failures.append(f"Item {item_id} {column} references missing item {other}")

    item_count = len(ids)
    indexed = connection.execute("SELECT count(*) FROM itemSearch_docsize").fetchone()[0]
    if indexed != item_count:
        failures.append(f"Full-text index has {indexed} row(s) but there are {item_count} item(s)")
    return failures


def main() -> int:
    if not DB_PATH.exists():
        print(f"Curriculum catalog validator failed:\n- Missing {DB_PATH.relative_to(ROOT).as_posix()}")
        return 1
    connection = sqlite3.connect(f"file:{DB_PATH.as_posix()}?mode=ro", uri=True)
    try:
        failures = validate(connection)
    finally:
        connection.close()
    if failures:
        print("Curriculum catalog validator failed:")
        for failure in failures[:50]:
            print(f"- {failure}")
        return 1
    print("Curriculum catalog validator passed.")
    return 0


if __name__ == "__main__":
    sys.exit(main())

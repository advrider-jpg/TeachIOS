#!/usr/bin/env python3
"""Select a current iPhone simulator destination for GradeDraft CI."""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass


@dataclass(frozen=True)
class Candidate:
    name: str
    udid: str
    runtime_identifier: str
    runtime_name: str
    version: tuple[int, ...]


def runtime_version(identifier: str, runtime_name: str) -> tuple[int, ...]:
    text = f"{identifier} {runtime_name}"
    match = re.search(r"iOS[- ]([0-9]+(?:[-.][0-9]+)*)", text)
    if not match:
        return ()
    return tuple(int(part) for part in re.split(r"[-.]", match.group(1)) if part.isdigit())


def model_rank(name: str) -> tuple[int, int, str]:
    number_match = re.search(r"iPhone\s+([0-9]+)", name)
    number = int(number_match.group(1)) if number_match else 0
    tier = 0
    if "Pro Max" in name:
        tier = 4
    elif "Pro" in name:
        tier = 3
    elif "Plus" in name:
        tier = 2
    return (number, tier, name)


def load_devices() -> dict:
    try:
        result = subprocess.run(
            ["xcrun", "simctl", "list", "devices", "available", "--json"],
            text=True,
            capture_output=True,
            check=False,
        )
    except FileNotFoundError:
        raise SystemExit("xcrun was not found. iOS simulator selection requires macOS with Xcode.") from None
    if result.returncode != 0:
        print(result.stdout, file=sys.stderr)
        print(result.stderr, file=sys.stderr)
        raise SystemExit("Could not list available iOS simulators.")
    return json.loads(result.stdout)


def select_candidate(min_major: int) -> Candidate:
    payload = load_devices()
    candidates: list[Candidate] = []
    for runtime_identifier, devices in payload.get("devices", {}).items():
        if "iOS" not in runtime_identifier:
            continue
        version = runtime_version(runtime_identifier, runtime_identifier)
        if not version or version[0] < min_major:
            continue
        runtime_name = runtime_identifier.rsplit(".", 1)[-1].replace("-", " ")
        for device in devices:
            name = device.get("name", "")
            udid = device.get("udid", "")
            if not device.get("isAvailable", True):
                continue
            if not name.startswith("iPhone ") or not udid:
                continue
            candidates.append(Candidate(name, udid, runtime_identifier, runtime_name, version))

    if not candidates:
        print(f"No available iPhone simulator with iOS {min_major}+ was found.", file=sys.stderr)
        subprocess.run(["xcrun", "simctl", "list", "devices", "available"], check=False)
        raise SystemExit(1)

    return max(candidates, key=lambda candidate: (candidate.version, model_rank(candidate.name)))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--print-destination", action="store_true", help="Print only the xcodebuild destination string.")
    args = parser.parse_args()

    min_major = int(os.environ.get("IOS_MIN_MAJOR", "26"))
    candidate = select_candidate(min_major)
    destination = f"platform=iOS Simulator,id={candidate.udid},arch=arm64"
    summary = (
        f"Selected simulator: {candidate.name} "
        f"({candidate.runtime_name}, {candidate.runtime_identifier}, {candidate.udid})"
    )

    if args.print_destination:
        print(destination)
        print(summary, file=sys.stderr)
    else:
        print(summary)
        github_output = os.environ.get("GITHUB_OUTPUT")
        if github_output:
            with open(github_output, "a", encoding="utf-8") as output:
                output.write(f"destination={destination}\n")
                output.write(f"device_name={candidate.name}\n")
                output.write(f"runtime_name={candidate.runtime_name}\n")
                output.write(f"runtime_identifier={candidate.runtime_identifier}\n")
                output.write(f"udid={candidate.udid}\n")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

#!/usr/bin/env bash
set -euo pipefail

MIN_MAJOR="${XCODE_MIN_MAJOR:-26}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Xcode selection requires macOS. This machine reports $(uname -s)." >&2
  exit 1
fi

candidate_paths=()
if [[ -n "${GRADE_DRAFT_XCODE_PATH:-}" ]]; then
  candidate_paths+=("$GRADE_DRAFT_XCODE_PATH")
fi

while IFS= read -r path; do
  candidate_paths+=("$path")
done < <(/usr/bin/python3 - "$MIN_MAJOR" <<'PY'
import glob
import os
import re
import sys

min_major = int(sys.argv[1])
paths = glob.glob(f"/Applications/Xcode_{min_major}*.app")

def version_key(path: str) -> tuple[int, ...]:
    name = os.path.basename(path)
    match = re.search(r"Xcode_([0-9]+(?:\.[0-9]+)*)", name)
    if not match:
        return ()
    return tuple(int(part) for part in match.group(1).split("."))

for app in sorted(paths, key=version_key, reverse=True):
    print(app)
PY
)

candidate_paths+=("/Applications/Xcode.app")

for app in "${candidate_paths[@]}"; do
  if [[ ! -d "$app" ]]; then
    continue
  fi
  sudo xcode-select -s "$app/Contents/Developer"
  version="$(xcodebuild -version | awk '/Xcode/{print $2}')"
  major="${version%%.*}"
  if [[ "$major" =~ ^[0-9]+$ ]] && (( major >= MIN_MAJOR )); then
    echo "Selected Xcode $version at $app"
    xcodebuild -version
    echo "Developer directory: $(xcode-select -p)"
    exit 0
  fi
  echo "Rejected Xcode $version at $app because Xcode ${MIN_MAJOR}+ is required." >&2
done

echo "No Xcode ${MIN_MAJOR}+ installation found." >&2
echo "Installed Xcode apps:" >&2
ls -d /Applications/Xcode*.app 2>/dev/null || true
exit 1

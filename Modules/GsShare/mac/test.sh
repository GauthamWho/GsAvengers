#!/bin/bash
# Unit tests for the key table + cursor rules. Usage: bash mac/test.sh
set -euo pipefail
cd "$(dirname "$0")/.."
OUT="${TMPDIR:-/tmp}/gsav-tests"
swiftc -target arm64-apple-macos13.0 -o "$OUT" mac/Sources/KeyMap.swift mac/Sources/KeyRules.swift mac/Sources/Config.swift \
  mac/Sources/Injector.swift mac/Sources/LocalInput.swift mac/Tests/main.swift
"$OUT"

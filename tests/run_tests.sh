#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$(command -v godot || true)}"

if [[ -z "${GODOT_BIN}" ]]; then
  echo "GODOT_BIN is not set and godot is not on PATH." >&2
  exit 1
fi

"${GODOT_BIN}" --headless --path "${ROOT_DIR}" --import
"${GODOT_BIN}" --headless --path "${ROOT_DIR}" --script res://tests/test_runner.gd

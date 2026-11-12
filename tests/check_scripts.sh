#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$(command -v godot || true)}"

if [[ -z "${GODOT_BIN}" ]]; then
  echo "GODOT_BIN is not set and godot is not on PATH." >&2
  exit 1
fi

checked=0
failed=0

while IFS= read -r -d '' file; do
  relative="${file#"${ROOT_DIR}/"}"
  checked=$((checked + 1))
  if ! "${GODOT_BIN}" --headless --path "${ROOT_DIR}" --check-only --script "res://${relative}" >/dev/null 2>&1; then
    echo "Type check failed: ${relative}" >&2
    "${GODOT_BIN}" --headless --path "${ROOT_DIR}" --check-only --script "res://${relative}" 2>&1 | tail -20 >&2 || true
    failed=$((failed + 1))
  fi
done < <(find "${ROOT_DIR}/scripts" "${ROOT_DIR}/tests" "${ROOT_DIR}/tools" -name '*.gd' -print0 | sort -z)

if ((failed > 0)); then
  echo "TYPE CHECK: ${checked} scripts checked, ${failed} failed." >&2
  exit 1
fi

echo "TYPE CHECK: ${checked} scripts checked, 0 failed."

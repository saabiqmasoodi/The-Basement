#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
GODOT_BIN="${GODOT_BIN:-$(command -v godot || true)}"
PLATFORM="${1:-all}"

if [[ -z "${GODOT_BIN}" ]]; then
  echo "GODOT_BIN is not set and godot is not on PATH." >&2
  exit 1
fi

cd "${ROOT_DIR}"
"${GODOT_BIN}" --headless --path "${ROOT_DIR}" --import
mkdir -p build/releases/windows build/releases/macos build/releases/linux build/artifacts

if [[ "${PLATFORM}" == "all" || "${PLATFORM}" == "windows" ]]; then
  rm -f build/releases/windows/NotToLove.exe
  "${GODOT_BIN}" --headless --path "${ROOT_DIR}" --export-release "Windows Desktop" build/releases/windows/NotToLove.exe
  (cd build/releases/windows && zip -qr "${ROOT_DIR}/build/artifacts/NotToLove-windows.zip" .)
fi

if [[ "${PLATFORM}" == "all" || "${PLATFORM}" == "macos" ]]; then
  rm -rf build/releases/macos/NotToLove.app
  "${GODOT_BIN}" --headless --path "${ROOT_DIR}" --export-release "macOS" build/releases/macos/NotToLove.app
  if command -v ditto >/dev/null 2>&1; then
    ditto -c -k --sequesterRsrc --keepParent build/releases/macos/NotToLove.app build/artifacts/NotToLove-macos.zip
  else
    (cd build/releases/macos && zip -qry "${ROOT_DIR}/build/artifacts/NotToLove-macos.zip" NotToLove.app)
  fi
fi

if [[ "${PLATFORM}" == "all" || "${PLATFORM}" == "linux" ]]; then
  rm -f build/releases/linux/NotToLove.x86_64
  "${GODOT_BIN}" --headless --path "${ROOT_DIR}" --export-release "Linux" build/releases/linux/NotToLove.x86_64
  (cd build/releases/linux && zip -qr "${ROOT_DIR}/build/artifacts/NotToLove-linux.zip" .)
fi

ls -lh build/artifacts

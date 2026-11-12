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

# Do not pass --headless to the export commands. The shader baker needs the
# renderer initialized so it can embed precompiled shaders in the PCK. This is
# what prevents the first New Game from blocking on GPU driver compilation.

if [[ "${PLATFORM}" == "all" || "${PLATFORM}" == "windows" ]]; then
  rm -f build/releases/windows/NotToLove.exe build/artifacts/NotToLove-Windows-x86_64.exe
  "${GODOT_BIN}" --path "${ROOT_DIR}" --export-release "Windows Desktop" build/releases/windows/NotToLove.exe
  cp build/releases/windows/NotToLove.exe build/artifacts/NotToLove-Windows-x86_64.exe
fi

if [[ "${PLATFORM}" == "all" || "${PLATFORM}" == "macos" ]]; then
  rm -rf build/releases/macos/NotToLove.app build/artifacts/NotToLove-macOS-universal.dmg
  "${GODOT_BIN}" --path "${ROOT_DIR}" --export-release "macOS" build/releases/macos/NotToLove.app
  if command -v hdiutil >/dev/null 2>&1; then
    STAGE="${ROOT_DIR}/build/dmg-stage"
    rm -rf "${STAGE}"
    mkdir -p "${STAGE}"
    cp -R build/releases/macos/NotToLove.app "${STAGE}/Not To Love.app"
    if python3 -c "import dmgbuild" >/dev/null 2>&1; then
      rm -f build/artifacts/NotToLove-macOS-universal.dmg
      python3 -m dmgbuild \
        -s packaging/dmg_settings.py \
        -D app="${STAGE}/Not To Love.app" \
        "Not To Love" \
        build/artifacts/NotToLove-macOS-universal.dmg
    else
      ln -s /Applications "${STAGE}/Applications"
      hdiutil create -volname "Not To Love" -srcfolder "${STAGE}" -ov -format UDZO \
        build/artifacts/NotToLove-macOS-universal.dmg
    fi
  else
    echo "hdiutil not found; a DMG can only be created on macOS." >&2
    exit 1
  fi
fi

if [[ "${PLATFORM}" == "all" || "${PLATFORM}" == "linux" ]]; then
  rm -f build/releases/linux/NotToLove.x86_64 build/artifacts/NotToLove-Linux-x86_64 \
    build/artifacts/NotToLove-Linux-x86_64.tar.gz
  "${GODOT_BIN}" --path "${ROOT_DIR}" --export-release "Linux" build/releases/linux/NotToLove.x86_64
  cp build/releases/linux/NotToLove.x86_64 build/artifacts/NotToLove-Linux-x86_64
  tar -C build/artifacts -czf build/artifacts/NotToLove-Linux-x86_64.tar.gz NotToLove-Linux-x86_64
fi

ls -lh build/artifacts

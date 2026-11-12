#!/usr/bin/env python3
"""Check that every res:// reference and .import source points at a real file."""

from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKIP_DIRS = {".git", ".godot", "build", "godot-mcp"}
TEXT_SUFFIXES = {".gd", ".tscn", ".tres", ".gdshader", ".cfg"}
REFERENCE_RE = re.compile(r"res://[^\"'\n<>]+")
IMPORT_SOURCE_RE = re.compile(r'^source_file="(res://[^"]+)"', re.MULTILINE)


def iter_files() -> list[Path]:
    files: list[Path] = []
    for path in ROOT.rglob("*"):
        if any(part in SKIP_DIRS for part in path.relative_to(ROOT).parts):
            continue
        if path.is_file():
            files.append(path)
    return files


def clean_reference(value: str) -> str:
    value = value.split(" -- ", 1)[0]
    return value.rstrip(".,;:)]}")


def main() -> int:
    files = iter_files()
    missing: list[tuple[Path, str]] = []
    references = 0

    for path in files:
        if path.suffix not in TEXT_SUFFIXES:
            continue
        text = path.read_text(encoding="utf-8", errors="ignore")
        for match in REFERENCE_RE.findall(text):
            reference = clean_reference(match)
            if reference == "res://":
                continue
            references += 1
            target = ROOT / reference.removeprefix("res://")
            if not target.exists():
                missing.append((path, reference))

    imports = 0
    for path in files:
        if path.suffix != ".import":
            continue
        imports += 1
        text = path.read_text(encoding="utf-8", errors="ignore")
        match = IMPORT_SOURCE_RE.search(text)
        if match is None:
            missing.append((path, "<missing source_file>"))
            continue
        target = ROOT / match.group(1).removeprefix("res://")
        if not target.exists():
            missing.append((path, match.group(1)))

    for path, reference in missing:
        print(f"{path.relative_to(ROOT)}: missing {reference}", file=sys.stderr)

    print(f"REFERENCES: {references} checked, {imports} imports checked, {len(missing)} missing.")
    return 1 if missing else 0


if __name__ == "__main__":
    raise SystemExit(main())

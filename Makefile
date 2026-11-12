GODOT_BIN ?= godot
PYTHON ?= python3

.PHONY: format lint format-check typecheck test references check build clean

format:
	gdformat scripts tests tools

lint:
	gdlint scripts tests tools

format-check:
	gdformat --check scripts tests tools

typecheck:
	GODOT_BIN="$(GODOT_BIN)" ./tests/check_scripts.sh

test:
	GODOT_BIN="$(GODOT_BIN)" ./tests/run_tests.sh

references:
	$(PYTHON) tests/check_references.py

check: lint format-check references typecheck test

build:
	./tools/build_release.sh

clean:
	rm -rf build/releases build/artifacts

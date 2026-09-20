# Required Godot version (see also .godot-version at repo root).
GODOT_VERSION := $(shell tr -d '[:space:]' < .godot-version)
GODOT ?= $(HOME)/bin/godot
EXPORT_PRESET := Linux
EXPORT_PATH := build/linux/project_polder.x86_64

.PHONY: help check-godot editor run import test build clean

help:
	@echo "Project Polder — local Godot targets"
	@echo "  make check-godot  Verify editor at \$$GODOT matches .godot-version ($(GODOT_VERSION))"
	@echo "  make editor       Open the Godot editor"
	@echo "  make run          Run the project"
	@echo "  make import       Headless reimport assets"
	@echo "  make test         Run GUT headless; fails on load errors and empty runs too (ARGS=\"-gselect=name\" to filter)"
	@echo "  make build        Export Linux x86_64 release to $(EXPORT_PATH)"
	@echo "  make clean        Remove build/ output"

check-godot:
	@test -x "$(GODOT)" || { echo "Godot not found at $(GODOT). Install $(GODOT_VERSION) to \$$HOME/bin (see docs/ENGINE.md)."; exit 1; }
	@ver=$$($(GODOT) --version); \
		echo "$$ver" | grep -F "$(GODOT_VERSION)" >/dev/null \
			|| { echo "Expected Godot $(GODOT_VERSION), got: $$ver"; exit 1; }; \
		echo "Using $$ver ($(GODOT))"

editor: check-godot
	$(GODOT) --path . --editor

run: check-godot
	$(GODOT) --path .

import: check-godot
	$(GODOT) --headless --path . --import
	@echo "Import finished."

test: check-godot
	./scripts/test.sh $(ARGS)

build: check-godot
	mkdir -p build/linux
	$(GODOT) --headless --path . --export-release "$(EXPORT_PRESET)" "$(EXPORT_PATH)"
	@echo "Exported to $(EXPORT_PATH)"

clean:
	rm -rf build

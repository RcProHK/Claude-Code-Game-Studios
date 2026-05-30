#!/usr/bin/env -S godot --headless --script
## CI Lint — CombatResolver must NOT be an autoload (GDD Rule 1, ADR-0006 C12)
##
## AC-autoload-lint / Story 001: CombatResolver is `class_name CombatResolver
## extends RefCounted` invoked via `CombatResolver.resolve_hit(ctx)` — a pure
## static class, NEVER a registered singleton. If it were an autoload it would
## have instance state and a node lifecycle, voiding the pure-function contract.
##
## This lint reads `project.godot`, locates the `[autoload]` section, and fails
## if any autoload entry references `CombatResolver` (either as the registration
## key `CombatResolver=...` or pointing at `combat_resolver.gd`).
##
## Usage:
##   godot --headless --script tools/ci/check_combat_resolver_autoload.gd
##
## Exit codes:
##   0 = CombatResolver is not registered as an autoload (clean)
##   1 = CombatResolver found in the [autoload] section (CI MUST fail)
##   2 = internal error (project.godot missing / unreadable)
##
## Governing docs: design/gdd/combat-resolver.md Rule 1; ADR-0006 Contract 12;
##   story-001-ci-lints-purity-defense.md AC-autoload-lint.
extends SceneTree


const PROJECT_FILE: String = "res://project.godot"


func _init() -> void:
	if not FileAccess.file_exists(PROJECT_FILE):
		push_error("[check_combat_resolver_autoload] project.godot not found at %s" % PROJECT_FILE)
		quit(2)
		return

	var file := FileAccess.open(PROJECT_FILE, FileAccess.READ)
	if file == null:
		push_error("[check_combat_resolver_autoload] cannot read project.godot")
		quit(2)
		return
	var lines: PackedStringArray = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()

	var in_autoload_section: bool = false
	var violations: Array[Dictionary] = []

	for i: int in lines.size():
		var raw_line: String = lines[i]
		var stripped: String = raw_line.strip_edges()

		if stripped.is_empty() or stripped.begins_with(";"):
			continue

		# Section header transitions (e.g. `[autoload]`, `[rendering]`).
		if stripped.begins_with("[") and stripped.ends_with("]"):
			in_autoload_section = stripped == "[autoload]"
			continue

		if not in_autoload_section:
			continue

		# Inside [autoload]: each entry is `Key="*res://path.gd"`.
		if stripped.contains("CombatResolver") or stripped.contains("combat_resolver.gd"):
			violations.append({"line": i + 1, "snippet": stripped})

	if violations.is_empty():
		print("[check_combat_resolver_autoload] PASS: CombatResolver is NOT a registered autoload")
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d: CombatResolver MUST NOT be an autoload (pure static class — GDD Rule 1, ADR-0006 C12)" % [PROJECT_FILE, v["line"]])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[check_combat_resolver_autoload] FAIL: %d [autoload] reference(s) to CombatResolver. Remove it from project.godot." % violations.size())
	quit(1)

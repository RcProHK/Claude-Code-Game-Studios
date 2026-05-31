#!/usr/bin/env -S godot --headless --script
## CI Lint — EnemyDirector RNG provenance enforcement (GDD Rule 4 / FR-3, Story 002 AC-14).
##
## Purpose:
##   All randomness MUST come from the seeded `_rng_factory` (RNGFactory class, Story 006).
##   Direct engine RNG calls produce non-deterministic, non-reproducible behaviour and
##   break the #13 determinism chain (RNG seeded on transition_id). They are FORBIDDEN
##   in enemy_director.gd EXCEPT inside the `class RNGFactory` body, which is the one
##   sanctioned place that wraps RandomNumberGenerator.
##
## Scan target:
##   res://src/autoload/enemy_director.gd  (this single file ONLY).
##
## Forbidden patterns (regex), outside RNGFactory class body only:
##   randf\(                       randi\(                  randf_range\(
##   Time\.get_ticks_msec\(        RandomNumberGenerator\.new\(
##
## Class-scope heuristic: `class RNGFactory:` line sets inside_rng_factory = true.
## Ends when a zero-indented non-blank non-comment line is encountered after entering
## the class (GDScript inner class ends at the next unindented declaration).
##
## Usage:
##   godot --headless --script tools/ci/check_enemy_director_randf.gd
##
## Exit codes:
##   0 = no violations (clean)
##   1 = one or more violations found (CI MUST fail)
##   2 = internal error (target file missing, regex compile failure, unreadable)
##
## Governing docs: design/gdd/enemy-director.md Rule 4 (RNGFactory); ADR-0005
##   (RNG seeded on transition_id); Story 002 AC-14, Story 006.
extends SceneTree


const TARGET_FILE: String = "res://src/autoload/enemy_director.gd"

## Forbidden direct-RNG patterns. Checked only OUTSIDE the RNGFactory class body.
const FORBIDDEN_PATTERNS: Array[String] = [
	"randf\\(",
	"randi\\(",
	"randf_range\\(",
	"Time\\.get_ticks_msec\\(",
	"RandomNumberGenerator\\.new\\(",
]

## Line that opens the sanctioned inner class. Allowed-zone start marker.
const RNG_FACTORY_START: String = "^\\s*class\\s+RNGFactory"


func _init() -> void:
	var abs_path: String = ProjectSettings.globalize_path(TARGET_FILE)
	if not FileAccess.file_exists(abs_path):
		push_error("[check_enemy_director_randf] target not found: %s" % TARGET_FILE)
		quit(2)
		return

	var re_scope_start := RegEx.new()
	if re_scope_start.compile(RNG_FACTORY_START) != OK:
		push_error("[check_enemy_director_randf] scope-start regex compile failed")
		quit(2)
		return

	var compiled: Array[RegEx] = []
	for pattern: String in FORBIDDEN_PATTERNS:
		var re := RegEx.new()
		if re.compile(pattern) != OK:
			push_error("[check_enemy_director_randf] regex compile failed: %s" % pattern)
			quit(2)
			return
		compiled.append(re)

	var lines: PackedStringArray = _read_lines(abs_path)
	if lines.is_empty():
		push_error("[check_enemy_director_randf] unreadable or empty: %s" % TARGET_FILE)
		quit(2)
		return

	var violations: Array[Dictionary] = []
	var inside_rng_factory: bool = false

	for i: int in lines.size():
		var line: String = lines[i]
		var stripped: String = line.strip_edges()

		# Comment / blank lines never open or close scope and never violate.
		if stripped.begins_with("#") or stripped == "":
			continue

		# Class body ends at the first zero-indented non-blank non-comment line
		# AFTER we entered the class.
		if inside_rng_factory and not line.begins_with("\t") and not line.begins_with(" "):
			inside_rng_factory = false

		# Entering the sanctioned RNGFactory class body — skip the declaration line itself.
		if re_scope_start.search(line) != null:
			inside_rng_factory = true
			continue

		if inside_rng_factory:
			continue  # Inside RNGFactory — direct RNG is allowed here.

		for j: int in compiled.size():
			var m := compiled[j].search(line)
			if m != null:
				violations.append({
					"line": i + 1,
					"col": m.get_start() + 1,
					"pattern": FORBIDDEN_PATTERNS[j],
					"snippet": stripped,
				})

	if violations.is_empty():
		print("[check_enemy_director_randf] PASS: %s — 0 direct-RNG violations outside RNGFactory" % TARGET_FILE)
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: direct RNG FORBIDDEN outside RNGFactory — use _rng_factory (pattern: %s)" % [
			TARGET_FILE, v["line"], v["col"], v["pattern"],
		])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[check_enemy_director_randf] FAIL: %d violation(s)." % violations.size())
	quit(1)


func _read_lines(abs_path: String) -> PackedStringArray:
	var file := FileAccess.open(abs_path, FileAccess.READ)
	if file == null:
		return PackedStringArray()
	var lines: PackedStringArray = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	return lines

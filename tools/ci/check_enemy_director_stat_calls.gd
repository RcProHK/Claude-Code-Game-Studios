#!/usr/bin/env -S godot --headless --script
## CI Lint — EnemyDirector stat-read locality enforcement (GDD Rule 8, Story 002).
##
## Purpose:
##   `StatSystem.get_stat()` reads MUST be confined to `_build_stat_snapshot()` so the
##   combat pipeline operates on one consistent, atomically-captured stat snapshot per
##   resolve cycle. Scattered StatSystem.get_stat() calls re-read mutable global state
##   mid-pipeline and are FORBIDDEN. (Story 008 implements _build_stat_snapshot(); until
##   then the clean file has zero StatSystem.get_stat() calls and this check passes.)
##
## Scan target:
##   res://src/autoload/enemy_director.gd  (this single file ONLY).
##
## Forbidden pattern (regex), outside _build_stat_snapshot method body only:
##   StatSystem\.get_stat\(
##
## Class-scope heuristic: `func _build_stat_snapshot` line sets inside_snapshot = true.
## Ends when a zero-indented non-blank non-comment line is encountered after entering
## the method (GDScript function ends at the next unindented declaration).
##
## Usage:
##   godot --headless --script tools/ci/check_enemy_director_stat_calls.gd
##
## Exit codes:
##   0 = no violations (clean)
##   1 = one or more violations found (CI MUST fail)
##   2 = internal error (target file missing, regex compile failure, unreadable)
##
## Governing docs: design/gdd/enemy-director.md Rule 8 (stat snapshot locality);
##   Story 002 (story-level AC), Story 008 (_build_stat_snapshot implementation).
extends SceneTree


const TARGET_FILE: String = "res://src/autoload/enemy_director.gd"

## Forbidden stat-read pattern. Checked only OUTSIDE _build_stat_snapshot body.
const FORBIDDEN_PATTERN: String = "StatSystem\\.get_stat\\("

## Line that opens the sanctioned method. Allowed-zone start marker.
const SNAPSHOT_START: String = "^\\s*func\\s+_build_stat_snapshot"


func _init() -> void:
	var abs_path: String = ProjectSettings.globalize_path(TARGET_FILE)
	if not FileAccess.file_exists(abs_path):
		push_error("[check_enemy_director_stat_calls] target not found: %s" % TARGET_FILE)
		quit(2)
		return

	var re_forbidden := RegEx.new()
	if re_forbidden.compile(FORBIDDEN_PATTERN) != OK:
		push_error("[check_enemy_director_stat_calls] forbidden regex compile failed")
		quit(2)
		return

	var re_scope_start := RegEx.new()
	if re_scope_start.compile(SNAPSHOT_START) != OK:
		push_error("[check_enemy_director_stat_calls] scope-start regex compile failed")
		quit(2)
		return

	var lines: PackedStringArray = _read_lines(abs_path)
	if lines.is_empty():
		push_error("[check_enemy_director_stat_calls] unreadable or empty: %s" % TARGET_FILE)
		quit(2)
		return

	var violations: Array[Dictionary] = []
	var inside_snapshot: bool = false

	for i: int in lines.size():
		var line: String = lines[i]
		var stripped: String = line.strip_edges()

		if stripped.begins_with("#") or stripped == "":
			continue

		# Method body ends at the first zero-indented non-blank non-comment line
		# AFTER we entered the method.
		if inside_snapshot and not line.begins_with("\t") and not line.begins_with(" "):
			inside_snapshot = false

		# Entering the sanctioned method body — skip the declaration line itself.
		if re_scope_start.search(line) != null:
			inside_snapshot = true
			continue

		if inside_snapshot:
			continue  # Inside _build_stat_snapshot — StatSystem.get_stat() is allowed.

		var m := re_forbidden.search(line)
		if m != null:
			violations.append({
				"line": i + 1,
				"col": m.get_start() + 1,
				"snippet": stripped,
			})

	if violations.is_empty():
		print("[check_enemy_director_stat_calls] PASS: %s — 0 StatSystem.get_stat() calls outside _build_stat_snapshot" % TARGET_FILE)
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: StatSystem.get_stat() FORBIDDEN outside _build_stat_snapshot (Rule 8)" % [
			TARGET_FILE, v["line"], v["col"],
		])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[check_enemy_director_stat_calls] FAIL: %d violation(s)." % violations.size())
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

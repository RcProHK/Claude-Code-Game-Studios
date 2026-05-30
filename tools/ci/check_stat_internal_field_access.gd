#!/usr/bin/env -S godot --headless --script
## CI Lint — StatSystem internal field access enforcement (GDD Rule 2, ADR-0006 Contract 12)
##
## AC-02: Only `src/autoload/stat_system.gd` may reference
##   `StatSystem._base[` or `StatSystem._equipment_modifiers[`.
##   External reads or writes to these private fields bypass the closed-mutation API
##   (GDD Rule 2) and void the Pillar 1 (Real Body, Real Power) anti-fabrication chain.
##
## Usage:
##   godot --headless --script tools/ci/check_stat_internal_field_access.gd
##
## Exit codes:
##   0 = no violations (clean)
##   1 = one or more violations found (CI MUST fail)
##   2 = internal error (src/ missing, regex compile failure, unreadable file)
##
## Governing docs: design/gdd/stat-system.md Rule 2; ADR-0006 Contract 12; TR-stat-002.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const FILE_EXTENSION: String = "gd"
## Owner file is permitted to access its own internal fields.
const OWNER_FILE: String = "res://src/autoload/stat_system.gd"


func _init() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCAN_ROOT)):
		push_error("[check_stat_internal_field_access] src/ not found at %s — cannot scan" % SCAN_ROOT)
		quit(2)
		return

	# Two forbidden external-access patterns.
	var pattern_strings: PackedStringArray = [
		"StatSystem\\._base\\[",
		"StatSystem\\._equipment_modifiers\\[",
	]
	var regexes: Array[RegEx] = []
	for ps: String in pattern_strings:
		var re := RegEx.new()
		if re.compile(ps) != OK:
			push_error("[check_stat_internal_field_access] regex compile failed: %s" % ps)
			quit(2)
			return
		regexes.append(re)

	var scan_files: Array[String] = []
	_collect_gd_files(SCAN_ROOT, scan_files)

	var violations: Array[Dictionary] = []
	for file_path: String in scan_files:
		if file_path == OWNER_FILE:
			continue  # stat_system.gd owns these fields — self-access is permitted
		violations.append_array(_scan_file(file_path, regexes))

	if violations.is_empty():
		print("[check_stat_internal_field_access] PASS: scanned %d file(s), 0 violations" % scan_files.size())
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: StatSystem._base[] / ._equipment_modifiers[] access FORBIDDEN outside stat_system.gd (GDD Rule 2, ADR-0006 C12)" % [
			v["file"], v["line"], v["col"],
		])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[check_stat_internal_field_access] FAIL: %d violation(s). Only src/autoload/stat_system.gd may access these private fields." % violations.size())
	quit(1)


func _collect_gd_files(dir_path: String, accumulator: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("[check_stat_internal_field_access] cannot open directory: %s" % dir_path)
		return
	for file_name: String in dir.get_files():
		if file_name.get_extension() == FILE_EXTENSION:
			accumulator.append(dir_path.path_join(file_name))
	for subdir_name: String in dir.get_directories():
		_collect_gd_files(dir_path.path_join(subdir_name), accumulator)


func _scan_file(file_path: String, regexes: Array[RegEx]) -> Array[Dictionary]:
	var violations: Array[Dictionary] = []
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[check_stat_internal_field_access] cannot read: %s" % file_path)
		return violations
	var lines: PackedStringArray = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	for i: int in lines.size():
		var line: String = lines[i]
		if _is_comment_line(line):
			continue
		for re: RegEx in regexes:
			var m := re.search(line)
			if m != null:
				violations.append({
					"file": file_path,
					"line": i + 1,
					"col": m.get_start() + 1,
					"snippet": line.strip_edges(),
				})
				break  # one violation report per line is sufficient
	return violations


## A line is a comment if its first non-whitespace character is `#`.
func _is_comment_line(line: String) -> bool:
	return line.strip_edges(true, false).begins_with("#")

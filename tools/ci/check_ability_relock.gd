#!/usr/bin/env -S godot --headless --script
## CI Lint — _unlocked_abilities relock detection (GDD Rule 12 — permanent unlock)
##
## AC-relock: Abilities, once unlocked, are PERMANENT. No code path may `.erase()` or
##   `.clear()` the `_unlocked_abilities` table — doing so would silently relock an
##   earned ability, violating the permanent-unlock contract (Rule 12). Only the owner
##   file is exempt (and even there, schema migration is the only legitimate clear path,
##   reviewed manually). Any erase/clear in another src/ file is a CI failure.
##
## Usage:
##   godot --headless --script tools/ci/check_ability_relock.gd
##
## Exit codes:
##   0 = no violations (clean)
##   1 = one or more violations found (CI MUST fail)
##   2 = internal error (src/ missing, regex compile failure, unreadable file)
##
## Governing docs: design/gdd/ability-system.md Rule 12; ADR-0006 Contract 12; TR-ability-003.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const FILE_EXTENSION: String = "gd"
## Owner file is permitted to access its own field (schema migration paths only).
const OWNER_FILE: String = "res://src/autoload/ability_system.gd"

## Matches `_unlocked_abilities.erase(` or `_unlocked_abilities.clear(` with optional
## whitespace before the paren.
const FORBIDDEN_PATTERN: String = "_unlocked_abilities\\.(erase|clear)\\s*\\("


func _init() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCAN_ROOT)):
		push_error("[check_ability_relock] src/ not found at %s — cannot scan" % SCAN_ROOT)
		quit(2)
		return

	var re := RegEx.new()
	if re.compile(FORBIDDEN_PATTERN) != OK:
		push_error("[check_ability_relock] regex compile failed: %s" % FORBIDDEN_PATTERN)
		quit(2)
		return

	var scan_files: Array[String] = []
	_collect_gd_files(SCAN_ROOT, scan_files)

	var violations: Array[Dictionary] = []
	for file_path: String in scan_files:
		if file_path == OWNER_FILE:
			continue  # owner exempt — schema migration is the only legitimate clear path.
		violations.append_array(_scan_file(file_path, re))

	if violations.is_empty():
		print("[check_ability_relock] PASS: scanned %d file(s), 0 relock (erase/clear) violations" % scan_files.size())
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: _unlocked_abilities.erase()/.clear() FORBIDDEN — abilities are permanent (GDD Rule 12)" % [
			v["file"], v["line"], v["col"],
		])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[check_ability_relock] FAIL: %d relock violation(s). Unlocked abilities are permanent (Rule 12)." % violations.size())
	quit(1)


func _collect_gd_files(dir_path: String, accumulator: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("[check_ability_relock] cannot open directory: %s" % dir_path)
		return
	for file_name: String in dir.get_files():
		if file_name.get_extension() == FILE_EXTENSION:
			accumulator.append(dir_path.path_join(file_name))
	for subdir_name: String in dir.get_directories():
		_collect_gd_files(dir_path.path_join(subdir_name), accumulator)


func _scan_file(file_path: String, re: RegEx) -> Array[Dictionary]:
	var violations: Array[Dictionary] = []
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[check_ability_relock] cannot read: %s" % file_path)
		return violations
	var lines: PackedStringArray = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	for i: int in lines.size():
		var line: String = lines[i]
		if _is_comment_line(line):
			continue
		var m := re.search(line)
		if m != null:
			violations.append({
				"file": file_path,
				"line": i + 1,
				"col": m.get_start() + 1,
				"snippet": line.strip_edges(),
			})
	return violations


## A line is a comment if its first non-whitespace character is `#`.
func _is_comment_line(line: String) -> bool:
	return line.strip_edges(true, false).begins_with("#")

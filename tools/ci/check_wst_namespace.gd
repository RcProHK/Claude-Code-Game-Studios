#!/usr/bin/env -S godot --headless --script
## CI Lint — WorkoutStateTracker wst.* namespace exclusivity (GDD Rule 14, Story 009)
##
## AC-06(b): Only `src/autoload/workout_state_tracker.gd` may call
##   `PersistenceLayer.write("wst...."`. All wst.* keys are exclusively owned by #9;
##   any other writer would silently corrupt the bfcache snapshot schema.
##
## Usage:
##   godot --headless --script tools/ci/check_wst_namespace.gd
##
## Exit codes:
##   0 = no violations (clean)
##   1 = one or more violations found (CI MUST fail)
##   2 = internal error
##
## Governing docs: design/gdd/workout-state-tracker.md Rule 7/14; TR-wst-006.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const FILE_EXTENSION: String = "gd"
const OWNER_FILE: String = "res://src/autoload/workout_state_tracker.gd"
const ALLOW_COMMENT: String = "# ci:allow-wst-mutation"


func _init() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCAN_ROOT)):
		push_error("[check_wst_namespace] src/ not found — cannot scan")
		quit(2)
		return

	var re := RegEx.new()
	if re.compile("PersistenceLayer\\.write\\([\"']wst\\.") != OK:
		push_error("[check_wst_namespace] regex compile failed")
		quit(2)
		return

	var scan_files: Array[String] = []
	_collect_gd_files(SCAN_ROOT, scan_files)

	var violations: Array[Dictionary] = []
	for file_path: String in scan_files:
		if file_path == OWNER_FILE:
			continue
		violations.append_array(_scan_file(file_path, re))

	if violations.is_empty():
		print("[check_wst_namespace] PASS: scanned %d file(s), 0 violations" % scan_files.size())
		quit(0)
		return

	for v: Dictionary in violations:
		printerr('%s:%d:%d: PersistenceLayer.write("wst.*") FORBIDDEN outside workout_state_tracker.gd (GDD Rule 14)' % [
			v["file"], v["line"], v["col"],
		])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[check_wst_namespace] FAIL: %d violation(s). Only #9 owns wst.* keys." % violations.size())
	quit(1)


func _collect_gd_files(dir_path: String, accumulator: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
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
		return violations
	var lines: PackedStringArray = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()

	for line: String in lines:
		if line.contains(ALLOW_COMMENT):
			return violations  # Whitelisted file

	for i: int in lines.size():
		var line: String = lines[i]
		if _is_comment_line(line):
			continue
		var m := re.search(line)
		if m != null:
			violations.append({
				"file": file_path, "line": i + 1,
				"col": m.get_start() + 1, "snippet": line.strip_edges(),
			})
	return violations


func _is_comment_line(line: String) -> bool:
	return line.strip_edges(true, false).begins_with("#")

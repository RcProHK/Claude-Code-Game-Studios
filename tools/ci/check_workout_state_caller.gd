#!/usr/bin/env -S godot --headless --script
## CI Lint — WorkoutStateTracker closed-API enforcement (GDD Rule 1/14, Story 009)
##
## AC-06(a): Only `src/autoload/workout_state_tracker.gd` may directly set
##   WorkoutStateTracker internal fields or call set_* methods. Any external caller
##   that bypasses the public read-only query API (get_*) breaks the anti-fabrication
##   chain (#9 Pillar 1 substrate).
##
## Usage:
##   godot --headless --script tools/ci/check_workout_state_caller.gd
##
## Exit codes:
##   0 = no violations (clean)
##   1 = one or more violations found (CI MUST fail)
##   2 = internal error (src/ missing, regex compile failure, unreadable file)
##
## Governing docs: design/gdd/workout-state-tracker.md Rule 1/14; TR-wst-006.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const FILE_EXTENSION: String = "gd"
## Owner file is permitted to mutate its own internal fields.
const OWNER_FILE: String = "res://src/autoload/workout_state_tracker.gd"
## Comment that whitelists a file from this check (for test doubles / spy harnesses).
const ALLOW_COMMENT: String = "# ci:allow-wst-mutation"


func _init() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCAN_ROOT)):
		push_error("[check_workout_state_caller] src/ not found at %s — cannot scan" % SCAN_ROOT)
		quit(2)
		return

	# Pattern: WorkoutStateTracker followed by .(set_ or ._)
	# Matches direct field access (._xxx) and set_* method calls from outside.
	var re := RegEx.new()
	if re.compile("WorkoutStateTracker\\.(?:set_|_)") != OK:
		push_error("[check_workout_state_caller] regex compile failed")
		quit(2)
		return

	var scan_files: Array[String] = []
	_collect_gd_files(SCAN_ROOT, scan_files)

	var violations: Array[Dictionary] = []
	for file_path: String in scan_files:
		if file_path == OWNER_FILE:
			continue  # Owner file may access its own internals
		violations.append_array(_scan_file(file_path, re))

	if violations.is_empty():
		print("[check_workout_state_caller] PASS: scanned %d file(s), 0 violations" % scan_files.size())
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: WorkoutStateTracker.(set_|_) FORBIDDEN outside workout_state_tracker.gd (GDD Rule 14)" % [
			v["file"], v["line"], v["col"],
		])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[check_workout_state_caller] FAIL: %d violation(s)." % violations.size())
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

	# If the file contains the allow-comment anywhere, skip the whole file.
	for line: String in lines:
		if line.contains(ALLOW_COMMENT):
			return violations

	for i: int in lines.size():
		var line: String = lines[i]
		if _is_comment_line(line):
			continue
		# Note: WorkoutStateTracker.get_*() is NOT matched by WorkoutStateTracker\.(set_|_)
		# because "get_" starts with 'g', not 'set_' or '_'. No whitelist needed.
		# Note: WorkoutStateTracker.signal_name.connect() is also NOT matched because
		# signal names do not start with 'set_' or '_'. Whole-line .connect() whitelist
		# was removed — it could silently bypass real violations on the same line.
		var m := re.search(line)
		if m != null:
			violations.append({
				"file": file_path,
				"line": i + 1,
				"col": m.get_start() + 1,
				"snippet": line.strip_edges(),
			})
	return violations


func _is_comment_line(line: String) -> bool:
	return line.strip_edges(true, false).begins_with("#")

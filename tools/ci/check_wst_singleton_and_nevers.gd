#!/usr/bin/env -S godot --headless --script
## CI Lint — WorkoutStateTracker singleton + Rule 16 NEVERs (GDD Rule 15/16, Story 009)
##
## AC-17: Three checks in one script:
##   (a) No `preload(...workout_state_tracker...).new()` instantiation — must use autoload.
##   (b) No `_workout_phase =` / `_dominant_class =` outside the owner autoload file.
##   (c) No `Stat.get_` calls INSIDE `src/autoload/workout_state_tracker.gd`
##       (Rule 16 NEVER #6: #9 is a strictly one-way Stat caller).
##
## Usage:
##   godot --headless --script tools/ci/check_wst_singleton_and_nevers.gd
##
## Exit codes:
##   0 = no violations (clean)
##   1 = one or more violations found (CI MUST fail)
##   2 = internal error
##
## Governing docs: design/gdd/workout-state-tracker.md Rule 15/16; TR-wst-006.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const FILE_EXTENSION: String = "gd"
const OWNER_FILE: String = "res://src/autoload/workout_state_tracker.gd"
const ALLOW_COMMENT: String = "# ci:allow-wst-mutation"


func _init() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCAN_ROOT)):
		push_error("[check_wst_singleton_and_nevers] src/ not found — cannot scan")
		quit(2)
		return

	# Check (a): preload-new instantiation (any file)
	var re_preload := RegEx.new()
	if re_preload.compile("preload\\(.*workout_state_tracker.*\\)\\.new\\(\\)") != OK:
		push_error("[check_wst_singleton_and_nevers] preload regex compile failed")
		quit(2)
		return

	# Check (b): internal field mutation outside owner — MEMBER-ACCESS form only.
	# Require a leading `.` so we match `WorkoutStateTracker._workout_phase = x` (a real
	# closed-API bypass) but NOT a bare `_workout_phase = v` self-assignment inside an
	# unrelated class that happens to declare a same-named backing var (e.g. the
	# WorkoutSnapshotRO / WorkoutSummaryRO inline setters). A bare `_field =` can only
	# ever be self-scoped, so it is never a Rule 16 cross-object violation.
	var re_phase := RegEx.new()
	var re_class := RegEx.new()
	if re_phase.compile("\\._workout_phase\\s*=") != OK or re_class.compile("\\._dominant_class\\s*=") != OK:
		push_error("[check_wst_singleton_and_nevers] field mutation regex compile failed")
		quit(2)
		return

	# Check (c): Stat.get_* INSIDE owner file (Rule 16 NEVER #6)
	var re_stat_get := RegEx.new()
	if re_stat_get.compile("Stat\\.get_") != OK:
		push_error("[check_wst_singleton_and_nevers] Stat.get_ regex compile failed")
		quit(2)
		return

	var scan_files: Array[String] = []
	_collect_gd_files(SCAN_ROOT, scan_files)

	var violations: Array[Dictionary] = []

	for file_path: String in scan_files:
		if _is_whitelisted(file_path):
			continue
		if file_path != OWNER_FILE:
			# (a) preload-new: any file except owner
			violations.append_array(_scan_file(file_path, re_preload,
				"preload(...workout_state_tracker...).new() FORBIDDEN — use WorkoutStateTracker autoload"))
			# (b) field mutation: outside owner
			violations.append_array(_scan_file(file_path, re_phase,
				"_workout_phase = FORBIDDEN outside workout_state_tracker.gd (Rule 16)"))
			violations.append_array(_scan_file(file_path, re_class,
				"_dominant_class = FORBIDDEN outside workout_state_tracker.gd (Rule 16)"))
		else:
			# (c) Stat.get_ is forbidden INSIDE owner file
			violations.append_array(_scan_file(file_path, re_stat_get,
				"Stat.get_* FORBIDDEN inside workout_state_tracker.gd (Rule 16 NEVER #6)"))

	if violations.is_empty():
		print("[check_wst_singleton_and_nevers] PASS: scanned %d file(s), 0 violations" % scan_files.size())
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: %s" % [v["file"], v["line"], v["col"], v["msg"]])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[check_wst_singleton_and_nevers] FAIL: %d violation(s)." % violations.size())
	quit(1)


func _is_whitelisted(file_path: String) -> bool:
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return false
	while not file.eof_reached():
		if file.get_line().contains(ALLOW_COMMENT):
			file.close()
			return true
	file.close()
	return false


func _collect_gd_files(dir_path: String, accumulator: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		if file_name.get_extension() == FILE_EXTENSION:
			accumulator.append(dir_path.path_join(file_name))
	for subdir_name: String in dir.get_directories():
		_collect_gd_files(dir_path.path_join(subdir_name), accumulator)


func _scan_file(file_path: String, re: RegEx, msg: String) -> Array[Dictionary]:
	var violations: Array[Dictionary] = []
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
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
				"file": file_path, "line": i + 1,
				"col": m.get_start() + 1,
				"snippet": line.strip_edges(), "msg": msg,
			})
	return violations


func _is_comment_line(line: String) -> bool:
	return line.strip_edges(true, false).begins_with("#")

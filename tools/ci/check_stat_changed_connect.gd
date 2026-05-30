#!/usr/bin/env -S godot --headless --script
## CI Lint — stat_changed plain .connect() detection (ADR-0006 Contract 6)
##
## AC-34: Subscribers to the stat_changed signal MUST use
##   `stat_system.connect_for_initial_state(callable)` instead of plain `.connect()`.
##   Plain `.connect()` in `_ready()` misses the initial-state delivery because the
##   signal may have already fired before the subscriber registered — Contract 6 of
##   ADR-0006 defines `connect_for_initial_state` as the mandatory subscription path.
##
## Forbidden patterns (on non-comment lines outside stat_system.gd):
##   stat_changed.connect(…)           — direct signal-object connect
##   .connect("stat_changed", …)        — legacy string-based connect (Godot 3 style)
##   connect("stat_changed", …)         — implied-self string-based connect
##
## Correct pattern:
##   stat_system.connect_for_initial_state(_on_stat_changed)
##
## Usage:
##   godot --headless --script tools/ci/check_stat_changed_connect.gd
##
## Exit codes:
##   0 = no violations (clean)
##   1 = one or more violations found (CI MUST fail)
##   2 = internal error (src/ missing, regex compile failure, unreadable file)
##
## Governing docs: ADR-0006 Contract 6; design/gdd/stat-system.md; TR-stat-002.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const FILE_EXTENSION: String = "gd"
## stat_system.gd owns the signal — internal connects are permitted.
const OWNER_FILE: String = "res://src/autoload/stat_system.gd"

## Combined pattern covering both:
##   1. stat_changed.connect(        — direct signal-object connect (Godot 4 style)
##   2. connect("stat_changed"       — string-based connect (legacy Godot 3 style;
##                                     still valid in Godot 4; catches both
##                                     `.connect("stat_changed"` and
##                                     `connect("stat_changed"` with implied self)
const FORBIDDEN_PATTERN: String = "(stat_changed\\.connect\\(|connect\\(\\s*\"stat_changed\")"


func _init() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCAN_ROOT)):
		push_error("[check_stat_changed_connect] src/ not found at %s — cannot scan" % SCAN_ROOT)
		quit(2)
		return

	var re := RegEx.new()
	if re.compile(FORBIDDEN_PATTERN) != OK:
		push_error("[check_stat_changed_connect] regex compile failed: %s" % FORBIDDEN_PATTERN)
		quit(2)
		return

	var scan_files: Array[String] = []
	_collect_gd_files(SCAN_ROOT, scan_files)

	var violations: Array[Dictionary] = []
	for file_path: String in scan_files:
		if file_path == OWNER_FILE:
			continue  # signal owner is permitted to connect its own signal internally
		violations.append_array(_scan_file(file_path, re))

	if violations.is_empty():
		print("[check_stat_changed_connect] PASS: scanned %d file(s), 0 plain-connect violations" % scan_files.size())
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: Plain .connect() on stat_changed FORBIDDEN — use connect_for_initial_state(callable) (ADR-0006 Contract 6)" % [
			v["file"], v["line"], v["col"],
		])
		printerr("  > %s" % v["snippet"])
		printerr("  FIX: stat_system.connect_for_initial_state(_on_stat_changed)")
	printerr("")
	printerr("[check_stat_changed_connect] FAIL: %d violation(s). See ADR-0006 Contract 6 for the correct subscription pattern." % violations.size())
	quit(1)


func _collect_gd_files(dir_path: String, accumulator: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("[check_stat_changed_connect] cannot open directory: %s" % dir_path)
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
		push_error("[check_stat_changed_connect] cannot read: %s" % file_path)
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

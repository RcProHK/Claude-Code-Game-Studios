#!/usr/bin/env -S godot --headless --script
## CI Lint — StatSystem.apply_stat_delta() caller whitelist (GDD Rule 4, ADR-0006 Contract 12)
##
## AC-03: Only the four whitelisted files may call StatSystem.apply_stat_delta().
##   Any other src/ caller bypasses the closed-API contract and risks fabricating
##   stat gains outside the real-workout signal chain (Pillar 1 violation).
##
## Whitelist:
##   src/autoload/stat_system.gd           (self — internal mutations)
##   src/core/workout_state_tracker.gd      (VOLUME_TICK + set_completed consumer)
##   src/feature/pr_detection.gd           (PR_BREAKTHROUGH consumer)
##   src/feature/equipment_inventory.gd     (equipment modifier layer consumer)
##
## Usage:
##   godot --headless --script tools/ci/check_stat_mutation_callers.gd
##
## Exit codes:
##   0 = no violations (clean)
##   1 = one or more unauthorized callers found (CI MUST fail)
##   2 = internal error (src/ missing, regex compile failure, unreadable file)
##
## Governing docs: design/gdd/stat-system.md Rule 4; ADR-0006 Contract 12; TR-stat-002; ADR-0007.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const FILE_EXTENSION: String = "gd"
const FORBIDDEN_PATTERN: String = "StatSystem\\.apply_stat_delta\\("

## Full res:// paths so a file with the same basename in a different directory
## cannot accidentally slip through the whitelist check.
const WHITELISTED_FILES := [
	"res://src/autoload/stat_system.gd",
	"res://src/core/workout_state_tracker.gd",
	"res://src/feature/pr_detection.gd",
	"res://src/feature/equipment_inventory.gd",
]


func _init() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCAN_ROOT)):
		push_error("[check_stat_mutation_callers] src/ not found at %s — cannot scan" % SCAN_ROOT)
		quit(2)
		return

	var re := RegEx.new()
	if re.compile(FORBIDDEN_PATTERN) != OK:
		push_error("[check_stat_mutation_callers] regex compile failed: %s" % FORBIDDEN_PATTERN)
		quit(2)
		return

	var scan_files: Array[String] = []
	_collect_gd_files(SCAN_ROOT, scan_files)

	var violations: Array[Dictionary] = []
	for file_path: String in scan_files:
		if WHITELISTED_FILES.has(file_path):
			continue
		violations.append_array(_scan_file(file_path, re))

	if violations.is_empty():
		print("[check_stat_mutation_callers] PASS: scanned %d file(s), 0 unauthorized apply_stat_delta() callers" % scan_files.size())
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: Unauthorized StatSystem.apply_stat_delta() call (GDD Rule 4, ADR-0006 C12)" % [
			v["file"], v["line"], v["col"],
		])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[check_stat_mutation_callers] FAIL: %d unauthorized caller(s)." % violations.size())
	printerr("  Whitelist: stat_system.gd | workout_state_tracker.gd | pr_detection.gd | equipment_inventory.gd")
	quit(1)


func _collect_gd_files(dir_path: String, accumulator: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("[check_stat_mutation_callers] cannot open directory: %s" % dir_path)
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
		push_error("[check_stat_mutation_callers] cannot read: %s" % file_path)
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

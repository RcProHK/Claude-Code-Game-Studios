#!/usr/bin/env -S godot --headless --script
## CI Lint — AbilitySystem.unlock_ability() caller whitelist (GDD Rule 6, ADR-0006 Contract 12)
##
## AC-08: `unlock_ability` is an internal chokepoint. External systems (e.g. PR
##   Detection) MUST emit a signal that the internal handler subscribes to — they
##   must NEVER call `AbilitySystem.unlock_ability(...)` directly. Only the owner
##   file itself (the internal handler lives there) may invoke it. A direct external
##   call would bypass the caller-whitelist runtime guard + source/class allow-list.
##
## Whitelist:
##   src/autoload/ability_system.gd   (self — internal handler only)
##
## Usage:
##   godot --headless --script tools/ci/check_ability_unlock_callers.gd
##
## Exit codes:
##   0 = no violations (clean)
##   1 = one or more unauthorized callers found (CI MUST fail)
##   2 = internal error (src/ missing, regex compile failure, unreadable file)
##
## Governing docs: design/gdd/ability-system.md Rule 6; ADR-0006 Contract 12; TR-ability-007.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const FILE_EXTENSION: String = "gd"
## Matches `AbilitySystem.unlock_ability(` with optional whitespace before the paren.
const FORBIDDEN_PATTERN: String = "AbilitySystem\\.unlock_ability\\s*\\("

## Full res:// paths so a same-basename file in a different directory cannot slip through.
const WHITELISTED_FILES := [
	"res://src/autoload/ability_system.gd",
]


func _init() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCAN_ROOT)):
		push_error("[check_ability_unlock_callers] src/ not found at %s — cannot scan" % SCAN_ROOT)
		quit(2)
		return

	var re := RegEx.new()
	if re.compile(FORBIDDEN_PATTERN) != OK:
		push_error("[check_ability_unlock_callers] regex compile failed: %s" % FORBIDDEN_PATTERN)
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
		print("[check_ability_unlock_callers] PASS: scanned %d file(s), 0 unauthorized unlock_ability() callers" % scan_files.size())
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: Unauthorized AbilitySystem.unlock_ability() call — emit a signal instead (GDD Rule 6, ADR-0006 C12)" % [
			v["file"], v["line"], v["col"],
		])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[check_ability_unlock_callers] FAIL: %d unauthorized caller(s). Only ability_system.gd internal handler may call unlock_ability()." % violations.size())
	quit(1)


func _collect_gd_files(dir_path: String, accumulator: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("[check_ability_unlock_callers] cannot open directory: %s" % dir_path)
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
		push_error("[check_ability_unlock_callers] cannot read: %s" % file_path)
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

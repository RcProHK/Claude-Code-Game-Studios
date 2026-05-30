#!/usr/bin/env -S godot --headless --script
## CI Lint — AbilitySystem.cast_ability() caller whitelist (GDD Rule 6, ADR-0006 Contract 12)
##
## AC-09: `cast_ability` is the combat chokepoint. Only `src/core/combat_resolver.gd`
##   resolves a cast (it owns the deterministic combat math + GSM gate). HUD, input,
##   AI, and every other system must route a cast intent through the combat resolver —
##   never call `AbilitySystem.cast_ability(...)` directly. A direct external call
##   bypasses combat resolution ordering and the cast precondition checks.
##
## Whitelist:
##   src/core/combat_resolver.gd   (the sole authorised cast caller)
##
## Usage:
##   godot --headless --script tools/ci/check_ability_cast_callers.gd
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
## Matches `AbilitySystem.cast_ability(` with optional whitespace before the paren.
const FORBIDDEN_PATTERN: String = "AbilitySystem\\.cast_ability\\s*\\("

## Full res:// paths so a same-basename file in a different directory cannot slip through.
const WHITELISTED_FILES := [
	"res://src/core/combat_resolver.gd",
]


func _init() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCAN_ROOT)):
		push_error("[check_ability_cast_callers] src/ not found at %s — cannot scan" % SCAN_ROOT)
		quit(2)
		return

	var re := RegEx.new()
	if re.compile(FORBIDDEN_PATTERN) != OK:
		push_error("[check_ability_cast_callers] regex compile failed: %s" % FORBIDDEN_PATTERN)
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
		print("[check_ability_cast_callers] PASS: scanned %d file(s), 0 unauthorized cast_ability() callers" % scan_files.size())
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: Unauthorized AbilitySystem.cast_ability() call — route through combat_resolver.gd (GDD Rule 6, ADR-0006 C12)" % [
			v["file"], v["line"], v["col"],
		])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[check_ability_cast_callers] FAIL: %d unauthorized caller(s). Only src/core/combat_resolver.gd may call cast_ability()." % violations.size())
	quit(1)


func _collect_gd_files(dir_path: String, accumulator: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("[check_ability_cast_callers] cannot open directory: %s" % dir_path)
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
		push_error("[check_ability_cast_callers] cannot read: %s" % file_path)
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

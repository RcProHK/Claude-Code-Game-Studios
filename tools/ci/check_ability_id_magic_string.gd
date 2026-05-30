#!/usr/bin/env -S godot --headless --script
## CI Lint — AbilityId magic-string detection (GDD Rule 1, ADR-0006 Contract 12)
##
## AC-02: Ability IDs are a LOCKED surface exposed only via `AbilitySystem.AbilityId`
##   StringName constants. A raw string literal matching the canonical id shape
##   `(strike|control|mobility)_tier_[1-3]_[a-z_]+` anywhere in `src/` (outside the
##   owner file) is a magic string — it bypasses the locked surface and drifts the
##   moment an id is renamed. Use `AbilityId.STRIKE_TIER_1_JAB` etc. instead.
##
## Usage:
##   godot --headless --script tools/ci/check_ability_id_magic_string.gd
##
## Exit codes:
##   0 = no violations (clean)
##   1 = one or more magic-string literals found (CI MUST fail)
##   2 = internal error (src/ missing, regex compile failure, unreadable file)
##
## Governing docs: design/gdd/ability-system.md Rule 1; ADR-0006 Contract 12; TR-ability-003.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const FILE_EXTENSION: String = "gd"
## Owner file declares the canonical AbilityId StringName constants — the lowercase
## literals live here legitimately.
const OWNER_FILE: String = "res://src/autoload/ability_system.gd"

## Canonical ability-id shape. Matches `strike_tier_1_jab`, `control_tier_3_grapple`,
## `mobility_tier_2_leap`, etc. The trailing `[a-z_]+` covers the variable suffix.
const FORBIDDEN_PATTERN: String = "(strike|control|mobility)_tier_[1-3]_[a-z_]+"


func _init() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCAN_ROOT)):
		push_error("[check_ability_id_magic_string] src/ not found at %s — cannot scan" % SCAN_ROOT)
		quit(2)
		return

	var re := RegEx.new()
	if re.compile(FORBIDDEN_PATTERN) != OK:
		push_error("[check_ability_id_magic_string] regex compile failed: %s" % FORBIDDEN_PATTERN)
		quit(2)
		return

	var scan_files: Array[String] = []
	_collect_gd_files(SCAN_ROOT, scan_files)

	var violations: Array[Dictionary] = []
	for file_path: String in scan_files:
		if file_path == OWNER_FILE:
			continue  # ability_system.gd declares the canonical lowercase literals.
		violations.append_array(_scan_file(file_path, re))

	if violations.is_empty():
		print("[check_ability_id_magic_string] PASS: scanned %d file(s), 0 magic-string ability ids" % scan_files.size())
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: Magic ability-id string FORBIDDEN — use AbilitySystem.AbilityId.* (GDD Rule 1, ADR-0006 C12)" % [
			v["file"], v["line"], v["col"],
		])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[check_ability_id_magic_string] FAIL: %d magic-string ability id(s). Use the AbilityId constant surface." % violations.size())
	quit(1)


func _collect_gd_files(dir_path: String, accumulator: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("[check_ability_id_magic_string] cannot open directory: %s" % dir_path)
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
		push_error("[check_ability_id_magic_string] cannot read: %s" % file_path)
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

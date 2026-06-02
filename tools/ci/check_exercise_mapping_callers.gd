#!/usr/bin/env -S godot --headless --script
## CI Lint — ExerciseClassMapping read-only closed-API enforcement (ADR-0007; #10 Story 005 AC).
##
## Purpose:
##   ExerciseClassMapping is a CLOSED, read-only lookup service (GDD Rule 2 / ADR-0007 no-
##   fabrication posture). External code may ONLY call its read API
##   (get_class_for_exercise / get_class_for_movement_pattern / is_known_exercise). It must
##   NEVER mutate the singleton's state or reach into its private members — doing so would let
##   a caller corrupt the canonical class taxonomy at runtime. This lint scans all of src/ and
##   fails on any external write to, or private-member access on, the ExerciseClassMapping
##   singleton. Mirrors check_screen_effects_callers.gd / check_streak_callers.gd.
##
## Scan target:
##   res://src/   (recursive — every .gd file).
##
## Whitelist (may touch ExerciseClassMapping internals):
##   res://src/autoload/exercise_class_mapping.gd   — owner (defines the state + test factory)
##
## Forbidden pattern (regex), on non-comment lines outside the owner file:
##   external access to a private member, OR assignment to any member, via the singleton:
##     ExerciseClassMapping . ( _privateMember | member = )   (assignment, not '==')
##   Public read calls (no leading underscore, no assignment) never match.
##
## Usage:
##   godot --headless --script tools/ci/check_exercise_mapping_callers.gd
##
## Exit codes:
##   0 = no violations (clean)
##   1 = one or more external mutators / private accesses (CI MUST fail)
##   2 = internal error (src/ missing, regex compile failure)
##
## Governing docs: ADR-0007; ADR-0008 (#10 autoload); design/gdd/exercise-class-mapping.md
##   Rule 2; TR-ECM-005; #10 Story 005.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const FILE_EXTENSION: String = "gd"
const LINT_TAG: String = "check_exercise_mapping_callers"

## Only the owner may touch ExerciseClassMapping's internals (state + _create_test_registry).
## Matched by exact res:// path so a look-alike basename can never self-exempt.
const EXEMPT_EXACT := [
	"res://src/autoload/exercise_class_mapping.gd",
]

## ExerciseClassMapping.<_private>  OR  ExerciseClassMapping.<member> = (single '=', not '==').
const FORBIDDEN_PATTERN: String = "ExerciseClassMapping\\s*\\.\\s*(?:_[A-Za-z0-9_]+|[A-Za-z0-9_]+\\s*=(?!=))"


func _init() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCAN_ROOT)):
		push_error("[%s] src/ not found at %s — cannot scan" % [LINT_TAG, SCAN_ROOT])
		quit(2)
		return

	var re := RegEx.new()
	if re.compile(FORBIDDEN_PATTERN) != OK:
		push_error("[%s] regex compile failed: %s" % [LINT_TAG, FORBIDDEN_PATTERN])
		quit(2)
		return

	var scan_files: Array[String] = []
	_collect_gd_files(SCAN_ROOT, scan_files)

	var violations: Array[Dictionary] = []
	for file_path: String in scan_files:
		if _is_whitelisted(file_path):
			continue
		violations.append_array(_scan_file(file_path, re))

	if violations.is_empty():
		print("[%s] PASS: scanned %d file(s), 0 external mutators/private-accesses of ExerciseClassMapping" % [
			LINT_TAG, scan_files.size(),
		])
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: ExerciseClassMapping is a read-only closed API — no external write/private access (ADR-0007)" % [
			v["file"], v["line"], v["col"],
		])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[%s] FAIL: %d external mutator/private-access call(s). Use get_class_for_exercise / get_class_for_movement_pattern / is_known_exercise only." % [
		LINT_TAG, violations.size(),
	])
	quit(1)


## A file is exempt only if it is the owner (exact res:// path).
func _is_whitelisted(file_path: String) -> bool:
	return EXEMPT_EXACT.has(file_path)


func _collect_gd_files(dir_path: String, accumulator: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("[%s] cannot open directory: %s" % [LINT_TAG, dir_path])
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
		push_error("[%s] cannot read: %s" % [LINT_TAG, file_path])
		return violations
	var lines: PackedStringArray = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()
	for i: int in lines.size():
		var raw_line: String = lines[i]
		if raw_line.strip_edges(true, false).begins_with("#"):
			continue
		var line: String = _strip_trailing_comment(raw_line)
		var m := re.search(line)
		if m != null:
			violations.append({
				"file": file_path,
				"line": i + 1,
				"col": m.get_start() + 1,
				"snippet": raw_line.strip_edges(),
			})
	return violations


## Remove a trailing `#` comment from a code line, ignoring `#` inside string literals.
func _strip_trailing_comment(line: String) -> String:
	var in_single: bool = false
	var in_double: bool = false
	for k: int in line.length():
		var ch: String = line[k]
		if ch == "\"" and not in_single:
			in_double = not in_double
		elif ch == "'" and not in_double:
			in_single = not in_single
		elif ch == "#" and not in_single and not in_double:
			return line.substr(0, k)
	return line

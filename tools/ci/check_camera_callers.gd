#!/usr/bin/env -S godot --headless --script
## CI Lint — Camera2D mutation gateway enforcement (ADR-0001 structural; Story 004 AC-05).
##
## Purpose:
##   Direct mutation of `Camera2D.position` / `Camera2D.zoom` / `Camera2D.make_current()`
##   is FORBIDDEN outside `src/autoload/camera_controller.gd`. All camera motion MUST
##   route through the CameraController API to preserve Pillar 2 frictionless feel and
##   the ADR-0001 web-export budget caps. Story 004 AC-05 extends this scan to cover
##   enemy_director.gd (and the whole of src/) — no caller may bypass the gateway.
##
## Scan target:
##   res://src/   (recursive — every .gd file EXCEPT the exempt gateway autoload).
##
## Exempt gateway (may mutate Camera2D directly):
##   res://src/autoload/camera_controller.gd
##
## Forbidden patterns (regex), on non-comment lines outside the exempt file.
##   Each is anchored to a `Camera2D` reference token so the lint targets ONLY camera
##   mutation and never false-positives on unrelated `node.position = ...` lines:
##     Camera2D[^\n]*\.position\s*=        — Camera2D positional mutation
##     Camera2D[^\n]*\.zoom\s*=            — Camera2D zoom mutation
##     Camera2D[^\n]*\.make_current\s*\(   — Camera2D activation
##   The reference may be a node path (`$Camera2D`), a unique name (`%Camera2D`), or a
##   typed local (`var cam: Camera2D`); all carry the `Camera2D` token on the line.
##   The gateway file is exempt, so legitimate CameraController internals never trip
##   the lint; any OTHER file mutating a Camera2D is the surface ADR-0001 forbids.
##
## Usage:
##   godot --headless --script tools/ci/check_camera_callers.gd
##
## Exit codes:
##   0 = no violations (clean)
##   1 = one or more violations found (CI MUST fail)
##   2 = internal error (src/ missing, regex compile failure)
##
## Governing docs: ADR-0001 (Camera2D mutation gateway); .claude/docs/technical-preferences.md
##   Forbidden Patterns; Story 004 AC-05.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const FILE_EXTENSION: String = "gd"
const LINT_TAG: String = "check_camera_callers"

## Full res:// path of the sole gateway permitted to mutate Camera2D directly.
const EXEMPT_FILES := [
	"res://src/autoload/camera_controller.gd",
]

## Forbidden Camera2D mutation tokens. Matched on any non-comment line outside the
## exempt gateway file.
const FORBIDDEN_PATTERNS: Array[String] = [
	"Camera2D[^\\n]*\\.position\\s*=",
	"Camera2D[^\\n]*\\.zoom\\s*=",
	"Camera2D[^\\n]*\\.make_current\\s*\\(",
]


func _init() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCAN_ROOT)):
		push_error("[%s] src/ not found at %s — cannot scan" % [LINT_TAG, SCAN_ROOT])
		quit(2)
		return

	var compiled: Array[RegEx] = []
	for pattern: String in FORBIDDEN_PATTERNS:
		var re := RegEx.new()
		if re.compile(pattern) != OK:
			push_error("[%s] regex compile failed: %s" % [LINT_TAG, pattern])
			quit(2)
			return
		compiled.append(re)

	var scan_files: Array[String] = []
	_collect_gd_files(SCAN_ROOT, scan_files)

	var violations: Array[Dictionary] = []
	for file_path: String in scan_files:
		if EXEMPT_FILES.has(file_path):
			continue
		violations.append_array(_scan_file(file_path, compiled))

	if violations.is_empty():
		print("[%s] PASS: scanned %d file(s), 0 direct Camera2D mutations outside camera_controller.gd" % [
			LINT_TAG, scan_files.size(),
		])
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: direct Camera2D mutation FORBIDDEN — route through CameraController (pattern: %s)" % [
			v["file"], v["line"], v["col"], v["pattern"],
		])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[%s] FAIL: %d violation(s). Only camera_controller.gd may mutate Camera2D directly (ADR-0001)." % [
		LINT_TAG, violations.size(),
	])
	quit(1)


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


func _scan_file(file_path: String, compiled: Array[RegEx]) -> Array[Dictionary]:
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
		# Strip trailing comment before matching so an inline comment that mentions a
		# forbidden token (e.g. "# route via CameraController not Camera2D.position =")
		# does not false-positive. Code before the comment is still scanned.
		var line: String = _strip_trailing_comment(raw_line)
		for j: int in compiled.size():
			var m := compiled[j].search(line)
			if m != null:
				violations.append({
					"file": file_path,
					"line": i + 1,
					"col": m.get_start() + 1,
					"pattern": FORBIDDEN_PATTERNS[j],
					"snippet": raw_line.strip_edges(),
				})
	return violations


## Remove a trailing `#` comment from a code line, ignoring `#` inside string
## literals (single/double quote). Returns the code portion only.
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

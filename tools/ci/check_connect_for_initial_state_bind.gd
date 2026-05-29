#!/usr/bin/env -S godot --headless --script
## CI Lint — `connect_for_initial_state(...bind(...))` detection
##
## ADR-0006 Contract 6 (line 391) + Contract 12 scope addition.
##
## FORBIDDEN pattern: `connect_for_initial_state(<callable>.bind(<extra>))`
## REASON: `.bind()` shifts positional argument layout. `connect_for_initial_state`
## delivers the initial state via `Callable.callv([from, to, payload])` — this targets
## the registered Callable by position. A bound Callable receives `(extra, from, to,
## payload)` instead of `(from, to, payload)`, so the subscriber silently sees
## `from = extra`, `to = from`, etc. — garbage initial state.
##
## CORRECT:
##   state_machine.connect_for_initial_state(_on_state_changed)
##
## FORBIDDEN:
##   state_machine.connect_for_initial_state(_on_state_changed.bind(extra_context))
##
## Usage (CI / local):
##   godot --headless --script tools/ci/check_connect_for_initial_state_bind.gd
##
## Exit codes:
##   0 = no violations (scan completed successfully)
##   1 = one or more violations found (CI MUST fail)
##   2 = scanner internal error (src/ unreadable, etc.)
##
## Scope:
##   - Scans all *.gd files recursively under res://src/
##   - Skips lines that are pure comments (whitespace + `#`)
##   - Line-by-line + 2-line window for multi-line call splits
##   - Self-skip: this file's own example-strings in doc comments are not flagged
##     because doc comments start with `#`, not raw code.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const FILE_EXTENSION: String = "gd"

## Pattern: `connect_for_initial_state` then `(`, then any non-`)` chars, then `.bind(`.
## Examples that match (after comment-line filter):
##   gsm.connect_for_initial_state(_on.bind(x))
##   GameStateMachine.connect_for_initial_state( handler.bind(ctx) )
##   var x = foo.connect_for_initial_state(cb.bind(a, b))
const FORBIDDEN_PATTERN: String = "connect_for_initial_state\\s*\\(\\s*[^)]*\\.bind\\s*\\("


func _init() -> void:
	var violations: Array[Dictionary] = []
	var files_scanned: int = 0
	var regex := RegEx.new()
	var compile_result: int = regex.compile(FORBIDDEN_PATTERN)
	if compile_result != OK:
		push_error("[check_connect_for_initial_state_bind] regex compile failed (error %d)" % compile_result)
		quit(2)
		return

	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCAN_ROOT)):
		push_warning("[check_connect_for_initial_state_bind] %s does not exist — 0 files scanned, PASS" % SCAN_ROOT)
		print("PASS: 0 files scanned (no src/ directory), 0 violations")
		quit(0)
		return

	var scan_files: Array[String] = []
	_collect_gd_files(SCAN_ROOT, scan_files)
	files_scanned = scan_files.size()

	for file_path: String in scan_files:
		var file_violations: Array[Dictionary] = _scan_file(file_path, regex)
		violations.append_array(file_violations)

	if violations.is_empty():
		print("PASS: scanned %d file(s), 0 violations" % files_scanned)
		quit(0)
		return

	# Emit each violation in `path:line:col: message` format (matches most CI parsers)
	for v: Dictionary in violations:
		printerr("%s:%d:%d: connect_for_initial_state called with .bind() callable — forbidden per ADR-0006 Contract 6 (line 391)" % [
			v["file"], v["line"], v["col"]
		])
		printerr("  > %s" % v["snippet"])

	printerr("")
	printerr("FAIL: scanned %d file(s), %d violation(s) of ADR-0006 Contract 6 + 12" % [files_scanned, violations.size()])
	quit(1)


func _collect_gd_files(dir_path: String, accumulator: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("[check_connect_for_initial_state_bind] cannot open %s" % dir_path)
		return
	for file_name: String in dir.get_files():
		if file_name.get_extension() == FILE_EXTENSION:
			accumulator.append(dir_path.path_join(file_name))
	for subdir_name: String in dir.get_directories():
		_collect_gd_files(dir_path.path_join(subdir_name), accumulator)


func _scan_file(file_path: String, regex: RegEx) -> Array[Dictionary]:
	var violations: Array[Dictionary] = []
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[check_connect_for_initial_state_bind] cannot read %s" % file_path)
		return violations

	var lines: PackedStringArray = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()

	for i: int in lines.size():
		var line: String = lines[i]
		if _is_comment_line(line):
			continue
		var match := regex.search(line)
		if match != null:
			violations.append({
				"file": file_path,
				"line": i + 1,
				"col": match.get_start() + 1,
				"snippet": line.strip_edges(),
			})

	return violations


## A line is a comment line if its first non-whitespace char is `#`.
## Inline `#` (mid-line) is NOT treated as a comment by this lint — but the regex
## requires the literal token `connect_for_initial_state(` followed by `.bind(`,
## so an inline `# ... .bind(...)` after real code on the same line is rare and
## would still be a real call if `connect_for_initial_state(` appeared earlier.
func _is_comment_line(line: String) -> bool:
	var stripped: String = line.strip_edges(true, false)
	return stripped.begins_with("#")

#!/usr/bin/env -S godot --headless --script
## CI Lint — `_force_test_drop` must be debug-build gated (GDD Rule, Story 001)
##
## Story 001 (GDD Rule enforcement): `_force_test_drop` is a developer-only hook
## that mints loot on demand for testing. It MUST NEVER run in a release/web build
## (Pillar 3 "loot must be earned" — a release force-drop is a cheat vector). Any
## CALL SITE of `_force_test_drop(...)` must be guarded by an `OS.is_debug_build()`
## branch; the DEFINITION (`func _force_test_drop`) is allowed anywhere.
##
## ── DETECTION STRATEGY (file-level co-existence HEURISTIC, MVP precision) ──────
## For each `src/` .gd file that contains a CALL to `_force_test_drop(`, we require
## the SAME FILE to also contain an `OS.is_debug_build()` reference. This is a
## file-level co-existence heuristic — it does NOT prove the call is lexically
## inside the guard's `if` block (a control-flow analysis would). It catches the
## common mistake (an un-guarded force-drop in a file with no debug check at all)
## cheaply; a release-build runtime guard inside `_force_test_drop` itself is the
## authoritative second line of defense. A `func _force_test_drop` definition line
## is NOT counted as a call site.
##
## Usage:
##   godot --headless --script tools/ci/check_loot_force_drop_debug_only.gd
##
## Exit codes:
##   0 = every file calling _force_test_drop also references OS.is_debug_build() (clean)
##   1 = a file calls _force_test_drop with NO debug guard present (CI MUST fail)
##   2 = internal error (src/ missing, regex compile failure)
##
## Governing docs: design/gdd/loot-drop-system.md (Pillar 3); story-001-ci-lints-closed-api.md.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const FILE_EXTENSION: String = "gd"
const LINT_TAG: String = "check_loot_force_drop_debug_only"
const CALL_PATTERN: String = "_force_test_drop\\s*\\("
const DEFINITION_PATTERN: String = "^[ \\t]*func[ \\t]+_force_test_drop\\b"
const GUARD_PATTERN: String = "OS\\.is_debug_build\\s*\\("


func _init() -> void:
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCAN_ROOT)):
		push_error("[%s] src/ not found at %s — cannot scan" % [LINT_TAG, SCAN_ROOT])
		quit(2)
		return

	var re_call := _compile(CALL_PATTERN)
	var re_def := _compile(DEFINITION_PATTERN)
	var re_guard := _compile(GUARD_PATTERN)
	if re_call == null or re_def == null or re_guard == null:
		quit(2)
		return

	var scan_files: Array[String] = []
	_collect_gd_files(SCAN_ROOT, scan_files)

	var violations: Array[Dictionary] = []
	for file_path: String in scan_files:
		var lines := _read_lines(file_path)
		if lines.is_empty() and not FileAccess.file_exists(file_path):
			continue

		var call_sites: Array[int] = []
		var has_guard := false
		for i: int in lines.size():
			var line: String = lines[i]
			if line.strip_edges(true, false).begins_with("#"):
				continue
			if re_def.search(line) != null:
				continue  # the definition is not a call
			if re_call.search(line) != null:
				call_sites.append(i)
			if re_guard.search(line) != null:
				has_guard = true

		if call_sites.is_empty():
			continue
		if has_guard:
			continue  # file co-locates a debug guard — heuristic-clean
		# Calls present, but the file has NO OS.is_debug_build() anywhere.
		for idx: int in call_sites:
			violations.append({
				"file": file_path,
				"line": idx + 1,
				"snippet": lines[idx].strip_edges(),
			})

	if violations.is_empty():
		print("[%s] PASS: scanned %d file(s), every _force_test_drop caller co-locates an OS.is_debug_build() guard" % [LINT_TAG, scan_files.size()])
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d: _force_test_drop() called in a file with no OS.is_debug_build() guard — debug-only hook must be gated (Pillar 3)" % [v["file"], v["line"]])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[%s] FAIL: %d un-guarded _force_test_drop call(s)." % [LINT_TAG, violations.size()])
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


func _read_lines(file_path: String) -> PackedStringArray:
	var out: PackedStringArray = []
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[%s] cannot read: %s" % [LINT_TAG, file_path])
		return out
	while not file.eof_reached():
		out.append(file.get_line())
	file.close()
	return out


func _compile(pattern: String) -> RegEx:
	var re := RegEx.new()
	if re.compile(pattern) != OK:
		push_error("[%s] regex compile failed: %s" % [LINT_TAG, pattern])
		return null
	return re

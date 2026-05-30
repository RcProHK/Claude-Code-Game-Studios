#!/usr/bin/env -S godot --headless --script
## CI Lint — StatSource.DEBUG_OVERRIDE release branch guard (GDD Rule 10, FR-3)
##
## AC-14: On release branches (main / release/*), any src/ file containing
##   `StatSource.DEBUG_OVERRIDE` causes this lint to FAIL.
##   DEBUG_OVERRIDE forces a stat baseline for playtesting and MUST NOT reach
##   production — it short-circuits the real-workout signal chain (Pillar 1 violation).
##
## Branch detection (reads CI environment variables):
##   GITHUB_REF_NAME — branch name set by GitHub Actions (e.g. "main")
##   GITHUB_REF      — full ref path fallback (e.g. "refs/heads/main")
##   If neither is set (local dev run) → exits 0 (lint only enforced in CI).
##
## Editor guard exception: occurrences are skipped when:
##   - The offending line itself contains OS.has_feature("editor") (inline guard), OR
##   - Any of the 3 lines immediately above the offending line contains
##     OS.has_feature("editor") (block-level `if OS.has_feature("editor"):` guard).
##
## Usage:
##   godot --headless --script tools/ci/check_debug_override_calls.gd
##
## Exit codes:
##   0 = no violations, or non-release branch, or local run
##   1 = violations found on a release branch (CI MUST fail)
##   2 = internal error (src/ missing, regex compile failure, unreadable file)
##
## Governing docs: design/gdd/stat-system.md Rule 10; TR-stat-016; FR-3.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const FILE_EXTENSION: String = "gd"
const FORBIDDEN_PATTERN: String = "StatSource\\.DEBUG_OVERRIDE"
const EDITOR_GUARD_PATTERN: String = "OS\\.has_feature\\(\"editor\"\\)"


func _init() -> void:
	# --- Branch detection -------------------------------------------------------
	var branch := OS.get_environment("GITHUB_REF_NAME")
	if branch.is_empty():
		var ref := OS.get_environment("GITHUB_REF")
		if ref.begins_with("refs/heads/"):
			branch = ref.substr("refs/heads/".length())
		# refs/tags/* are treated as non-release for this lint

	var is_release_branch := (branch == "main" or branch.begins_with("release/"))
	if not is_release_branch:
		var label := branch if not branch.is_empty() else "local/undetected"
		print("[check_debug_override_calls] PASS: branch '%s' is not a release branch — DEBUG_OVERRIDE permitted" % label)
		quit(0)
		return

	# --- Scan -------------------------------------------------------------------
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(SCAN_ROOT)):
		push_error("[check_debug_override_calls] src/ not found at %s — cannot scan" % SCAN_ROOT)
		quit(2)
		return

	var forbidden_re := RegEx.new()
	var editor_re := RegEx.new()
	if forbidden_re.compile(FORBIDDEN_PATTERN) != OK:
		push_error("[check_debug_override_calls] regex compile failed: %s" % FORBIDDEN_PATTERN)
		quit(2)
		return
	if editor_re.compile(EDITOR_GUARD_PATTERN) != OK:
		push_error("[check_debug_override_calls] regex compile failed: %s" % EDITOR_GUARD_PATTERN)
		quit(2)
		return

	var scan_files: Array[String] = []
	_collect_gd_files(SCAN_ROOT, scan_files)

	var violations: Array[Dictionary] = []
	for file_path: String in scan_files:
		violations.append_array(_scan_file(file_path, forbidden_re, editor_re))

	if violations.is_empty():
		print("[check_debug_override_calls] PASS: scanned %d file(s) on branch '%s', 0 violations" % [scan_files.size(), branch])
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: StatSource.DEBUG_OVERRIDE on release branch '%s' — FORBIDDEN (GDD Rule 10, FR-3)" % [
			v["file"], v["line"], v["col"], branch,
		])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[check_debug_override_calls] FAIL: %d violation(s) on release branch '%s'. Remove DEBUG_OVERRIDE before merging to main." % [violations.size(), branch])
	quit(1)


func _collect_gd_files(dir_path: String, accumulator: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("[check_debug_override_calls] cannot open directory: %s" % dir_path)
		return
	for file_name: String in dir.get_files():
		if file_name.get_extension() == FILE_EXTENSION:
			accumulator.append(dir_path.path_join(file_name))
	for subdir_name: String in dir.get_directories():
		_collect_gd_files(dir_path.path_join(subdir_name), accumulator)


## Scans a single file for DEBUG_OVERRIDE occurrences, applying editor-guard filtering.
## An occurrence is skipped if:
##   - The offending line itself contains OS.has_feature("editor") (inline guard)
##   - Any of the 3 lines immediately above contains OS.has_feature("editor")
##     (covers the common `if OS.has_feature("editor"):` block pattern)
func _scan_file(file_path: String, forbidden_re: RegEx, editor_re: RegEx) -> Array[Dictionary]:
	var violations: Array[Dictionary] = []
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		push_error("[check_debug_override_calls] cannot read: %s" % file_path)
		return violations
	var lines: PackedStringArray = []
	while not file.eof_reached():
		lines.append(file.get_line())
	file.close()

	for i: int in lines.size():
		var line: String = lines[i]
		if _is_comment_line(line):
			continue
		var m := forbidden_re.search(line)
		if m == null:
			continue
		# Inline guard: same line contains OS.has_feature("editor")
		if editor_re.search(line) != null:
			continue
		# Block guard: any of the 3 lines above contains OS.has_feature("editor")
		var guarded := false
		var look_back: int = mini(3, i)
		for j: int in range(1, look_back + 1):
			if editor_re.search(lines[i - j]) != null:
				guarded = true
				break
		if guarded:
			continue
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

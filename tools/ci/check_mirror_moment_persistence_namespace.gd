#!/usr/bin/env -S godot --headless --script
## CI Lint CI-MM-4 — MirrorMoment writes only the mirror_moment.* namespace (CR-M13 / AC-19).
##
## Purpose:
##   #29 persists a thin ceremony latch under `mirror_moment.*` ONLY. It must never write
##   `avatar.*` (the #26-owned evolution-tier history) — that would breach the ADR-0010
##   ownership seam (CR-M14). Reading #26's signals (named `avatar_evolution_milestone` /
##   `avatar_micro_evolution`, underscore — NOT a namespace dot) is allowed; only the
##   `avatar.` persistence-namespace prefix and #26's history key are forbidden.
##
## Scan target: every res://src/**/mirror_moment*.gd.
## Exit codes: 0 = clean, 1 = violation, 2 = internal error.
## Governing: ADR-0003 / ADR-0010, mirror-moment.md CR-M13 / CI-MM-4, Story 014.
extends SceneTree

const LINT_TAG := "check_mirror_moment_persistence_namespace"

## `"avatar\.` = the avatar persistence namespace (dot). The signal names use an underscore
## (`avatar_evolution_milestone`) so they never match this — only a foreign namespace write does.
const FORBIDDEN_PATTERNS: Array[String] = [
	"\"avatar\\.",            # writing/reading the #26 persistence namespace
	"evolution_tier_history",  # the #26-owned persistence key by name
]


func _init() -> void:
	var compiled: Array[RegEx] = []
	for pattern: String in FORBIDDEN_PATTERNS:
		var re := RegEx.new()
		if re.compile(pattern) != OK:
			push_error("[%s] regex compile failed: %s" % [LINT_TAG, pattern])
			quit(2)
			return
		compiled.append(re)

	var scan_files: Array[String] = []
	_collect("res://src/", scan_files)

	var violations: Array[Dictionary] = []
	for file_path: String in scan_files:
		violations.append_array(_scan_file(file_path, compiled))

	if violations.is_empty():
		print("[%s] PASS: scanned %d #29 file(s), 0 avatar.* namespace write (CR-M13 / CR-M14)" % [LINT_TAG, scan_files.size()])
		quit(0)
		return
	for v: Dictionary in violations:
		printerr("%s:%d: foreign persistence namespace FORBIDDEN in #29 (mirror_moment.* only — CR-M13) [%s]" % [
			v["file"], v["line"], v["pattern"]])
		printerr("  > %s" % v["snippet"])
	printerr("[%s] FAIL: %d violation(s)." % [LINT_TAG, violations.size()])
	quit(1)


func _collect(dir_path: String, acc: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		if file_name.get_extension() == "gd" and file_name.begins_with("mirror_moment"):
			acc.append(dir_path.path_join(file_name))
	for subdir: String in dir.get_directories():
		_collect(dir_path.path_join(subdir), acc)


func _scan_file(file_path: String, compiled: Array[RegEx]) -> Array[Dictionary]:
	var violations: Array[Dictionary] = []
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return violations
	var i := 0
	while not file.eof_reached():
		var raw := file.get_line()
		i += 1
		if raw.strip_edges(true, false).begins_with("#"):
			continue
		for j: int in compiled.size():
			if compiled[j].search(raw) != null:
				violations.append({"file": file_path, "line": i, "pattern": FORBIDDEN_PATTERNS[j], "snippet": raw.strip_edges()})
	file.close()
	return violations

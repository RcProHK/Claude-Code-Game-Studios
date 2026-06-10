#!/usr/bin/env -S godot --headless --script
## CI Lint — AvatarRenderer render-only ownership boundary (ADR-0010 / CR-17 / AC-30).
##
## Purpose:
##   #26 Avatar Renderer renders the avatar's visible evolution state ONLY. ALL
##   Mirror Moment ceremony composition (9:16 portrait, hero-pose layout, ghost-
##   overlay compositing, screenshot prompt, share UI) belongs to #29 (ADR-0010).
##   This lint is the structural enforcement of that seam — symmetric with #29's
##   CI-MM-1 (check_mirror_moment_no_tier_compute.gd) guarding the other side.
##
## Scan target:
##   res://src/autoload/avatar_renderer.gd + res://src/ui/avatar* (if any).
##
## Forbidden ceremony tokens (regex, non-comment lines): any sign of #26 composing
##   the weekly ceremony rather than merely exposing the snapshot seam.
##
## Exit codes: 0 = clean, 1 = violation (CI MUST fail), 2 = internal error.
## Governing: ADR-0010, avatar-renderer.md CR-17 / AC-30, Story 017.
extends SceneTree

const LINT_TAG := "check_avatar_renderer_no_ceremony"
const FILE_EXTENSION := "gd"

## Files #26 OWNS — must contain zero ceremony composition.
const SCAN_GLOBS := [
	"res://src/autoload/avatar_renderer.gd",
	"res://src/ui/",  # any avatar* UI file here would be a violation by existence too
]

## Ceremony-composition tokens that must NOT appear in #26 source.
const FORBIDDEN_PATTERNS: Array[String] = [
	"9:16",
	"(?i)screenshot",
	"(?i)share_card",
	"(?i)share-card",
	"(?i)ghost_overlay",
	"(?i)ghost_offset",
	"(?i)ceremony",
	"(?i)CelebrationVFXLayer",
	"(?i)ModalLayer",
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
	# Always include the autoload.
	if FileAccess.file_exists("res://src/autoload/avatar_renderer.gd"):
		scan_files.append("res://src/autoload/avatar_renderer.gd")
	# Include any avatar* file under src/ui/.
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://src/ui/")):
		_collect_avatar_ui("res://src/ui/", scan_files)

	var violations: Array[Dictionary] = []
	for file_path: String in scan_files:
		violations.append_array(_scan_file(file_path, compiled))

	if violations.is_empty():
		print("[%s] PASS: scanned %d #26 file(s), 0 ceremony composition (ADR-0010 / CR-17)" % [
			LINT_TAG, scan_files.size()])
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d: ceremony composition FORBIDDEN in #26 (ADR-0010 / CR-17 — belongs to #29) [%s]" % [
			v["file"], v["line"], v["pattern"]])
		printerr("  > %s" % v["snippet"])
	printerr("[%s] FAIL: %d violation(s)." % [LINT_TAG, violations.size()])
	quit(1)


func _collect_avatar_ui(dir_path: String, acc: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		if file_name.get_extension() == FILE_EXTENSION and file_name.begins_with("avatar"):
			acc.append(dir_path.path_join(file_name))
	for subdir: String in dir.get_directories():
		_collect_avatar_ui(dir_path.path_join(subdir), acc)


func _scan_file(file_path: String, compiled: Array[RegEx]) -> Array[Dictionary]:
	var violations: Array[Dictionary] = []
	var file := FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return violations
	var i := 0
	while not file.eof_reached():
		var raw := file.get_line()
		i += 1
		var trimmed := raw.strip_edges(true, false)
		if trimmed.begins_with("#"):
			continue
		for j: int in compiled.size():
			if compiled[j].search(raw) != null:
				violations.append({
					"file": file_path, "line": i,
					"pattern": FORBIDDEN_PATTERNS[j], "snippet": raw.strip_edges(),
				})
	file.close()
	return violations

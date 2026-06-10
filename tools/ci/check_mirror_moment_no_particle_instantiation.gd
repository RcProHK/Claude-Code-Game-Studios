#!/usr/bin/env -S godot --headless --script
## CI Lint CI-MM-2 — MirrorMoment particles only via #5.play() (CR-M8 / technical-preferences).
##
## Purpose:
##   #5 ParticleSystemWrapper is the sole owner of GPUParticles2D (ADR-0001 forbidden
##   pattern). #29 celebration bursts go EXCLUSIVELY through #5.play() — never a direct
##   particle node. This also keeps the B-1 LOOT-preset → CelebrationVFXLayer 110 routing
##   (a #5 internal) the only path, so the burst is never stranded below the modal backdrop.
##
## Scan target: every res://src/**/mirror_moment*.gd.
## Exit codes: 0 = clean, 1 = violation, 2 = internal error.
## Governing: ADR-0001, mirror-moment.md CR-M8 / CI-MM-2, Story 014.
extends SceneTree

const LINT_TAG := "check_mirror_moment_no_particle_instantiation"

const FORBIDDEN_PATTERNS: Array[String] = [
	"GPUParticles2D",   # direct particle node — forbidden outside #5 (ADR-0001)
	"CPUParticles2D",
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
		print("[%s] PASS: scanned %d #29 file(s), 0 direct particle instantiation (CR-M8)" % [LINT_TAG, scan_files.size()])
		quit(0)
		return
	for v: Dictionary in violations:
		printerr("%s:%d: direct particle node FORBIDDEN in #29 (use #5.play() — CR-M8) [%s]" % [v["file"], v["line"], v["pattern"]])
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

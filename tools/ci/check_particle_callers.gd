#!/usr/bin/env -S godot --headless --script
## CI Lint — GPUParticles2D instantiation gateway (ADR-0001 structural; Story 004 AC-26/AC-05).
##
## Purpose:
##   Direct `GPUParticles2D` instantiation / mutation is FORBIDDEN outside
##   `src/autoload/particle_system_wrapper.gd`. All particle FX MUST route through
##   `ParticleSystemWrapper.play(preset, position, caller_mult)` so the web-export
##   budget governance (mobile 0.5× density, concurrency cap) is centralised. Story
##   004 AC-26 extends this scan to cover enemy_director.gd (and the whole of src/):
##   no caller may mint a GPUParticles2D or flip its `.emitting` directly.
##
## Scan target:
##   res://src/   (recursive — every .gd file EXCEPT the exempt gateway autoload).
##
## Exempt gateway (may instantiate / mutate GPUParticles2D directly):
##   res://src/autoload/particle_system_wrapper.gd
##
## Forbidden patterns (regex), on non-comment lines outside the exempt file:
##   GPUParticles2D\.new\s*\(            — direct GPUParticles2D instantiation (AC-26)
##   GPUParticles2D[^\n]*\.emitting\s*=  — direct emitting toggle (AC-05)
##
## Usage:
##   godot --headless --script tools/ci/check_particle_callers.gd
##
## Exit codes:
##   0 = no violations (clean)
##   1 = one or more violations found (CI MUST fail)
##   2 = internal error (src/ missing, regex compile failure)
##
## Governing docs: ADR-0001 (GPUParticles2D instantiation gateway);
##   .claude/docs/technical-preferences.md Forbidden Patterns; Story 004 AC-26, AC-05.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const FILE_EXTENSION: String = "gd"
const LINT_TAG: String = "check_particle_callers"

## Full res:// path of the sole gateway permitted to instantiate GPUParticles2D directly.
const EXEMPT_FILES := [
	"res://src/autoload/particle_system_wrapper.gd",
]

## Forbidden GPUParticles2D instantiation / mutation tokens.
const FORBIDDEN_PATTERNS: Array[String] = [
	"GPUParticles2D\\.new\\s*\\(",
	"GPUParticles2D[^\\n]*\\.emitting\\s*=",
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
		print("[%s] PASS: scanned %d file(s), 0 direct GPUParticles2D instantiation/mutation outside particle_system_wrapper.gd" % [
			LINT_TAG, scan_files.size(),
		])
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: direct GPUParticles2D use FORBIDDEN — route through ParticleSystemWrapper.play() (pattern: %s)" % [
			v["file"], v["line"], v["col"], v["pattern"],
		])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[%s] FAIL: %d violation(s). Only particle_system_wrapper.gd may instantiate GPUParticles2D (ADR-0001)." % [
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
		# Strip trailing comment before matching (inline comment mentioning a
		# forbidden token must not false-positive). Code before the comment still scanned.
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


## Remove a trailing `#` comment, ignoring `#` inside string literals.
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

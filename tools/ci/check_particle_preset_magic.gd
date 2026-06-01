#!/usr/bin/env -S godot --headless --script
## CI Lint — ParticleSystemWrapper.play() magic preset-id detection (GDD Rule 1, TR-particle-013).
##
## AC-14: Preset ids are a LOCKED surface exposed only via `ParticleSystemWrapper.PresetId`
##   enum constants. A `ParticleSystemWrapper.play(` call whose FIRST argument is a raw int
##   or string literal bypasses the typed enum and drifts the moment a preset is renamed.
##   Use `ParticleSystemWrapper.play(ParticleSystemWrapper.PresetId.HIT_LIGHT, pos)` instead.
##
## Scan target:
##   res://src/   (recursive — every .gd file EXCEPT the owner autoload).
##
## Forbidden pattern (regex), on non-comment lines:
##   ParticleSystemWrapper\.play\s*\(\s*["'0-9]   — magic int/string first arg
##   (PresetId.* references start with "P", so a correct call never matches.)
##
## Scoped to the `ParticleSystemWrapper.` qualifier so unrelated `.play(` calls
## (AnimationPlayer, AudioStreamPlayer, etc.) never false-positive.
##
## Usage:
##   godot --headless --script tools/ci/check_particle_preset_magic.gd
##
## Exit codes:
##   0 = no violations (clean)
##   1 = one or more magic preset-id literals found (CI MUST fail)
##   2 = internal error (src/ missing, regex compile failure, unreadable file)
##
## Governing docs: design/gdd/particle-system-wrapper.md Rule 1; TR-particle-013; ADR-0001.
extends SceneTree


const SCAN_ROOT: String = "res://src/"
const FILE_EXTENSION: String = "gd"
const LINT_TAG: String = "check_particle_preset_magic"
## Owner declares `func play(preset_id: PresetId, ...)` — exempt (it never calls the
## qualified ParticleSystemWrapper.play() form, but exempt for clarity).
const OWNER_FILE: String = "res://src/autoload/particle_system_wrapper.gd"

const FORBIDDEN_PATTERN: String = "ParticleSystemWrapper\\.play\\s*\\(\\s*[\"'0-9]"


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
		if file_path == OWNER_FILE:
			continue
		violations.append_array(_scan_file(file_path, re))

	if violations.is_empty():
		print("[%s] PASS: scanned %d file(s), 0 magic preset-id play() calls" % [LINT_TAG, scan_files.size()])
		quit(0)
		return

	for v: Dictionary in violations:
		printerr("%s:%d:%d: Magic preset-id FORBIDDEN — use ParticleSystemWrapper.PresetId.* (GDD Rule 1, TR-particle-013)" % [
			v["file"], v["line"], v["col"],
		])
		printerr("  > %s" % v["snippet"])
	printerr("")
	printerr("[%s] FAIL: %d magic preset-id play() call(s). Use the PresetId enum surface." % [LINT_TAG, violations.size()])
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
		var line: String = lines[i]
		if line.strip_edges(true, false).begins_with("#"):
			continue  # skip comment lines (no false-positive on commented examples)
		var m := re.search(line)
		if m != null:
			violations.append({
				"file": file_path,
				"line": i + 1,
				"col": m.get_start() + 1,
				"snippet": line.strip_edges(),
			})
	return violations

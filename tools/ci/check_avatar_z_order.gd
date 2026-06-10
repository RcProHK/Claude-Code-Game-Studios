#!/usr/bin/env -S godot --headless --script
## CI Lint — avatar z-order discipline (CR-7 / INV-3 / CI-4 / AC-26).
##
## CanvasLayer topology (ADR-0001): World(0) < Character(10, avatar, internal z_index∈[-10,10])
## < Particle(20, always above avatar) < Event/HUD(100). This lint forward-guards the #26
## render surface + any src/ui/avatar* view so a z-order regression can never bury the avatar
## under the world or float it over the HUD:
##   - `z_index = N`            literal must be in [-10, 10]
##   - `<CanvasLayer>.layer = N` / `layer = N` literal must be 10 (avatar Character layer)
##     UNLESS the line mentions a particle layer (then it must be >= 20).
##
## Scan: avatar_renderer.gd + every src/ui/avatar* .gd (recursive). Today the coordinator
## owns no z_index (the view is a later story), so this passes trivially and arms the guard
## for when the render surface lands.
##
## Exit codes: 0 = clean, 1 = violation (CI MUST fail), 2 = internal error.
## Governing: avatar-renderer.md CR-7 / INV-3 / AC-26, ADR-0001, Story 017.
extends SceneTree

const LINT_TAG := "check_avatar_z_order"
const Z_MIN := -10
const Z_MAX := 10
const CHARACTER_LAYER := 10
const PARTICLE_LAYER_MIN := 20


func _init() -> void:
	var z_re := RegEx.new()
	z_re.compile("z_index\\s*=\\s*(-?\\d+)")
	var layer_re := RegEx.new()
	layer_re.compile("\\blayer\\s*=\\s*(-?\\d+)")

	var scan_files: Array[String] = []
	if FileAccess.file_exists("res://src/autoload/avatar_renderer.gd"):
		scan_files.append("res://src/autoload/avatar_renderer.gd")
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://src/ui/")):
		_collect_avatar_ui("res://src/ui/", scan_files)

	var violations: Array[String] = []
	for path: String in scan_files:
		var file := FileAccess.open(path, FileAccess.READ)
		if file == null:
			continue
		var i := 0
		while not file.eof_reached():
			var raw := file.get_line()
			i += 1
			if raw.strip_edges(true, false).begins_with("#"):
				continue
			var zm := z_re.search(raw)
			if zm != null:
				var z := int(zm.get_string(1))
				if z < Z_MIN or z > Z_MAX:
					violations.append("%s:%d: z_index=%d outside [-10,10] (CR-7/AC-26 Character layer)" % [path, i, z])
			var lm := layer_re.search(raw)
			if lm != null:
				var lay := int(lm.get_string(1))
				var is_particle := raw.to_lower().contains("particle")
				if is_particle:
					if lay < PARTICLE_LAYER_MIN:
						violations.append("%s:%d: particle layer=%d must be >= 20 (CR-7/AC-26)" % [path, i, lay])
				elif lay != CHARACTER_LAYER:
					violations.append("%s:%d: avatar CanvasLayer.layer=%d must be 10 (CR-7/AC-26 Character layer)" % [path, i, lay])
		file.close()

	if violations.is_empty():
		print("[%s] PASS: scanned %d file(s), avatar z-order within CR-7/INV-3 bounds" % [LINT_TAG, scan_files.size()])
		quit(0)
		return
	for v: String in violations:
		printerr(v)
	printerr("[%s] FAIL: %d violation(s)." % [LINT_TAG, violations.size()])
	quit(1)


func _collect_avatar_ui(dir_path: String, acc: Array[String]) -> void:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return
	for file_name: String in dir.get_files():
		if file_name.get_extension() == "gd" and file_name.begins_with("avatar"):
			acc.append(dir_path.path_join(file_name))
	for subdir: String in dir.get_directories():
		_collect_avatar_ui(dir_path.path_join(subdir), acc)

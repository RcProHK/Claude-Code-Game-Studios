# ScreenEffects — Story 008: autoload position 15, after ParticleSystemWrapper (13).
# (Shifted 14→15 by #10 Story 005: ExerciseClassMapping inserted at pos 5 — ADR-0008.)
#
# Static read of project.godot [autoload] (ADR-0008 sole ground truth for absolute positions).
extends GutTest

const PROJECT_GODOT: String = "res://project.godot"


func _read_autoload_order() -> Array[String]:
	var abs := ProjectSettings.globalize_path(PROJECT_GODOT)
	var file := FileAccess.open(abs, FileAccess.READ)
	assert_not_null(file, "project.godot must be readable")
	var in_section := false
	var order: Array[String] = []
	while file != null and not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "[autoload]":
			in_section = true
			continue
		if in_section and line.begins_with("["):
			break
		if in_section and "=" in line and not line.begins_with(";"):
			order.append(line.split("=")[0].strip_edges())
	if file != null:
		file.close()
	return order


func test_screen_effects_is_position_15_after_particle_wrapper() -> void:
	var order := _read_autoload_order()
	var se_idx := order.find("ScreenEffects")
	var psw_idx := order.find("ParticleSystemWrapper")
	assert_gt(se_idx, -1, "ScreenEffects must be a registered autoload")
	assert_gt(psw_idx, -1, "ParticleSystemWrapper must be a registered autoload")
	assert_eq(se_idx + 1, 15, "ScreenEffects must be at autoload position 15 (ADR-0008 ground truth)")
	assert_lt(psw_idx, se_idx, "ScreenEffects must boot AFTER ParticleSystemWrapper (pos 13)")

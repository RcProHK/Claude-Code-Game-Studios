# CameraController — Story 009: autoload position 14 (after ParticleSystemWrapper 13, before
# ScreenEffects 15). Static read of project.godot [autoload] (ADR-0008 ground truth).
# (Shifted 13→14 by #10 Story 005: ExerciseClassMapping inserted at pos 5 — ADR-0008.)
extends GutTest

const PROJECT_GODOT: String = "res://project.godot"


func _read_autoload_order() -> Array[String]:
	var file := FileAccess.open(ProjectSettings.globalize_path(PROJECT_GODOT), FileAccess.READ)
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


func test_camera_controller_is_position_14() -> void:
	var order := _read_autoload_order()
	var cam_idx := order.find("CameraController")
	var psw_idx := order.find("ParticleSystemWrapper")
	var se_idx := order.find("ScreenEffects")
	assert_gt(cam_idx, -1, "CameraController must be a registered autoload")
	assert_eq(cam_idx + 1, 14, "CameraController must be at autoload position 14 (ADR-0008 ground truth)")
	assert_lt(psw_idx, cam_idx, "CameraController boots after ParticleSystemWrapper (pos 13)")
	assert_lt(cam_idx, se_idx, "CameraController boots before ScreenEffects (pos 15)")

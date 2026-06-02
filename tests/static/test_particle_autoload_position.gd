# ParticleSystemWrapper — Story 007 AC-15: autoload position 13, after AvatarRenderer (12).
# (Shifted 12→13 by #10 Story 005: ExerciseClassMapping inserted at pos 5 — ADR-0008.)
#
# Static read of project.godot [autoload] (ADR-0008 — project.godot is the sole ground
# truth for absolute autoload positions). boot ≤80ms is a PERF claim → ADVISORY, deferred
# to VS-tier device profiling (not headless-assertable); only the position invariant is checked.
extends GutTest

const PROJECT_GODOT: String = "res://project.godot"


## Ordered list of autoload key names from the [autoload] section of project.godot.
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


func test_particle_wrapper_is_position_13_after_avatar_renderer() -> void:
	var order := _read_autoload_order()
	var psw_idx := order.find("ParticleSystemWrapper")
	var avatar_idx := order.find("AvatarRenderer")
	assert_gt(psw_idx, -1, "AC-15: ParticleSystemWrapper must be a registered autoload")
	assert_gt(avatar_idx, -1, "AC-15: AvatarRenderer must be a registered autoload")
	# 1-based position == index + 1. ADR-0008 ground truth: pos 13 (after #10 inserted at pos 5).
	assert_eq(psw_idx + 1, 13, "AC-15: ParticleSystemWrapper must be at autoload position 13")
	assert_lt(avatar_idx, psw_idx, "AC-15: ParticleSystemWrapper must boot AFTER AvatarRenderer (pos 12)")

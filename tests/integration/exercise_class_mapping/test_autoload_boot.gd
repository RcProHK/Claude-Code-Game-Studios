# ExerciseClassMapping — #10 Story 005: autoload pos 5 boot + ordering (Integration).
#
# project.godot is the sole ground truth for absolute autoload positions (ADR-0008). #10
# insertion rule: ExerciseClassMapping at pos 5 (after GymSysBackendClient pos 4, before
# StatSystem pos 6); binding constraint 7: ExerciseClassMapping ≺ StatSystem. Combined with
# a runtime check that the singleton actually booted (present at /root), this proves the
# registration took effect, not just that the text is in the file.
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


# --- TC-005-01: autoload pos 5 registered, neighbours intact -----------------------

func test_exercise_class_mapping_is_position_5() -> void:
	var order := _read_autoload_order()
	var ecm_idx := order.find("ExerciseClassMapping")
	assert_gt(ecm_idx, -1, "TC-005-01: ExerciseClassMapping must be a registered autoload")
	assert_eq(ecm_idx + 1, 5, "TC-005-01: ExerciseClassMapping must be at autoload position 5 (ADR-0008 ground truth)")


func test_position_5_neighbours_are_intact() -> void:
	var order := _read_autoload_order()
	var gym_idx := order.find("GymSysBackendClient")
	var ecm_idx := order.find("ExerciseClassMapping")
	var stat_idx := order.find("StatSystem")
	assert_eq(gym_idx + 1, 4, "TC-005-01: GymSysBackendClient stays at pos 4")
	assert_eq(stat_idx + 1, 6, "TC-005-01: StatSystem shifted to pos 6 (was 5)")
	# Binding constraint 7: ExerciseClassMapping ≺ StatSystem.
	assert_lt(gym_idx, ecm_idx, "TC-005-01: ExerciseClassMapping boots AFTER GymSysBackendClient")
	assert_lt(ecm_idx, stat_idx, "TC-005-01: ExerciseClassMapping boots BEFORE StatSystem (constraint 7)")


# --- TC-005-02: no duplicates / no gaps in the autoload list -----------------------

func test_autoload_order_has_no_duplicates() -> void:
	var order := _read_autoload_order()
	var seen: Dictionary = {}
	var dups: Array[String] = []
	for name: String in order:
		if seen.has(name):
			dups.append(name)
		seen[name] = true
	assert_eq(dups, ([] as Array[String]),
		"TC-005-02: autoload list must have no duplicate entries")
	assert_gt(order.size(), 14, "TC-005-02: list grew to 15 entries after #10 insertion")


# --- TC-005-01: runtime boot proof -------------------------------------------------

func test_exercise_class_mapping_singleton_booted() -> void:
	## Stronger than a text read: the autoload node must actually exist at /root after boot,
	## proving project.godot registration took effect at runtime.
	var node := get_node_or_null("/root/ExerciseClassMapping")
	assert_not_null(node, "TC-005-01: ExerciseClassMapping autoload must be present at /root after boot")

# LootDropSystem — Story 014 AC-32: boot order (LootDrop ≺ EnemyDirector) + deferred wiring.
#
# Coverage:
#   AC-32a — LootDropSystem key precedes EnemyDirector key in project.godot autoload section.
#             (HARD constraint per ADR-0008 + check_autoload_boot_order CI lint)
#   AC-32b — After LootDropSystem._ready() (with stub GymSysClient emitting backend_ready),
#             EnemyDirector.enemy_killed.is_connected(_on_enemy_killed_payload) == true.
#   AC-32c — After boot, WorkoutStateTracker.workout_completed_forwarded.is_connected(
#             _on_workout_completed_forwarded) == true.
extends GutTest

const PROJECT_GODOT := "res://project.godot"


# ---------------------------------------------------------------------------
# AC-32a — static boot-order assertion from project.godot text
# ---------------------------------------------------------------------------

## Parse the [autoload] section of project.godot and return an ordered list of autoload key names.
func _read_autoload_order() -> Array[String]:
	var abs := ProjectSettings.globalize_path(PROJECT_GODOT)
	var file := FileAccess.open(abs, FileAccess.READ)
	assert_not_null(file, "project.godot must be readable")
	var in_section := false
	var order: Array[String] = []
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line == "[autoload]":
			in_section = true
			continue
		if in_section and line.begins_with("["):
			break  # next section
		if in_section and "=" in line and not line.begins_with(";"):
			order.append(line.split("=")[0].strip_edges())
	file.close()
	return order


func test_ac32a_loot_drop_precedes_enemy_director_in_project_godot() -> void:
	var order := _read_autoload_order()
	var loot_idx := order.find("LootDropSystem")
	var ed_idx   := order.find("EnemyDirector")
	assert_gt(loot_idx, -1, "AC-32a: LootDropSystem must be in project.godot autoloads")
	assert_gt(ed_idx,   -1, "AC-32a: EnemyDirector must be in project.godot autoloads")
	assert_lt(loot_idx, ed_idx,
		"AC-32a: LootDropSystem MUST precede EnemyDirector (HARD constraint LootDrop ≺ EnemyDirector)")


# ---------------------------------------------------------------------------
# AC-32b/c — post-boot signal connection check
# ---------------------------------------------------------------------------

## Minimal GymSysBackendClient stub — emits backend_ready so LootDrop._ready() can proceed.
class StubGymSysClient:
	extends RefCounted
	signal backend_ready
	func emit_ready() -> void:
		backend_ready.emit()


func test_ac32b_enemy_killed_connected_after_boot() -> void:
	# Arrange: inject stub GymSys into LootDropSystem; temporarily replace _enemy_director.
	var stub_gymsys := StubGymSysClient.new()
	LootDropSystem.set(&"_gymsys_client", stub_gymsys)
	LootDropSystem.set(&"_enemy_director", EnemyDirector)  # use real autoload
	LootDropSystem.set(&"_workout_tracker", WorkoutStateTracker)
	# Act: trigger _ready (re-runs Step 5 wiring).
	stub_gymsys.emit_ready()
	await get_tree().process_frame
	await get_tree().process_frame
	# Assert: handler connected after backend_ready resolved.
	assert_true(
		EnemyDirector.enemy_killed.is_connected(
			Callable(LootDropSystem, "_on_enemy_killed_payload")),
		"AC-32b: EnemyDirector.enemy_killed must be connected to _on_enemy_killed_payload after boot")
	# Cleanup.
	if EnemyDirector.enemy_killed.is_connected(Callable(LootDropSystem, "_on_enemy_killed_payload")):
		EnemyDirector.enemy_killed.disconnect(Callable(LootDropSystem, "_on_enemy_killed_payload"))
	LootDropSystem.set(&"_gymsys_client", null)
	LootDropSystem.set(&"_enemy_director", null)
	LootDropSystem.set(&"_workout_tracker", null)


func test_ac32c_workout_completed_forwarded_connected_after_boot() -> void:
	var stub_gymsys := StubGymSysClient.new()
	LootDropSystem.set(&"_gymsys_client", stub_gymsys)
	LootDropSystem.set(&"_enemy_director", EnemyDirector)
	LootDropSystem.set(&"_workout_tracker", WorkoutStateTracker)
	stub_gymsys.emit_ready()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(
		WorkoutStateTracker.workout_completed_forwarded.is_connected(
			Callable(LootDropSystem, "_on_workout_completed_forwarded")),
		"AC-32c: workout_completed_forwarded must be connected to _on_workout_completed_forwarded after boot")
	# Cleanup.
	if WorkoutStateTracker.workout_completed_forwarded.is_connected(
			Callable(LootDropSystem, "_on_workout_completed_forwarded")):
		WorkoutStateTracker.workout_completed_forwarded.disconnect(
			Callable(LootDropSystem, "_on_workout_completed_forwarded"))
	LootDropSystem.set(&"_gymsys_client", null)
	LootDropSystem.set(&"_enemy_director", null)
	LootDropSystem.set(&"_workout_tracker", null)

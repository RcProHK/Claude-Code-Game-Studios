# EnemyDirector — Story 016 AC-22: light-workout mini-boss cascade param selection (EC-19).
extends GutTest

const BAS = EnemyDirector.BossAnchorState


func before_each() -> void:
	await get_tree().process_frame
	EnemyDirector.set_physics_process(false)
	EnemyDirector.set(&"_boss_anchor_state", BAS.IDLE)
	EnemyDirector.set(&"_boss_node", null)
	EnemyDirector.set(&"_boss_cascade_params", {})


func after_each() -> void:
	EnemyDirector.call("despawn_boss_silently")
	await get_tree().process_frame
	EnemyDirector.set(&"_boss_scene_mini", null)
	EnemyDirector.set(&"_boss_scene_final", null)
	EnemyDirector.set(&"_boss_anchor_state", BAS.IDLE)
	EnemyDirector.set_physics_process(true)


func _make_scene() -> PackedScene:
	var root := Node2D.new()
	var ps := PackedScene.new()
	ps.pack(root)
	root.free()
	return ps


# ---------------------------------------------------------------------------
# AC-22 — cascade param selection
# ---------------------------------------------------------------------------

func test_ac22_light_workout_selects_mini_params() -> void:
	var params: Dictionary = EnemyDirector.call("_select_boss_cascade_params", 2)  # ≤ threshold
	assert_true(params["is_mini"], "AC-22: 2 sets → mini-boss path")
	assert_almost_eq(params["camera_sec"], 0.4, 0.001, "AC-22: mini camera 0.4s (not 0.6)")
	assert_almost_eq(params["shake"], 0.25, 0.001, "AC-22: mini shake 0.25 (not 0.4)")
	assert_almost_eq(params["particle_mult"], 1.0, 0.001, "AC-22: mini particle_mult 1.0 (not 1.2)")


func test_ac22_standard_workout_selects_full_params() -> void:
	var params: Dictionary = EnemyDirector.call("_select_boss_cascade_params", 5)  # > threshold
	assert_false(params["is_mini"], "AC-22: 5 sets → standard boss path")
	assert_almost_eq(params["camera_sec"], 0.6, 0.001, "AC-22: standard camera 0.6s")
	assert_almost_eq(params["shake"], 0.4, 0.001, "AC-22: standard shake 0.4")
	assert_almost_eq(params["particle_mult"], 1.2, 0.001, "AC-22: standard particle_mult 1.2")


## Boundary: exactly LIGHT_WORKOUT_THRESHOLD_SETS (2) is still mini.
func test_ac22_threshold_boundary_is_mini() -> void:
	var params: Dictionary = EnemyDirector.call("_select_boss_cascade_params",
		EnemyDirector.LIGHT_WORKOUT_THRESHOLD_SETS)
	assert_true(params["is_mini"], "AC-22: exactly threshold (2) → mini")
	var params3: Dictionary = EnemyDirector.call("_select_boss_cascade_params",
		EnemyDirector.LIGHT_WORKOUT_THRESHOLD_SETS + 1)
	assert_false(params3["is_mini"], "AC-22: threshold+1 (3) → standard")


# ---------------------------------------------------------------------------
# Scene selection — pre_spawn uses the correct pool per path
# ---------------------------------------------------------------------------

func test_pre_spawn_light_uses_mini_scene() -> void:
	EnemyDirector.set(&"_boss_scene_mini", _make_scene())
	EnemyDirector.set(&"_boss_scene_final", null)  # only mini available
	EnemyDirector.call("pre_spawn_boss", 2)
	assert_not_null(EnemyDirector.get(&"_boss_node"), "mini path instantiated the mini scene")
	assert_true((EnemyDirector.get(&"_boss_cascade_params") as Dictionary)["is_mini"], "is_mini recorded")


func test_pre_spawn_standard_uses_final_scene() -> void:
	EnemyDirector.set(&"_boss_scene_mini", null)  # only final available
	EnemyDirector.set(&"_boss_scene_final", _make_scene())
	EnemyDirector.call("pre_spawn_boss", 5)
	assert_not_null(EnemyDirector.get(&"_boss_node"), "standard path instantiated the final scene")
	assert_false((EnemyDirector.get(&"_boss_cascade_params") as Dictionary)["is_mini"], "is_mini false recorded")

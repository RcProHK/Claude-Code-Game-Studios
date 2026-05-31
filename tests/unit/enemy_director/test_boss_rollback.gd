# EnemyDirector — Story 016 AC-21 rollback + Formula 5 trigger (boss anchor part 1).
extends GutTest

const BAS = EnemyDirector.BossAnchorState


func before_each() -> void:
	await get_tree().process_frame
	EnemyDirector.set_physics_process(false)
	EnemyDirector.set(&"_boss_anchor_state", BAS.IDLE)
	EnemyDirector.set(&"_boss_node", null)
	EnemyDirector.set(&"_boss_cascade_params", {})
	EnemyDirector.get(&"_anomaly_rate_tracker").clear()
	EnemyDirector.set(&"_boss_scene_mini", _make_scene())
	EnemyDirector.set(&"_boss_scene_final", _make_scene())


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
# Formula 5 — IDLE → PRE_SPAWN
# ---------------------------------------------------------------------------

func test_formula5_final_set_high_progress_triggers_pre_spawn() -> void:
	EnemyDirector.call("_check_boss_anchor_state", 0.85, true, 5)
	assert_eq(EnemyDirector.get(&"_boss_anchor_state"), BAS.PRE_SPAWN, "Formula 5: → PRE_SPAWN")
	assert_not_null(EnemyDirector.get(&"_boss_node"), "Formula 5: boss node pre-spawned")


func test_formula5_not_final_set_no_trigger() -> void:
	EnemyDirector.call("_check_boss_anchor_state", 0.85, false, 5)
	assert_eq(EnemyDirector.get(&"_boss_anchor_state"), BAS.IDLE, "Formula 5: not final set → stays IDLE")


func test_formula5_below_threshold_no_trigger() -> void:
	EnemyDirector.call("_check_boss_anchor_state", 0.7, true, 5)
	assert_eq(EnemyDirector.get(&"_boss_anchor_state"), BAS.IDLE, "Formula 5: progress<0.8 → stays IDLE")


# ---------------------------------------------------------------------------
# AC-21 — silent rollback PRE_SPAWN → IDLE
# ---------------------------------------------------------------------------

func test_ac21_progress_drop_rolls_back_silently() -> void:
	# Arrange: get into PRE_SPAWN.
	EnemyDirector.call("_check_boss_anchor_state", 0.85, true, 5)
	assert_eq(EnemyDirector.get(&"_boss_anchor_state"), BAS.PRE_SPAWN, "precondition: PRE_SPAWN")
	watch_signals(EnemyDirector)
	# Act: progress drops below threshold.
	EnemyDirector.call("_check_boss_anchor_state", 0.7, true, 5)
	# Assert: rolled back to IDLE, no signals.
	assert_eq(EnemyDirector.get(&"_boss_anchor_state"), BAS.IDLE, "AC-21: rolled back to IDLE")
	assert_null(EnemyDirector.get(&"_boss_node"), "AC-21: boss node cleared")
	assert_eq(get_signal_emit_count(EnemyDirector, "enemy_killed"), 0,
		"AC-21: NO enemy_killed on silent rollback")
	assert_eq(get_signal_emit_count(EnemyDirector, "combat_metric_anomaly"), 0,
		"AC-21: NO anomaly on legitimate rollback")


func test_despawn_boss_silently_clears_state() -> void:
	EnemyDirector.call("_check_boss_anchor_state", 0.85, true, 5)
	EnemyDirector.call("despawn_boss_silently")
	assert_eq(EnemyDirector.get(&"_boss_anchor_state"), BAS.IDLE, "despawn → IDLE")
	assert_null(EnemyDirector.get(&"_boss_node"), "despawn → boss node null")


## Already PRE_SPAWN with sustained high progress does not re-spawn (idempotent).
func test_pre_spawn_not_retriggered_while_active() -> void:
	EnemyDirector.call("_check_boss_anchor_state", 0.85, true, 5)
	var first_node = EnemyDirector.get(&"_boss_node")
	EnemyDirector.call("_check_boss_anchor_state", 0.90, true, 5)  # still PRE_SPAWN
	assert_eq(EnemyDirector.get(&"_boss_node"), first_node, "PRE_SPAWN not re-triggered (same node)")

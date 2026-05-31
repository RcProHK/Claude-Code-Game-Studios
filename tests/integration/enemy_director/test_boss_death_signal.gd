# EnemyDirector — Story 017 AC-19: boss death emits enemy_killed SAME FRAME, non-boss preserved.
extends GutTest

const ENEMY_ID := &"STRIKE_MOB_T1"
const BOSS_ID := &"BOSS_FINAL"


func before_each() -> void:
	await get_tree().process_frame
	EnemyDirector.set_physics_process(false)
	EnemyDirector.get(&"_enemy_state_pool").clear()
	EnemyDirector.get(&"_killed_dedupe_set").clear()


func after_each() -> void:
	await get_tree().process_frame
	EnemyDirector.get(&"_enemy_state_pool").clear()
	EnemyDirector.set_physics_process(true)


func _kill_result() -> CombatResolver.HitResult:
	var hr := CombatResolver.HitResult.new()
	hr.is_kill = true
	hr.target_hp_after = 0
	hr.ability_id = &"ABILITY_STRIKE_1"
	hr.transition_id = "TX-bosskill-001"
	hr.overkill_excess = 0
	return hr


# ---------------------------------------------------------------------------
# AC-19 — same-frame enemy_killed + non-boss preservation
# ---------------------------------------------------------------------------

func test_ac19_boss_kill_emits_enemy_killed_same_frame() -> void:
	var pool: Dictionary = EnemyDirector.get(&"_enemy_state_pool")
	pool[7001] = EnemyDirector.EnemyState.new(7001, BOSS_ID, 0.0, 2000.0)
	watch_signals(EnemyDirector)
	EnemyDirector.call("_apply_hit_result", 7001, _kill_result())
	# No await — the emit must already be observed (synchronous, not call_deferred).
	assert_eq(get_signal_emit_count(EnemyDirector, "enemy_killed"), 1,
		"AC-19: enemy_killed emitted SAME FRAME (synchronous, not deferred)")
	var payload = get_signal_parameters(EnemyDirector, "enemy_killed")[0]
	assert_eq(payload.enemy_instance_id, 7001, "AC-19: payload carries the boss instance id")
	assert_eq(payload.enemy_id, BOSS_ID, "AC-19: payload carries the boss enemy_id")


func test_ac19_non_boss_enemies_not_force_despawned() -> void:
	var pool: Dictionary = EnemyDirector.get(&"_enemy_state_pool")
	pool[7001] = EnemyDirector.EnemyState.new(7001, BOSS_ID, 0.0, 2000.0)
	pool[1] = EnemyDirector.EnemyState.new(1, ENEMY_ID, 50.0, 80.0)
	pool[2] = EnemyDirector.EnemyState.new(2, ENEMY_ID, 80.0, 80.0)
	pool[3] = EnemyDirector.EnemyState.new(3, ENEMY_ID, 80.0, 80.0)
	EnemyDirector.call("_apply_hit_result", 7001, _kill_result())
	# Non-boss enemies remain in the pool (no force-despawn — narrative continuity).
	assert_true(pool.has(1), "AC-19: non-boss enemy 1 preserved")
	assert_true(pool.has(2), "AC-19: non-boss enemy 2 preserved")
	assert_true(pool.has(3), "AC-19: non-boss enemy 3 preserved")


## A non-kill hit does NOT emit enemy_killed.
func test_non_kill_hit_no_enemy_killed() -> void:
	var pool: Dictionary = EnemyDirector.get(&"_enemy_state_pool")
	pool[5] = EnemyDirector.EnemyState.new(5, ENEMY_ID, 80.0, 80.0)
	var hr := CombatResolver.HitResult.new()
	hr.is_kill = false
	hr.target_hp_after = 40
	watch_signals(EnemyDirector)
	EnemyDirector.call("_apply_hit_result", 5, hr)
	assert_eq(get_signal_emit_count(EnemyDirector, "enemy_killed"), 0,
		"non-kill hit emits no enemy_killed")
	assert_almost_eq((pool[5] as Object).hp, 40.0, 0.001, "non-kill hit updates hp")

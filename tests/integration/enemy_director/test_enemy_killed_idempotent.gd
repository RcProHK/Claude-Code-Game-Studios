# EnemyDirector — Story 019 AC-37: enemy_killed idempotency (Rule 15 / EC-17).
extends GutTest

const ENEMY_ID := &"STRIKE_MOB_T1"


func before_each() -> void:
	await get_tree().process_frame
	EnemyDirector.set_physics_process(false)
	EnemyDirector.get(&"_enemy_state_pool").clear()
	EnemyDirector.get(&"_killed_dedupe_set").clear()
	EnemyDirector.get(&"_anomaly_rate_tracker").clear()


func after_each() -> void:
	await get_tree().process_frame
	EnemyDirector.get(&"_enemy_state_pool").clear()
	EnemyDirector.get(&"_killed_dedupe_set").clear()
	EnemyDirector.set_physics_process(true)


func _kill_result() -> CombatResolver.HitResult:
	var hr := CombatResolver.HitResult.new()
	hr.is_kill = true
	hr.target_hp_after = 0
	hr.ability_id = &"AOE_1"
	hr.transition_id = "TX-dup"
	return hr


# ---------------------------------------------------------------------------
# AC-37 — duplicate kill blocked + DEAD_TARGET_RESOLVE anomaly
# ---------------------------------------------------------------------------

func test_ac37_first_kill_emits_enemy_killed() -> void:
	EnemyDirector.get(&"_enemy_state_pool")[42] = EnemyDirector.EnemyState.new(42, ENEMY_ID)
	watch_signals(EnemyDirector)
	EnemyDirector.call("_emit_enemy_killed", 42, _kill_result())
	assert_eq(get_signal_emit_count(EnemyDirector, "enemy_killed"), 1, "AC-37: first kill emits enemy_killed")
	assert_true((EnemyDirector.get(&"_killed_dedupe_set") as Dictionary).has(42), "AC-37: 42 marked killed")


func test_ac37_duplicate_kill_blocked_and_anomaly_emitted() -> void:
	EnemyDirector.get(&"_enemy_state_pool")[42] = EnemyDirector.EnemyState.new(42, ENEMY_ID)
	EnemyDirector.get(&"_killed_dedupe_set")[42] = true  # already killed
	watch_signals(EnemyDirector)
	EnemyDirector.call("_emit_enemy_killed", 42, _kill_result())
	assert_eq(get_signal_emit_count(EnemyDirector, "enemy_killed"), 0,
		"AC-37: duplicate kill does NOT re-emit enemy_killed")
	assert_signal_emitted(EnemyDirector, "combat_metric_anomaly", "AC-37: DEAD_TARGET_RESOLVE anomaly emitted")
	var payload = get_signal_parameters(EnemyDirector, "combat_metric_anomaly")[0]
	assert_eq(payload.reason, EnemyDirector.REASON_DEAD_TARGET_RESOLVE, "AC-37: reason DEAD_TARGET_RESOLVE")
	assert_true(payload.context_dump.get("duplicate_kill", false), "AC-37: context_dump.duplicate_kill true")


func test_ac37_same_frame_double_resolve_one_kill_one_anomaly() -> void:
	EnemyDirector.get(&"_enemy_state_pool")[42] = EnemyDirector.EnemyState.new(42, ENEMY_ID)
	watch_signals(EnemyDirector)
	# Two resolves on the same id in the same frame (AOE × catch-up race).
	EnemyDirector.call("_emit_enemy_killed", 42, _kill_result())
	EnemyDirector.call("_emit_enemy_killed", 42, _kill_result())
	assert_eq(get_signal_emit_count(EnemyDirector, "enemy_killed"), 1,
		"AC-37: same-frame double-resolve → exactly 1 enemy_killed")
	assert_eq(get_signal_emit_count(EnemyDirector, "combat_metric_anomaly"), 1,
		"AC-37: same-frame double-resolve → exactly 1 DEAD_TARGET_RESOLVE anomaly")


## Despawn clears the dedupe entry (Story 012) — a respawned id can be killed again.
func test_ac37_despawn_clears_dedupe_allowing_future_kill() -> void:
	EnemyDirector.get(&"_enemy_state_pool")[42] = EnemyDirector.EnemyState.new(42, ENEMY_ID)
	EnemyDirector.call("_emit_enemy_killed", 42, _kill_result())  # kill + mark
	EnemyDirector.call("_on_enemy_despawned", 42)  # clears pool + dedupe
	assert_false((EnemyDirector.get(&"_killed_dedupe_set") as Dictionary).has(42),
		"AC-37: despawn cleared the dedupe entry (no unbounded growth)")
	# Re-add + kill again → emits (dedupe was cleared).
	EnemyDirector.get(&"_enemy_state_pool")[42] = EnemyDirector.EnemyState.new(42, ENEMY_ID)
	watch_signals(EnemyDirector)
	EnemyDirector.call("_emit_enemy_killed", 42, _kill_result())
	assert_eq(get_signal_emit_count(EnemyDirector, "enemy_killed"), 1,
		"AC-37: after despawn-clear, the id can be killed again")

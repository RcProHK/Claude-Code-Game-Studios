# EnemyDirector — Story 012 Pool Cleanup / Long-session leak guard (integration)
#
# Coverage:
#   EC-47 — spawn 100 → kill all → despawn all → pool AND dedupe set both empty (no leak).
#   EC-38 — pool + dedupe erased together on each despawn (interleaved spawn/despawn).
#
# Uses _on_enemy_despawned (the tree_exited handler) directly to simulate mass despawn
# without instantiating 100 real scene nodes — the leak invariant is about dictionary
# bookkeeping, which is engine-independent.
extends GutTest


class FakeGSM:
	signal state_changed(from_state: int, to_state: int, payload)
	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)
	func get_current_state() -> int:
		return GameStateMachine.GameState.COMBAT_ACTIVE
	func acquire_transition_id(_from: int, _to: int) -> String:
		return "TX-pool-001"


class FakeAbilitySystem:
	signal ability_cast(ability_id: StringName, caster: Node2D, target: Node2D)
	func connect_for_initial_state(callable: Callable) -> void:
		ability_cast.connect(callable)


func before_each() -> void:
	await get_tree().process_frame
	EnemyDirector.set_physics_process(false)
	EnemyDirector.get(&"_catch_up_queue").clear()
	EnemyDirector.get(&"_anomaly_rate_tracker").clear()
	EnemyDirector.get(&"_enemy_state_pool").clear()
	EnemyDirector.get(&"_killed_dedupe_set").clear()
	EnemyDirector.get(&"_spawn_pool").clear()
	EnemyDirector.set(&"_rng_factory", null)
	EnemyDirector.set(&"_stat_system", null)
	EnemyDirector.set(&"_wst_source", null)
	EnemyDirector.set(&"_spawn_sink", null)
	EnemyDirector.set(&"_gsm_source", FakeGSM.new())
	EnemyDirector.set(&"_ability_source", FakeAbilitySystem.new())
	EnemyDirector.call("_ready")


func after_each() -> void:
	await get_tree().process_frame
	EnemyDirector.set(&"_wave_scheduler_paused", true)
	EnemyDirector.get(&"_enemy_state_pool").clear()
	EnemyDirector.get(&"_killed_dedupe_set").clear()
	EnemyDirector.set(&"_gsm_source", null)
	EnemyDirector.set(&"_ability_source", null)
	EnemyDirector.set(&"_wst_source", null)
	EnemyDirector.set_physics_process(true)


# ---------------------------------------------------------------------------
# EC-47 — 100-enemy long session, no leak
# ---------------------------------------------------------------------------

func test_ec47_spawn_100_despawn_all_leaves_pool_and_dedupe_empty() -> void:
	var pool: Dictionary = EnemyDirector.get(&"_enemy_state_pool")
	var dedupe: Dictionary = EnemyDirector.get(&"_killed_dedupe_set")
	# Simulate 100 spawned + killed enemies.
	for i in 100:
		pool[i] = EnemyDirector.EnemyState.new(i, &"STRIKE_MOB_T1", 0.0, 80.0)
		dedupe[i] = true  # killed
	assert_eq(pool.size(), 100, "precondition: 100 in pool")
	assert_eq(dedupe.size(), 100, "precondition: 100 killed")
	# Despawn all.
	for i in 100:
		EnemyDirector.call("_on_enemy_despawned", i)
	assert_true(pool.is_empty(), "EC-47: pool empty after despawning all 100")
	assert_true(dedupe.is_empty(), "EC-47: dedupe set empty after despawning all 100")


func test_ec47_interleaved_spawn_despawn_no_residue() -> void:
	var pool: Dictionary = EnemyDirector.get(&"_enemy_state_pool")
	var dedupe: Dictionary = EnemyDirector.get(&"_killed_dedupe_set")
	# Interleave: spawn 3, despawn 1, repeated — net should reconcile to 0 at the end.
	var live: Array[int] = []
	var next_id: int = 0
	for _round in 50:
		for _s in 3:
			pool[next_id] = EnemyDirector.EnemyState.new(next_id, &"STRIKE_MOB_T1")
			dedupe[next_id] = true
			live.append(next_id)
			next_id += 1
		var victim: int = live.pop_front()
		EnemyDirector.call("_on_enemy_despawned", victim)
	# Despawn the rest.
	for id in live:
		EnemyDirector.call("_on_enemy_despawned", id)
	assert_true(pool.is_empty(), "EC-47: interleaved spawn/despawn leaves no pool residue")
	assert_true(dedupe.is_empty(), "EC-47: interleaved spawn/despawn leaves no dedupe residue")


func test_ec38_despawn_unknown_instance_is_safe() -> void:
	# Despawning an id never tracked must not crash or create entries.
	EnemyDirector.call("_on_enemy_despawned", 123456)
	assert_true((EnemyDirector.get(&"_enemy_state_pool") as Dictionary).is_empty(),
		"EC-38: despawning an unknown id is a safe no-op")

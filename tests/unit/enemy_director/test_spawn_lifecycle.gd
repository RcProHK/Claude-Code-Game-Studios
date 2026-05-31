# EnemyDirector — Story 012 Enemy Spawn + Lifecycle (unit)
#
# Coverage:
#   Spawn flow  — sub-RNG jitter, PackedScene instantiate, EnemyState insert (hp=max_hp), one-shot connect.
#   Despawn     — _on_enemy_despawned erases pool + dedupe (EC-38).
#   HP update   — _apply_hit_result mutates pool hp (Rule 3); guard for absent instance.
#
# EnemyDirector autoload _physics_process disabled per test (determinism). _spawn_sink is
# left null so the REAL spawn path runs (Story 011 tests inject the sink for the hook path).
extends GutTest


class FakeGSM:
	signal state_changed(from_state: int, to_state: int, payload)
	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)
	func get_current_state() -> int:
		return GameStateMachine.GameState.COMBAT_ACTIVE
	func acquire_transition_id(_from: int, _to: int) -> String:
		return "TX-spawn-001"


class FakeAbilitySystem:
	signal ability_cast(ability_id: StringName, caster: Node2D, target: Node2D)
	func connect_for_initial_state(callable: Callable) -> void:
		ability_cast.connect(callable)


const ENEMY_ID: StringName = &"STRIKE_MOB_T1"


func before_each() -> void:
	await get_tree().process_frame
	EnemyDirector.set_physics_process(false)
	EnemyDirector.get(&"_catch_up_queue").clear()
	EnemyDirector.get(&"_anomaly_rate_tracker").clear()
	EnemyDirector.get(&"_enemy_state_pool").clear()
	EnemyDirector.get(&"_killed_dedupe_set").clear()
	EnemyDirector.get(&"_spawn_pool").clear()
	EnemyDirector.set(&"_rng_factory", null)
	EnemyDirector.set(&"_active_wave", null)
	EnemyDirector.set(&"_boss_anchor_state", EnemyDirector.BossAnchorState.IDLE)
	EnemyDirector.set(&"_stat_system", null)
	EnemyDirector.set(&"_wst_source", null)
	EnemyDirector.set(&"_spawn_sink", null)  # real spawn path
	EnemyDirector.set(&"_gsm_source", FakeGSM.new())
	EnemyDirector.set(&"_ability_source", FakeAbilitySystem.new())
	EnemyDirector.call("_ready")


func after_each() -> void:
	# Free any leftover spawned children (real nodes added to the autoload).
	for child in EnemyDirector.get_children():
		if child is Node2D:
			child.free()
	await get_tree().process_frame
	EnemyDirector.set(&"_wave_scheduler_paused", true)
	EnemyDirector.get(&"_enemy_state_pool").clear()
	EnemyDirector.get(&"_killed_dedupe_set").clear()
	EnemyDirector.get(&"_spawn_pool").clear()
	EnemyDirector.set(&"_gsm_source", null)
	EnemyDirector.set(&"_ability_source", null)
	EnemyDirector.set(&"_wst_source", null)
	EnemyDirector.set_physics_process(true)


func _make_packed_scene() -> PackedScene:
	var root := Node2D.new()
	var ps := PackedScene.new()
	ps.pack(root)
	root.free()
	return ps


func _make_wave() -> WaveDescriptor:
	var wd := WaveDescriptor.new()
	wd.enemy_templates = [ENEMY_ID] as Array[StringName]
	wd.faction = 1
	wd.max_hp = [80, 220, 540] as Array[int]
	wd.defense = [8, 18, 32] as Array[int]
	wd.archetype_cadence_mult = 1.0
	return wd


# ---------------------------------------------------------------------------
# Spawn flow
# ---------------------------------------------------------------------------

func test_spawn_inserts_enemy_state_with_hp_equal_max_hp() -> void:
	EnemyDirector.get(&"_spawn_pool")[ENEMY_ID] = _make_packed_scene()
	EnemyDirector.call("_spawn_enemy", _make_wave())
	var pool: Dictionary = EnemyDirector.get(&"_enemy_state_pool")
	assert_eq(pool.size(), 1, "spawn: one EnemyState inserted into the pool")
	var state = pool.values()[0]
	assert_eq(state.enemy_id, ENEMY_ID, "spawn: enemy_id recorded")
	assert_almost_eq(state.hp, 80.0, 0.001, "spawn: hp initialised to tier-0 max_hp (80)")
	assert_almost_eq(state.max_hp, 80.0, 0.001, "spawn: max_hp = tier-0 (80)")
	assert_almost_eq(state.defense, 8.0, 0.001, "spawn: defense = tier-0 (8)")
	assert_eq(state.faction, 1, "spawn: faction = 1 (ENEMY)")
	assert_eq(state.ai_state, EnemyDirector.EnemyAIState.SPAWNING, "spawn: ai_state = SPAWNING")


func test_spawn_instantiates_scene_as_child_with_jittered_position() -> void:
	EnemyDirector.get(&"_spawn_pool")[ENEMY_ID] = _make_packed_scene()
	var children_before: int = EnemyDirector.get_child_count()
	EnemyDirector.call("_spawn_enemy", _make_wave())
	assert_eq(EnemyDirector.get_child_count(), children_before + 1, "spawn: scene added as child")
	# Find the spawned Node2D; X within jitter band, Y at spawn origin.
	var spawned: Node2D = null
	for child in EnemyDirector.get_children():
		if child is Node2D:
			spawned = child
	assert_not_null(spawned, "spawn: a Node2D child exists")
	assert_almost_eq(spawned.position.y, EnemyDirector.SPAWN_ORIGIN.y, 0.001, "spawn: Y at origin")
	var dx: float = absf(spawned.position.x - EnemyDirector.SPAWN_ORIGIN.x)
	assert_lte(dx, EnemyDirector.SPAWN_JITTER_X, "spawn: X within ±jitter band")


func test_spawn_skips_when_no_preloaded_scene() -> void:
	# _spawn_pool empty → cannot instantiate → no pool entry, no crash.
	EnemyDirector.call("_spawn_enemy", _make_wave())
	assert_eq((EnemyDirector.get(&"_enemy_state_pool") as Dictionary).size(), 0,
		"spawn: no scene → no spawn")


func test_spawn_is_deterministic_for_same_seq_and_transition() -> void:
	# Same transition_id + same wave_seq → identical jitter (sub-RNG determinism).
	EnemyDirector.get(&"_spawn_pool")[ENEMY_ID] = _make_packed_scene()
	EnemyDirector.call("_spawn_enemy", _make_wave())
	var first_x: float = _last_spawned_x()
	# Reset pool/children + wave_seq to reproduce the exact same draw.
	for child in EnemyDirector.get_children():
		if child is Node2D:
			child.free()
	EnemyDirector.get(&"_enemy_state_pool").clear()
	EnemyDirector.set(&"_wave_seq_counter", 0)
	EnemyDirector.get(&"_spawn_pool")[ENEMY_ID] = _make_packed_scene()
	EnemyDirector.call("_spawn_enemy", _make_wave())
	var second_x: float = _last_spawned_x()
	assert_almost_eq(first_x, second_x, 0.0001,
		"spawn: same transition_id + wave_seq → identical jitter (deterministic)")


func _last_spawned_x() -> float:
	var spawned: Node2D = null
	for child in EnemyDirector.get_children():
		if child is Node2D:
			spawned = child
	return spawned.position.x if spawned != null else NAN


# ---------------------------------------------------------------------------
# Despawn (EC-38)
# ---------------------------------------------------------------------------

func test_despawn_erases_pool_and_dedupe_entries() -> void:
	EnemyDirector.get(&"_enemy_state_pool")[42] = EnemyDirector.EnemyState.new(42, ENEMY_ID)
	EnemyDirector.get(&"_killed_dedupe_set")[42] = true
	EnemyDirector.call("_on_enemy_despawned", 42)
	assert_false((EnemyDirector.get(&"_enemy_state_pool") as Dictionary).has(42),
		"EC-38: pool entry erased")
	assert_false((EnemyDirector.get(&"_killed_dedupe_set") as Dictionary).has(42),
		"EC-38: dedupe entry erased")


func test_real_tree_exited_triggers_cleanup() -> void:
	EnemyDirector.get(&"_spawn_pool")[ENEMY_ID] = _make_packed_scene()
	EnemyDirector.call("_spawn_enemy", _make_wave())
	var pool: Dictionary = EnemyDirector.get(&"_enemy_state_pool")
	assert_eq(pool.size(), 1, "precondition: one enemy spawned")
	var spawned: Node2D = null
	for child in EnemyDirector.get_children():
		if child is Node2D:
			spawned = child
	spawned.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(pool.size(), 0, "Story 012 (d): tree_exited one-shot cleanup erased the pool entry")


# ---------------------------------------------------------------------------
# HP update (Rule 3)
# ---------------------------------------------------------------------------

func test_apply_hit_result_updates_pool_hp() -> void:
	EnemyDirector.get(&"_enemy_state_pool")[7] = EnemyDirector.EnemyState.new(7, ENEMY_ID, 100.0, 100.0)
	var hr := CombatResolver.HitResult.new()
	hr.target_hp_after = 65
	EnemyDirector.call("_apply_hit_result", 7, hr)
	assert_almost_eq((EnemyDirector.get(&"_enemy_state_pool")[7] as Object).hp, 65.0, 0.001,
		"Rule 3: pool hp updated to target_hp_after")


func test_apply_hit_result_absent_instance_is_noop() -> void:
	var hr := CombatResolver.HitResult.new()
	hr.target_hp_after = 50
	EnemyDirector.call("_apply_hit_result", 999, hr)  # not in pool
	assert_eq((EnemyDirector.get(&"_enemy_state_pool") as Dictionary).size(), 0,
		"Rule 3: hit for absent instance is a safe no-op (no crash, no insert)")

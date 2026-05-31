# EnemyDirector — Story 018 AC-35: full _on_ability_cast AOE pipeline end-to-end.
extends GutTest

const ENEMY_ID := &"STRIKE_MOB_T1"


## Resolver spy — records every ctx and returns a HitResult (is_kill controlled per target_id).
class ResolverSpy:
	var call_count: int = 0
	var seen_ctx: Array = []
	var kill_ids: Dictionary = {}  # instance_id → true
	func resolve_hit(ctx) -> CombatResolver.HitResult:
		call_count += 1
		seen_ctx.append(ctx)
		var hr := CombatResolver.HitResult.new()
		hr.is_kill = kill_ids.has(ctx.target_state.instance_id)
		hr.target_hp_after = 0 if hr.is_kill else 10
		hr.ability_id = ctx.ability_id
		hr.transition_id = ctx.transition_id
		return hr


class FakeStatSpy:
	var call_count: int = 0
	func get_stat(_id: StringName) -> float:
		call_count += 1
		return 10.0


class FakeGSM:
	signal state_changed(from_state: int, to_state: int, payload)
	func connect_for_initial_state(c: Callable) -> void:
		state_changed.connect(c)
	func get_current_state() -> int:
		return GameStateMachine.GameState.COMBAT_ACTIVE
	func acquire_transition_id(_f: int, _t: int) -> String:
		return "TX-aoe-001"


class FakeAbilitySystem:
	signal ability_cast(ability_id: StringName, caster: Node2D, target: Node2D)
	func connect_for_initial_state(c: Callable) -> void:
		ability_cast.connect(c)


var _resolver: ResolverSpy
var _stat: FakeStatSpy
var _caster: Node2D


func before_each() -> void:
	await get_tree().process_frame
	EnemyDirector.set_physics_process(false)
	EnemyDirector.get(&"_enemy_state_pool").clear()
	EnemyDirector.get(&"_killed_dedupe_set").clear()
	EnemyDirector.get(&"_anomaly_rate_tracker").clear()
	EnemyDirector.set(&"_rng_factory", null)
	EnemyDirector.set(&"_stat_system", null)
	_resolver = ResolverSpy.new()
	_stat = FakeStatSpy.new()
	EnemyDirector.set(&"_gsm_source", FakeGSM.new())
	EnemyDirector.set(&"_ability_source", FakeAbilitySystem.new())
	EnemyDirector.set(&"_stat_system", _stat)
	EnemyDirector.set(&"_combat_resolver", _resolver)
	EnemyDirector.call("_ready")
	EnemyDirector.set(&"_stat_system", _stat)  # re-assert after _ready resolves seams
	EnemyDirector.set(&"_combat_resolver", _resolver)
	_caster = Node2D.new()
	add_child_autofree(_caster)
	# 5 targets in the pool (fake ids; ≤8 so no position lookup needed).
	var pool: Dictionary = EnemyDirector.get(&"_enemy_state_pool")
	for i in range(1, 6):
		pool[i] = EnemyDirector.EnemyState.new(i, ENEMY_ID, 80.0, 80.0, 5.0)


func after_each() -> void:
	await get_tree().process_frame
	EnemyDirector.get(&"_enemy_state_pool").clear()
	EnemyDirector.get(&"_killed_dedupe_set").clear()
	EnemyDirector.set(&"_combat_resolver", null)
	EnemyDirector.set(&"_gsm_source", null)
	EnemyDirector.set(&"_ability_source", null)
	EnemyDirector.set(&"_stat_system", null)
	EnemyDirector.set_physics_process(true)


# ---------------------------------------------------------------------------
# AC-35 — full pipeline (no kills)
# ---------------------------------------------------------------------------

func test_ac35a_stat_called_exactly_twice() -> void:
	EnemyDirector.call("_on_ability_cast", &"AOE_1", _caster, null)
	assert_eq(_stat.call_count, 2, "AC-35a: get_stat called exactly 2× (ATTACK_POWER + CRIT_CHANCE)")


func test_ac35b_resolve_hit_called_per_target() -> void:
	EnemyDirector.call("_on_ability_cast", &"AOE_1", _caster, null)
	assert_eq(_resolver.call_count, 5, "AC-35b: resolve_hit called exactly 5× (1 per target)")


func test_ac35c_five_hit_resolved_emitted() -> void:
	watch_signals(EnemyDirector)
	EnemyDirector.call("_on_ability_cast", &"AOE_1", _caster, null)
	assert_eq(get_signal_emit_count(EnemyDirector, "hit_resolved"), 5, "AC-35c: 5 hit_resolved signals")


func test_ac35d_all_ctx_share_same_snapshot() -> void:
	EnemyDirector.call("_on_ability_cast", &"AOE_1", _caster, null)
	assert_eq(_resolver.seen_ctx.size(), 5, "precondition: 5 ctx captured")
	var first_snap = _resolver.seen_ctx[0].caster_stats
	for ctx in _resolver.seen_ctx:
		assert_true(is_same(ctx.caster_stats, first_snap),
			"AC-35d: all AOE ctx share the SAME caster_stats snapshot reference")


func test_ac35_no_kills_no_enemy_killed() -> void:
	watch_signals(EnemyDirector)
	EnemyDirector.call("_on_ability_cast", &"AOE_1", _caster, null)
	assert_eq(get_signal_emit_count(EnemyDirector, "enemy_killed"), 0,
		"AC-35: no kills → 0 enemy_killed")


# ---------------------------------------------------------------------------
# AC-35e — kill dedupe
# ---------------------------------------------------------------------------

func test_ac35e_enemy_killed_once_per_instance() -> void:
	_resolver.kill_ids = {1: true, 2: true}
	watch_signals(EnemyDirector)
	EnemyDirector.call("_on_ability_cast", &"AOE_1", _caster, null)
	assert_eq(get_signal_emit_count(EnemyDirector, "enemy_killed"), 2,
		"AC-35e: exactly 2 enemy_killed (instance 1 and 2)")


func test_ac35e_dedupe_blocks_double_kill_emit() -> void:
	# Pre-mark instance 1 as already killed → only instance 2 should emit.
	EnemyDirector.get(&"_killed_dedupe_set")[1] = true
	_resolver.kill_ids = {1: true, 2: true}
	watch_signals(EnemyDirector)
	EnemyDirector.call("_on_ability_cast", &"AOE_1", _caster, null)
	assert_eq(get_signal_emit_count(EnemyDirector, "enemy_killed"), 1,
		"AC-35e: dedupe blocks the already-killed instance — only 1 new enemy_killed")

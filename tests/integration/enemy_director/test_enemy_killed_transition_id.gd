# EnemyDirector — Story 019 AC-36: enemy_killed.transition_id verbatim (LootDrop RNG seed).
extends GutTest

const ENEMY_ID := &"STRIKE_MOB_T1"
const KNOWN_TX := "TX-test-kill"


class ResolverKillSpy:
	func resolve_hit(ctx) -> CombatResolver.HitResult:
		var hr := CombatResolver.HitResult.new()
		hr.is_kill = true
		hr.target_hp_after = 0
		hr.ability_id = ctx.ability_id
		hr.transition_id = ctx.transition_id  # resolver echoes ctx.transition_id (matches real resolver)
		return hr


class FakeStat:
	func get_stat(_id: StringName) -> float:
		return 10.0


class FakeGSM:
	signal state_changed(from_state: int, to_state: int, payload)
	func connect_for_initial_state(c: Callable) -> void:
		state_changed.connect(c)
	func get_current_state() -> int:
		return GameStateMachine.GameState.COMBAT_ACTIVE
	func acquire_transition_id(_f: int, _t: int) -> String:
		return KNOWN_TX


class FakeAbility:
	signal ability_cast(ability_id: StringName, caster: Node2D, target: Node2D)
	func connect_for_initial_state(c: Callable) -> void:
		ability_cast.connect(c)


var _caster: Node2D


func before_each() -> void:
	await get_tree().process_frame
	EnemyDirector.set_physics_process(false)
	EnemyDirector.get(&"_enemy_state_pool").clear()
	EnemyDirector.get(&"_killed_dedupe_set").clear()
	EnemyDirector.get(&"_anomaly_rate_tracker").clear()
	EnemyDirector.set(&"_rng_factory", null)
	EnemyDirector.set(&"_stat_system", null)
	EnemyDirector.set(&"_gsm_source", FakeGSM.new())
	EnemyDirector.set(&"_ability_source", FakeAbility.new())
	EnemyDirector.set(&"_stat_system", FakeStat.new())
	EnemyDirector.set(&"_combat_resolver", ResolverKillSpy.new())
	EnemyDirector.call("_ready")
	EnemyDirector.set(&"_stat_system", FakeStat.new())
	EnemyDirector.set(&"_combat_resolver", ResolverKillSpy.new())
	_caster = Node2D.new()
	add_child_autofree(_caster)
	EnemyDirector.get(&"_enemy_state_pool")[1] = EnemyDirector.EnemyState.new(1, ENEMY_ID, 80.0, 80.0)


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
# AC-36 — transition_id flows verbatim
# ---------------------------------------------------------------------------

func test_ac36_enemy_killed_carries_verbatim_transition_id() -> void:
	watch_signals(EnemyDirector)
	EnemyDirector.call("_on_ability_cast", &"AOE_1", _caster, null)
	assert_eq(get_signal_emit_count(EnemyDirector, "enemy_killed"), 1, "precondition: kill emitted")
	var payload = get_signal_parameters(EnemyDirector, "enemy_killed")[0]
	assert_eq(payload.transition_id, KNOWN_TX,
		"AC-36: enemy_killed.transition_id == ctx.transition_id verbatim (LootDrop RNG seed)")


func test_ac36_payload_carries_enemy_identity() -> void:
	watch_signals(EnemyDirector)
	EnemyDirector.call("_on_ability_cast", &"AOE_1", _caster, null)
	var payload = get_signal_parameters(EnemyDirector, "enemy_killed")[0]
	assert_eq(payload.enemy_instance_id, 1, "AC-36: payload enemy_instance_id == 1")
	assert_eq(payload.enemy_id, ENEMY_ID, "AC-36: payload enemy_id from pool entry")

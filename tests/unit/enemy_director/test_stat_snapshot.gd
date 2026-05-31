# EnemyDirector — Story 008 _build_stat_snapshot: AC-4
#
# Coverage:
#   AC-4 — _build_stat_snapshot() calls StatSystem.get_stat() exactly 2 times
#           (ATTACK_POWER + CRIT_CHANCE). Same StatSnapshot reference shared across
#           all CombatContext objects built from one cast (AOE mid-cast drift prevention).
extends GutTest


## StatSystem spy — counts and records get_stat() calls.
class FakeStatSystemSpy:
	var call_count: int = 0
	var called_ids: Array[StringName] = []
	func get_stat(stat_id: StringName) -> float:
		call_count += 1
		called_ids.append(stat_id)
		match stat_id:
			StatSystem.StatId.ATTACK_POWER:
				return 28.0
			StatSystem.StatId.CRIT_CHANCE:
				return 0.015
			_:
				return 0.0


class FakeGSM:
	signal state_changed(from_state: int, to_state: int, payload)
	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)
	func get_current_state() -> int:
		return GameStateMachine.GameState.COMBAT_ACTIVE
	func acquire_transition_id(_from: int, _to: int) -> String:
		return "TX-snap-001"


class FakeAbilitySystem:
	signal ability_cast(ability_id: StringName, caster: Node2D, target: Node2D)
	func connect_for_initial_state(callable: Callable) -> void:
		ability_cast.connect(callable)


class FakeEnemyRegistry:
	func get_preloaded_pool() -> Dictionary:
		return {&"STRIKE_MOB_T1": null}


var _stat_spy: FakeStatSystemSpy


func before_each() -> void:
	await get_tree().process_frame
	EnemyDirector.get(&"_catch_up_queue").clear()
	EnemyDirector.get(&"_anomaly_rate_tracker").clear()
	EnemyDirector.get(&"_enemy_state_pool").clear()
	EnemyDirector.get(&"_killed_dedupe_set").clear()
	EnemyDirector.get(&"_spawn_pool").clear()
	EnemyDirector.set(&"_rng_factory", null)
	EnemyDirector.set(&"_active_wave", null)
	EnemyDirector.set(&"_boss_anchor_state", EnemyDirector.BossAnchorState.IDLE)
	EnemyDirector.set(&"_stat_system", null)
	_stat_spy = FakeStatSystemSpy.new()
	var fake_gsm := FakeGSM.new()
	var fake_ability := FakeAbilitySystem.new()
	var fake_registry := FakeEnemyRegistry.new()
	EnemyDirector.set(&"_gsm_source", fake_gsm)
	EnemyDirector.set(&"_ability_source", fake_ability)
	EnemyDirector.set(&"_stat_system", _stat_spy)
	EnemyDirector.set(&"_enemy_registry", fake_registry)
	EnemyDirector.call("_ready")


func after_each() -> void:
	await get_tree().process_frame
	EnemyDirector.set(&"_gsm_source", null)
	EnemyDirector.set(&"_ability_source", null)
	EnemyDirector.set(&"_stat_system", null)
	EnemyDirector.set(&"_enemy_registry", null)


# ---------------------------------------------------------------------------
# AC-4 — _build_stat_snapshot: exactly 2 get_stat() calls + correct values
# ---------------------------------------------------------------------------

## _build_stat_snapshot() calls get_stat() exactly 2 times.
func test_ac4_build_stat_snapshot_calls_get_stat_exactly_twice() -> void:
	EnemyDirector.call("_on_ability_cast", &"ABILITY_STRIKE_1", Node2D.new(), null)
	assert_eq(_stat_spy.call_count, 2,
		"AC-4: _build_stat_snapshot() must call get_stat() exactly 2 times (ATTACK_POWER + CRIT_CHANCE)")


## _build_stat_snapshot() queries ATTACK_POWER and CRIT_CHANCE specifically.
func test_ac4_build_stat_snapshot_queries_attack_power_and_crit_chance() -> void:
	EnemyDirector.call("_on_ability_cast", &"ABILITY_STRIKE_1", Node2D.new(), null)
	assert_true(_stat_spy.called_ids.has(StatSystem.StatId.ATTACK_POWER),
		"AC-4: get_stat must be called with ATTACK_POWER")
	assert_true(_stat_spy.called_ids.has(StatSystem.StatId.CRIT_CHANCE),
		"AC-4: get_stat must be called with CRIT_CHANCE")


## _build_stat_snapshot() returns snapshot with correct values from StatSystem.
func test_ac4_snapshot_values_match_stat_system_output() -> void:
	var snapshot := EnemyDirector.call("_build_stat_snapshot") as CombatResolver.StatSnapshot
	assert_not_null(snapshot, "AC-4: _build_stat_snapshot() must return non-null StatSnapshot")
	assert_almost_eq(snapshot.attack_power, 28.0, 0.001,
		"AC-4: snapshot.attack_power must match StatSystem.get_stat(ATTACK_POWER)")
	assert_almost_eq(snapshot.crit_chance, 0.015, 0.0001,
		"AC-4: snapshot.crit_chance must match StatSystem.get_stat(CRIT_CHANCE)")


## Each call to _build_stat_snapshot() calls get_stat() exactly 2 times (no caching leak).
func test_ac4_repeated_snapshot_calls_always_2_stats() -> void:
	EnemyDirector.call("_build_stat_snapshot")
	EnemyDirector.call("_build_stat_snapshot")
	assert_eq(_stat_spy.call_count, 4,
		"AC-4: Two _build_stat_snapshot() calls must each call get_stat() exactly 2×")


## Same snapshot reference can be shared — two builds produce independent objects.
## (Shared snapshot identity is enforced in Story 018 AOE loop; here we verify
## _build_stat_snapshot returns a distinct, fresh StatSnapshot each call.)
func test_ac4_snapshot_is_ref_counted_and_independent_per_call() -> void:
	var snap_a := EnemyDirector.call("_build_stat_snapshot") as CombatResolver.StatSnapshot
	var snap_b := EnemyDirector.call("_build_stat_snapshot") as CombatResolver.StatSnapshot
	assert_false(is_same(snap_a, snap_b),
		"AC-4: each _build_stat_snapshot() call must return a distinct object (not cached)")
	# Mutating one must not affect the other.
	snap_a.attack_power = 999.0
	assert_almost_eq(snap_b.attack_power, 28.0, 0.001,
		"AC-4: StatSnapshot instances must be independent (RefCounted value semantics)")

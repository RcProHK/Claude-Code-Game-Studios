# EnemyDirector — Story 011 Wave Archetype Scheduler (Rule 12 + Formula 1)
#
# Coverage:
#   EC-09    — UNKNOWN dominant class → STRIKE fallback + UNKNOWN_ABILITY_CLASS_FALLBACK anomaly.
#   EC-10    — registry lookup null → REGISTRY_LOOKUP_NULL anomaly + skip wave + no spawn.
#   EC-11    — pool cap (6): spawn paused at cap, resumes below (positive control), no anomaly.
#   EC-13    — REST_PERIOD → scheduler paused + pool enemies AI state→IDLE + preserved.
#   Formula 1 — actual_spawn_interval = BASE × archetype_cadence_mult (MOBILITY=3.0, STRIKE=4.0).
#   INV-1    — floor MIN_SPAWN_INTERVAL=2.25 positioned below real min (3.0), above sub-floor (2.0).
#
# EnemyDirector autoload _physics_process is disabled per test for determinism; the scheduler
# is driven explicitly via _spawn_cadence_tick / _on_state_changed / _compute_spawn_interval.
extends GutTest


class FakeWST:
	## Default UNKNOWN (3) to mirror production WorkoutStateTracker's default; each test
	## sets _dominant explicitly for the case under test.
	var _dominant: int = 3  # AbilityClass.UNKNOWN ordinal
	func get_dominant_ability_class() -> int:
		return _dominant


class FakeGSM:
	signal state_changed(from_state: int, to_state: int, payload)
	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)
	func get_current_state() -> int:
		return GameStateMachine.GameState.COMBAT_ACTIVE
	func acquire_transition_id(_from: int, _to: int) -> String:
		return "TX-wave-001"


class FakeAbilitySystem:
	signal ability_cast(ability_id: StringName, caster: Node2D, target: Node2D)
	func connect_for_initial_state(callable: Callable) -> void:
		ability_cast.connect(callable)


class FakeSpawnSink:
	var spawned: Array = []
	func spawn(wave) -> void:
		spawned.append(wave)


## Duck-typed enemy with a settable ai_state (stands in for Story 012's EnemyState).
class MockEnemy:
	var ai_state: int = 99  # sentinel != EnemyAIState.IDLE


var _fake_wst: FakeWST
var _fake_sink: FakeSpawnSink
var _strike_wd: WaveDescriptor
var _mobility_wd: WaveDescriptor


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

	_fake_wst = FakeWST.new()
	_fake_sink = FakeSpawnSink.new()
	_strike_wd = _make_descriptor(1.0)
	_mobility_wd = _make_descriptor(0.75)
	var registry: EnemyRegistry = _make_registry({&"STRIKE": _strike_wd, &"MOBILITY": _mobility_wd})

	EnemyDirector.set(&"_gsm_source", FakeGSM.new())
	EnemyDirector.set(&"_ability_source", FakeAbilitySystem.new())
	EnemyDirector.set(&"_wst_source", _fake_wst)
	EnemyDirector.set(&"_enemy_registry", registry)
	EnemyDirector.set(&"_spawn_sink", _fake_sink)
	EnemyDirector.call("_ready")


func after_each() -> void:
	await get_tree().process_frame
	# Re-pause so the live autoload _physics_process is a no-op once seams are nulled +
	# physics is re-enabled (otherwise the scheduler ticks with a null _wst_source).
	EnemyDirector.set(&"_wave_scheduler_paused", true)
	EnemyDirector.get(&"_enemy_state_pool").clear()
	EnemyDirector.set(&"_gsm_source", null)
	EnemyDirector.set(&"_ability_source", null)
	EnemyDirector.set(&"_wst_source", null)
	EnemyDirector.set(&"_enemy_registry", null)
	EnemyDirector.set(&"_spawn_sink", null)
	EnemyDirector.set(&"_active_wave", null)
	EnemyDirector.set_physics_process(true)


func _make_descriptor(cadence_mult: float) -> WaveDescriptor:
	var wd := WaveDescriptor.new()
	wd.archetype_cadence_mult = cadence_mult
	wd.faction = 1
	wd.spawn_cadence_sec = 2.0
	wd.enemy_templates = [&"MOB_T1"] as Array[StringName]
	return wd


## Minimal registry double exposing an `archetypes` Dictionary (matches EnemyRegistry API).
func _make_registry(archetypes: Dictionary) -> EnemyRegistry:
	var reg := EnemyRegistry.new()
	reg.archetypes = archetypes
	return reg


func _fill_pool(count: int) -> void:
	var pool: Dictionary = EnemyDirector.get(&"_enemy_state_pool")
	for i in count:
		pool[i] = MockEnemy.new()


# ---------------------------------------------------------------------------
# Formula 1
# ---------------------------------------------------------------------------

func test_formula1_strike_interval_is_4() -> void:
	assert_almost_eq(EnemyDirector.call("_compute_spawn_interval", _strike_wd), 4.0, 0.001,
		"Formula 1: STRIKE interval = 4.0 × 1.0 = 4.0")


func test_formula1_mobility_interval_is_3() -> void:
	assert_almost_eq(EnemyDirector.call("_compute_spawn_interval", _mobility_wd), 3.0, 0.001,
		"Formula 1: MOBILITY interval = 4.0 × 0.75 = 3.0")


## INV-1: the floor sits below the real minimum (3.0) but above a sub-floor product (2.0),
## so a future out-of-range mult would trip the production assert.
func test_inv1_floor_constant_positioned() -> void:
	var real_min: float = EnemyDirector.BASE_SPAWN_INTERVAL * 0.75
	var sub_floor: float = EnemyDirector.BASE_SPAWN_INTERVAL * 0.5
	assert_gte(real_min, EnemyDirector.MIN_SPAWN_INTERVAL, "INV-1: real min 3.0 ≥ floor 2.25")
	assert_lt(sub_floor, EnemyDirector.MIN_SPAWN_INTERVAL, "INV-1: sub-floor 2.0 < floor 2.25 (would assert)")


# ---------------------------------------------------------------------------
# EC-09 — UNKNOWN dominant class fallback
# ---------------------------------------------------------------------------

func test_ec09_unknown_class_falls_back_to_strike() -> void:
	_fake_wst._dominant = AbilitySystem.AbilityClass.UNKNOWN
	var key: StringName = EnemyDirector.call("_select_archetype_key")
	assert_eq(key, &"STRIKE", "EC-09: UNKNOWN dominant class falls back to STRIKE")


func test_ec09_unknown_class_emits_fallback_anomaly() -> void:
	_fake_wst._dominant = AbilitySystem.AbilityClass.UNKNOWN
	watch_signals(EnemyDirector)
	EnemyDirector.call("_select_archetype_key")
	assert_signal_emitted(EnemyDirector, "combat_metric_anomaly", "EC-09: anomaly emitted")
	var payload = get_signal_parameters(EnemyDirector, "combat_metric_anomaly")[0]
	assert_eq(payload.reason, EnemyDirector.REASON_UNKNOWN_ABILITY_CLASS_FALLBACK,
		"EC-09: reason UNKNOWN_ABILITY_CLASS_FALLBACK")


func test_ec09_known_class_no_anomaly() -> void:
	_fake_wst._dominant = AbilitySystem.AbilityClass.MOBILITY
	watch_signals(EnemyDirector)
	var key: StringName = EnemyDirector.call("_select_archetype_key")
	assert_eq(key, &"MOBILITY", "EC-09: known class maps directly")
	assert_eq(get_signal_emit_count(EnemyDirector, "combat_metric_anomaly"), 0,
		"EC-09: no anomaly for a known class")


# ---------------------------------------------------------------------------
# EC-10 — registry lookup null
# ---------------------------------------------------------------------------

func test_ec10_null_lookup_emits_registry_anomaly_and_no_active_wave() -> void:
	_fake_wst._dominant = AbilitySystem.AbilityClass.CONTROL  # key &"CONTROL" absent from registry
	watch_signals(EnemyDirector)
	var wave = EnemyDirector.call("_resolve_active_wave")
	assert_null(wave, "EC-10: null registry lookup returns null wave")
	assert_signal_emitted(EnemyDirector, "combat_metric_anomaly", "EC-10: anomaly emitted")
	var payload = get_signal_parameters(EnemyDirector, "combat_metric_anomaly")[0]
	assert_eq(payload.reason, EnemyDirector.REASON_REGISTRY_LOOKUP_NULL,
		"EC-10: reason REGISTRY_LOOKUP_NULL")


func test_ec10_null_lookup_during_tick_skips_spawn() -> void:
	_fake_wst._dominant = AbilitySystem.AbilityClass.CONTROL
	EnemyDirector.set(&"_wave_scheduler_paused", false)
	EnemyDirector.call("_spawn_cadence_tick", 10.0)
	assert_eq(_fake_sink.spawned.size(), 0, "EC-10: no spawn when registry lookup is null")


# ---------------------------------------------------------------------------
# EC-11 — pool cap (with positive control)
# ---------------------------------------------------------------------------

## Positive control: below the cap, an elapsed cadence DOES spawn.
func test_ec11_positive_control_spawns_below_cap() -> void:
	_fake_wst._dominant = AbilitySystem.AbilityClass.STRIKE
	EnemyDirector.set(&"_wave_scheduler_paused", false)
	_fill_pool(5)  # below cap of 6
	EnemyDirector.call("_spawn_cadence_tick", 10.0)  # delta >> interval(4.0)
	assert_eq(_fake_sink.spawned.size(), 1, "EC-11 control: below cap, elapsed cadence spawns")


## At cap, the elapsed cadence does NOT spawn and emits no anomaly.
func test_ec11_no_spawn_at_pool_cap() -> void:
	_fake_wst._dominant = AbilitySystem.AbilityClass.STRIKE
	EnemyDirector.set(&"_wave_scheduler_paused", false)
	_fill_pool(EnemyDirector.MAX_CONCURRENT_ENEMIES_ON_SCREEN)  # 6 = at cap
	watch_signals(EnemyDirector)
	EnemyDirector.call("_spawn_cadence_tick", 10.0)
	assert_eq(_fake_sink.spawned.size(), 0, "EC-11: no spawn at pool cap")
	assert_eq(get_signal_emit_count(EnemyDirector, "combat_metric_anomaly"), 0,
		"EC-11: pool cap is legitimate — NO anomaly emitted")


## Cadence below the interval does not spawn even when below the pool cap.
func test_ec11_no_spawn_before_interval_elapsed() -> void:
	_fake_wst._dominant = AbilitySystem.AbilityClass.STRIKE
	EnemyDirector.set(&"_wave_scheduler_paused", false)
	_fill_pool(0)
	EnemyDirector.call("_spawn_cadence_tick", 1.0)  # 1.0 < 4.0 interval
	assert_eq(_fake_sink.spawned.size(), 0, "EC-11: no spawn before the interval elapses")


## A paused scheduler never spawns (default-paused gate).
func test_scheduler_paused_never_spawns() -> void:
	_fake_wst._dominant = AbilitySystem.AbilityClass.STRIKE
	# _ready left it paused; do not unpause.
	EnemyDirector.call("_spawn_cadence_tick", 10.0)
	assert_eq(_fake_sink.spawned.size(), 0, "Paused scheduler must not spawn")


# ---------------------------------------------------------------------------
# EC-13 — REST_PERIOD pause + idle enemies (no despawn)
# ---------------------------------------------------------------------------

func test_ec13_rest_period_pauses_scheduler() -> void:
	EnemyDirector.set(&"_wave_scheduler_paused", false)
	EnemyDirector.call("_on_state_changed", GameStateMachine.GameState.COMBAT_ACTIVE,
		GameStateMachine.GameState.REST_PERIOD, null)
	assert_true(EnemyDirector.get(&"_wave_scheduler_paused"),
		"EC-13: REST_PERIOD pauses the scheduler")


func test_ec13_rest_period_idles_enemies_without_despawn() -> void:
	var pool: Dictionary = EnemyDirector.get(&"_enemy_state_pool")
	var e1 := MockEnemy.new()
	var e2 := MockEnemy.new()
	pool[101] = e1
	pool[102] = e2
	EnemyDirector.call("_on_state_changed", GameStateMachine.GameState.COMBAT_ACTIVE,
		GameStateMachine.GameState.REST_PERIOD, null)
	assert_eq(e1.ai_state, EnemyDirector.EnemyAIState.IDLE, "EC-13: enemy 1 set to IDLE")
	assert_eq(e2.ai_state, EnemyDirector.EnemyAIState.IDLE, "EC-13: enemy 2 set to IDLE")
	assert_eq(pool.size(), 2, "EC-13: enemies preserved (no despawn)")


func test_combat_active_unpauses_scheduler() -> void:
	EnemyDirector.set(&"_wave_scheduler_paused", true)
	EnemyDirector.call("_on_state_changed", GameStateMachine.GameState.IDLE,
		GameStateMachine.GameState.COMBAT_ACTIVE, null)
	assert_false(EnemyDirector.get(&"_wave_scheduler_paused"),
		"COMBAT_ACTIVE unpauses the scheduler")

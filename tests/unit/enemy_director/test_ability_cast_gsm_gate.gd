# EnemyDirector — Story 008 _on_ability_cast: GSM Gate (AC-1/2/3)
#
# Coverage:
#   AC-1 — GSM.SUSPENDED gate: reject + emit anomaly(GSM_SUSPENDED); no ctx built.
#   AC-2 — Null caster guard: reject + emit anomaly(INVALID_ABILITY_ID, caster:null); no ctx.
#   AC-3 — Empty transition_id guard: reject + emit anomaly(RNG_INJECTION_MISSING, tid:""); no ctx.
#
# All fakes inject via DI seams so _on_ability_cast runs with predictable inputs.
extends GutTest


## FakeGSM: controls current_state + acquire_transition_id return value.
class FakeGSM:
	signal state_changed(from_state: int, to_state: int, payload)
	var _state: int = GameStateMachine.GameState.COMBAT_ACTIVE
	var _transition_id: String = "TX-test-001"
	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)
	func get_current_state() -> int:
		return _state
	func acquire_transition_id(_from: int, _to: int) -> String:
		return _transition_id


## FakeAbilitySystem (minimal — required by _ready() subscription wiring).
class FakeAbilitySystem:
	signal ability_cast(ability_id: StringName, caster: Node2D, target: Node2D)
	func connect_for_initial_state(callable: Callable) -> void:
		ability_cast.connect(callable)


## FakeStatSystem (minimal — required by _build_stat_snapshot() in valid-path calls).
class FakeStatSystem:
	var call_count: int = 0
	func get_stat(_stat_id: StringName) -> float:
		call_count += 1
		return 10.0


## FakeEnemyRegistry (required by _ready() _preload_spawn_pool()).
class FakeEnemyRegistry:
	func get_preloaded_pool() -> Dictionary:
		return {&"STRIKE_MOB_T1": null}


var _fake_gsm: FakeGSM
var _fake_ability: FakeAbilitySystem
var _fake_stat: FakeStatSystem
var _fake_registry: FakeEnemyRegistry


func before_each() -> void:
	await get_tree().process_frame
	# Full container reset.
	EnemyDirector.get(&"_catch_up_queue").clear()
	EnemyDirector.get(&"_anomaly_rate_tracker").clear()
	EnemyDirector.get(&"_enemy_state_pool").clear()
	EnemyDirector.get(&"_killed_dedupe_set").clear()
	EnemyDirector.get(&"_spawn_pool").clear()
	EnemyDirector.set(&"_rng_factory", null)
	EnemyDirector.set(&"_active_wave", null)
	EnemyDirector.set(&"_boss_anchor_state", EnemyDirector.BossAnchorState.IDLE)
	EnemyDirector.set(&"_stat_system", null)
	# Inject fakes.
	_fake_gsm = FakeGSM.new()
	_fake_ability = FakeAbilitySystem.new()
	_fake_stat = FakeStatSystem.new()
	_fake_registry = FakeEnemyRegistry.new()
	EnemyDirector.set(&"_gsm_source", _fake_gsm)
	EnemyDirector.set(&"_ability_source", _fake_ability)
	EnemyDirector.set(&"_stat_system", _fake_stat)
	EnemyDirector.set(&"_enemy_registry", _fake_registry)
	EnemyDirector.call("_ready")


func after_each() -> void:
	await get_tree().process_frame
	EnemyDirector.set(&"_gsm_source", null)
	EnemyDirector.set(&"_ability_source", null)
	EnemyDirector.set(&"_stat_system", null)
	EnemyDirector.set(&"_enemy_registry", null)


# ---------------------------------------------------------------------------
# AC-1 — GSM Suspended gate
# ---------------------------------------------------------------------------

## Suspended state → anomaly emitted, no further processing.
func test_ac1_suspended_state_emits_gsm_suspended_anomaly() -> void:
	_fake_gsm._state = GameStateMachine.GameState.SUSPENDED
	watch_signals(EnemyDirector)
	EnemyDirector.call("_on_ability_cast", &"ABILITY_STRIKE_1", Node2D.new(), null)
	assert_signal_emitted(EnemyDirector, "combat_metric_anomaly",
		"AC-1: combat_metric_anomaly must be emitted when GSM is Suspended")
	var params: Array = get_signal_parameters(EnemyDirector, "combat_metric_anomaly")
	var payload = params[0]
	assert_eq(payload.reason, EnemyDirector.REASON_GSM_SUSPENDED,
		"AC-1: payload.reason must be GSM_SUSPENDED")
	assert_false(payload.aggregate, "AC-1: payload.aggregate must be false (individual emit)")


## Suspended state → stat_snapshot NOT called (no ctx built).
func test_ac1_suspended_state_no_stat_snapshot_call() -> void:
	_fake_gsm._state = GameStateMachine.GameState.SUSPENDED
	EnemyDirector.call("_on_ability_cast", &"ABILITY_STRIKE_1", Node2D.new(), null)
	assert_eq(_fake_stat.call_count, 0,
		"AC-1: StatSystem.get_stat must NOT be called when GSM is Suspended")


## Non-suspended state with valid inputs does NOT emit any anomaly.
func test_ac1_non_suspended_state_no_anomaly_emitted() -> void:
	_fake_gsm._state = GameStateMachine.GameState.COMBAT_ACTIVE
	watch_signals(EnemyDirector)
	EnemyDirector.call("_on_ability_cast", &"ABILITY_STRIKE_1", Node2D.new(), null)
	# Valid inputs + non-Suspended state → gate passes, no anomaly emitted in steps 1-7.
	var emit_count: int = get_signal_emit_count(EnemyDirector, "combat_metric_anomaly")
	assert_eq(emit_count, 0,
		"AC-1: no anomaly must be emitted when GSM is not Suspended and inputs are valid")


# ---------------------------------------------------------------------------
# AC-2 — Null caster guard
# ---------------------------------------------------------------------------

## Null caster → INVALID_ABILITY_ID anomaly with context_dump.caster == null.
func test_ac2_null_caster_emits_invalid_ability_id_anomaly() -> void:
	_fake_gsm._state = GameStateMachine.GameState.COMBAT_ACTIVE
	watch_signals(EnemyDirector)
	EnemyDirector.call("_on_ability_cast", &"ABILITY_STRIKE_1", null, null)
	assert_signal_emitted(EnemyDirector, "combat_metric_anomaly",
		"AC-2: combat_metric_anomaly must be emitted for null caster")
	var params: Array = get_signal_parameters(EnemyDirector, "combat_metric_anomaly")
	var payload = params[0]
	assert_eq(payload.reason, EnemyDirector.REASON_INVALID_ABILITY_ID,
		"AC-2: payload.reason must be INVALID_ABILITY_ID")
	assert_true(payload.context_dump.has("caster"),
		"AC-2: context_dump must contain 'caster' key")
	assert_eq(payload.context_dump["caster"], null,
		"AC-2: context_dump.caster must be null")


## Null caster → StatSystem NOT called.
func test_ac2_null_caster_no_stat_call() -> void:
	_fake_gsm._state = GameStateMachine.GameState.COMBAT_ACTIVE
	EnemyDirector.call("_on_ability_cast", &"ABILITY_STRIKE_1", null, null)
	assert_eq(_fake_stat.call_count, 0,
		"AC-2: StatSystem.get_stat must NOT be called for null caster")


# ---------------------------------------------------------------------------
# AC-3 — Empty transition_id guard
# ---------------------------------------------------------------------------

## Empty transition_id → RNG_INJECTION_MISSING anomaly with context_dump.transition_id == "".
func test_ac3_empty_transition_id_emits_rng_injection_missing() -> void:
	_fake_gsm._state = GameStateMachine.GameState.COMBAT_ACTIVE
	_fake_gsm._transition_id = ""  # Inject empty transition_id via DI seam.
	watch_signals(EnemyDirector)
	EnemyDirector.call("_on_ability_cast", &"ABILITY_STRIKE_1", Node2D.new(), null)
	assert_signal_emitted(EnemyDirector, "combat_metric_anomaly",
		"AC-3: combat_metric_anomaly must be emitted for empty transition_id")
	var params: Array = get_signal_parameters(EnemyDirector, "combat_metric_anomaly")
	var payload = params[0]
	assert_eq(payload.reason, EnemyDirector.REASON_RNG_INJECTION_MISSING,
		"AC-3: payload.reason must be RNG_INJECTION_MISSING")
	assert_true(payload.context_dump.has("transition_id"),
		"AC-3: context_dump must contain 'transition_id' key")
	assert_eq(payload.context_dump["transition_id"], "",
		"AC-3: context_dump.transition_id must be empty string")


## Empty transition_id → StatSystem NOT called.
func test_ac3_empty_transition_id_no_stat_call() -> void:
	_fake_gsm._state = GameStateMachine.GameState.COMBAT_ACTIVE
	_fake_gsm._transition_id = ""
	EnemyDirector.call("_on_ability_cast", &"ABILITY_STRIKE_1", Node2D.new(), null)
	assert_eq(_fake_stat.call_count, 0,
		"AC-3: StatSystem.get_stat must NOT be called when transition_id is empty")

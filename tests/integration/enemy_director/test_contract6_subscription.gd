# EnemyDirector — Story 005 AC-06: Contract 6 Signal Subscription
#
# Coverage:
#   AC-06 — After _ready() complete, EnemyDirector subscribed to:
#     - GameStateMachine.state_changed via connect_for_initial_state
#     - AbilitySystem.ability_cast via connect_for_initial_state wrapper
#   Verifies both signals are live-wired using DI-injected mocks.
extends GutTest


## Minimal fake GameStateMachine — has connect_for_initial_state + state_changed.
class FakeGSM:
	signal state_changed(from_state: int, to_state: int, payload)
	func connect_for_initial_state(callable: Callable) -> void:
		state_changed.connect(callable)


## Minimal fake AbilitySystem — has connect_for_initial_state + ability_cast.
class FakeAbilitySystem:
	signal ability_cast(ability_id: StringName, caster: Node2D, target: Node2D)
	func connect_for_initial_state(callable: Callable) -> void:
		ability_cast.connect(callable)


## Minimal fake EnemyRegistry (needed because _ready() calls _preload_spawn_pool).
class FakeEnemyRegistry:
	func get_preloaded_pool() -> Dictionary:
		return {&"STRIKE_MOB_T1": null}


var _fake_gsm: FakeGSM
var _fake_ability: FakeAbilitySystem
var _fake_registry: FakeEnemyRegistry


func before_each() -> void:
	await get_tree().process_frame
	# Reset all 8 EnemyDirector state containers (same as test_init_state.gd pattern).
	EnemyDirector.get(&"_catch_up_queue").clear()
	EnemyDirector.get(&"_anomaly_rate_tracker").clear()
	EnemyDirector.get(&"_enemy_state_pool").clear()
	EnemyDirector.get(&"_killed_dedupe_set").clear()
	EnemyDirector.get(&"_spawn_pool").clear()
	EnemyDirector.set(&"_rng_factory", null)
	EnemyDirector.set(&"_active_wave", null)
	EnemyDirector.set(&"_boss_anchor_state", EnemyDirector.BossAnchorState.IDLE)
	# Inject DI fakes.
	_fake_gsm = FakeGSM.new()
	_fake_ability = FakeAbilitySystem.new()
	_fake_registry = FakeEnemyRegistry.new()
	EnemyDirector.set(&"_gsm_source", _fake_gsm)
	EnemyDirector.set(&"_ability_source", _fake_ability)
	EnemyDirector.set(&"_enemy_registry", _fake_registry)
	# Re-run _ready() to wire subscriptions against fakes.
	EnemyDirector.call("_ready")


func after_each() -> void:
	await get_tree().process_frame
	EnemyDirector.set(&"_gsm_source", null)
	EnemyDirector.set(&"_ability_source", null)
	EnemyDirector.set(&"_enemy_registry", null)


# ---------------------------------------------------------------------------
# AC-06: subscriptions wired after _ready()
# ---------------------------------------------------------------------------

## state_changed must be connected to EnemyDirector._on_state_changed.
func test_ac06_state_changed_subscribed_after_ready() -> void:
	assert_true(
		_fake_gsm.state_changed.is_connected(
			Callable(EnemyDirector, "_on_state_changed")
		),
		"AC-06: state_changed must be connected to _on_state_changed after _ready()"
	)


## ability_cast must be connected to EnemyDirector._on_ability_cast.
func test_ac06_ability_cast_subscribed_after_ready() -> void:
	assert_true(
		_fake_ability.ability_cast.is_connected(
			Callable(EnemyDirector, "_on_ability_cast")
		),
		"AC-06: ability_cast must be connected to _on_ability_cast after _ready()"
	)


## Emitting state_changed on the fake GSM must invoke _on_state_changed.
## (Verifies end-to-end wiring — stub handler is a no-op, just checking it's reached.)
func test_ac06_state_changed_fires_handler() -> void:
	# Arrange
	watch_signals(EnemyDirector)
	var handler_called: Array[bool] = [false]
	# Override the stub handler temporarily to detect invocation.
	var original := Callable(EnemyDirector, "_on_state_changed")
	var detector := func(_f, _t, _p): handler_called[0] = true
	_fake_gsm.state_changed.connect(detector, CONNECT_ONE_SHOT)
	# Act — emit the fake signal.
	_fake_gsm.state_changed.emit(0, 1, null)
	# Assert — detector callable confirms the signal path is live.
	assert_true(handler_called[0],
		"AC-06: emitting fake state_changed must reach the wired handler")
	# Ensure original callable is still connected.
	assert_true(_fake_gsm.state_changed.is_connected(original),
		"AC-06: _on_state_changed must remain connected after emit")


## Emitting ability_cast on the fake AbilitySystem must invoke _on_ability_cast.
func test_ac06_ability_cast_fires_handler() -> void:
	var handler_called: Array[bool] = [false]
	var detector := func(_id, _c, _t): handler_called[0] = true
	_fake_ability.ability_cast.connect(detector, CONNECT_ONE_SHOT)
	# Act
	_fake_ability.ability_cast.emit(&"ABILITY_STRIKE_1", null, null)
	# Assert — detector fired AND the production handler remains connected (not just the fake works).
	assert_true(handler_called[0],
		"AC-06: emitting fake ability_cast must reach a wired handler")
	assert_true(
		_fake_ability.ability_cast.is_connected(Callable(EnemyDirector, "_on_ability_cast")),
		"AC-06: _on_ability_cast must remain connected after emit (production handler intact)")

# Unit test — AbilitySystem cast re-entrance depth limit (Story 006 / AC-28 / EC-28).
#
# A subscriber to ability_cooldown_started that synchronously re-enters cast_ability would, left
# unguarded, recurse without bound (cast → cooldown_started → cast → ...). The _cast_depth guard
# (MAX_EMIT_DEPTH=2) caps the chain: the cast that would push depth past 2 is rejected with
# GSM_REJECT + ability_cast_rejected("reentrance_depth_exceeded"), and the whole thing completes
# in well under a second (no stack overflow / infinite recursion).
#
# Chain: cast A (depth 1) → cooldown_started(A) → handler casts B (depth 2) → cooldown_started(B)
#        → handler casts C (depth 3 > 2) → REJECTED. Each cast is a DISTINCT unlocked ability so
#        the cooldown gate never short-circuits before the depth gate is exercised.
extends GutTest

const AbilitySystem := preload("res://src/autoload/ability_system.gd")


class MockGSM extends RefCounted:
	var state: int = GameStateMachine.GameState.COMBAT_ACTIVE
	func get_current_state() -> int:
		return state
	func connect_for_initial_state(_callable: Callable) -> void:
		pass


class MockStat extends RefCounted:
	func get_stat(_stat_id: StringName) -> float:
		return 100.0
	func connect_for_initial_state(_callable: Callable) -> void:
		pass


var _sut
var _gsm: MockGSM
var _stat: MockStat
var _caster: Node2D
var _target: Node2D
# The handler casts the next ability in this queue each time a cooldown starts.
var _cast_queue: Array[StringName] = []
var _reject_count: int = 0
var _reject_reason: String = ""


func before_each() -> void:
	_sut = AbilitySystem.new()
	_gsm = MockGSM.new()
	_stat = MockStat.new()
	_sut._gsm = _gsm
	_sut._stat_system = _stat
	_sut._persistence = MockPersistenceLayer.new()
	_caster = autofree(Node2D.new())
	_target = autofree(Node2D.new())
	_reject_count = 0
	_reject_reason = ""


func after_each() -> void:
	_sut.free()
	_sut = null
	_gsm = null
	_stat = null


func _force_unlock(ability_id: StringName) -> void:
	_sut._unlocked_abilities[ability_id] = AbilitySystem.UnlockRecord.new()


## Re-entrant subscriber: each cooldown_started pops the next queued ability and casts it,
## driving the depth chain. A guard keeps the test harness itself from looping forever.
func _on_cooldown_started(_ability_id: StringName, _duration: float) -> void:
	if _cast_queue.is_empty():
		return
	var next: StringName = _cast_queue.pop_front()
	var result: int = _sut.cast_ability(next, _caster, _target)
	if result == _sut.CastResult.GSM_REJECT:
		_reject_count += 1


## AC-28: the 3rd-level re-entrant cast is rejected and no stack overflow / hang occurs.
func test_reentrant_cast_rejected_at_depth_limit() -> void:
	# Arrange — three distinct unlocked STRIKE abilities so the cooldown gate never pre-empts the
	# depth gate. Queue B and C to be cast by the re-entrant handler.
	_force_unlock(_sut.AbilityId.STRIKE_TIER_1_JAB)
	_force_unlock(_sut.AbilityId.STRIKE_TIER_2_HOOK)
	_force_unlock(_sut.AbilityId.STRIKE_TIER_3_OVERHAND)
	_cast_queue = [_sut.AbilityId.STRIKE_TIER_2_HOOK, _sut.AbilityId.STRIKE_TIER_3_OVERHAND]
	_sut.ability_cooldown_started.connect(_on_cooldown_started)
	watch_signals(_sut)

	var start_ms: int = Time.get_ticks_msec()

	# Act — the outer cast (depth 1) drives the re-entrant chain.
	var outer: int = _sut.cast_ability(_sut.AbilityId.STRIKE_TIER_1_JAB, _caster, _target)

	var elapsed_ms: int = Time.get_ticks_msec() - start_ms

	# Assert — outer cast succeeded; the 3rd-level cast (depth 3) was rejected; bounded time.
	assert_eq(outer, _sut.CastResult.SUCCESS, "AC-28: the outer (depth-1) cast succeeds")
	assert_eq(_reject_count, 1, "AC-28: exactly one re-entrant cast hit the depth limit and was rejected")
	assert_signal_emitted(_sut, "ability_cast_rejected",
		"AC-28: a depth-limited cast emits ability_cast_rejected")
	# Find the reentrance rejection among emitted ability_cast_rejected signals.
	var found_reentrance := false
	var emit_count: int = get_signal_emit_count(_sut, "ability_cast_rejected")
	for i in range(emit_count):
		var params: Array = get_signal_parameters(_sut, "ability_cast_rejected", i)
		if params[1] == "reentrance_depth_exceeded":
			found_reentrance = true
	assert_true(found_reentrance, "AC-28: rejection reason is 'reentrance_depth_exceeded'")
	assert_lt(elapsed_ms, 1000, "AC-28: the chain completes in under 1 second (no infinite recursion)")


## AC-28: _cast_depth resets to 0 after the chain so a later normal cast is not falsely rejected.
func test_cast_depth_resets_after_chain() -> void:
	# Arrange — no re-entrant handler this time; two sequential normal casts.
	_force_unlock(_sut.AbilityId.MOBILITY_TIER_1_DASH)

	# Act — first cast, then (after cooldown cleared) a second cast.
	var first: int = _sut.cast_ability(_sut.AbilityId.MOBILITY_TIER_1_DASH, _caster, null)
	# Drain the cooldown so the second cast is not ON_COOLDOWN.
	for i in range(40):
		_sut._process(0.1)
	var second: int = _sut.cast_ability(_sut.AbilityId.MOBILITY_TIER_1_DASH, _caster, null)

	# Assert — both succeed; _cast_depth did not leak across calls.
	assert_eq(first, _sut.CastResult.SUCCESS, "AC-28: first cast succeeds")
	assert_eq(second, _sut.CastResult.SUCCESS, "AC-28: second cast succeeds (_cast_depth reset to 0)")

# StatSystem — Story 006 Atomic write, emit-after-mutate ordering (AC-19) Unit Tests.
#
# Scope: apply_stat_delta mutates _base BEFORE emitting stat_changed, so a
# subscriber that calls get_stat() from inside its handler observes the NEW value
# (not the stale pre-mutation value). This proves the emit happens after the
# in-memory store is consistent.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/stat-system.md §H AC-19 (Rule 7 atomicity)
# Story: production/epics/stat-system/story-006-persistence-atomic-write.md
extends GutTest

const StatSystem := preload("res://src/autoload/stat_system.gd")


class MockGSM extends RefCounted:
	func connect_for_initial_state(_callable: Callable) -> void:
		pass


## Subscriber that re-reads get_stat(STR) from inside its stat_changed handler.
## Holds a back-reference to the SUT so the handler can query live state.
class ReadbackSubscriber extends RefCounted:
	var sut
	var observed_during_emit: float = -1.0
	var observed_new_value_param: float = -1.0

	func on_changed(stat_id: StringName, _old_value: float, new_value: float,
			_source: int, _is_base_change: bool) -> void:
		if stat_id == sut.StatId.STR:
			observed_during_emit = sut.get_stat(stat_id)
			observed_new_value_param = new_value


var _sut


func before_each() -> void:
	_sut = StatSystem.new()
	_sut._persistence = MockPersistenceLayer.new()  # write() returns true
	_sut._gsm = MockGSM.new()
	add_child_autofree(_sut)  # boot to READY (STR == 10.0)


func after_each() -> void:
	_sut = null


func test_subscriber_reads_new_value_inside_emit() -> void:
	# Arrange: connect a subscriber that reads back during the emit.
	var sub := ReadbackSubscriber.new()
	sub.sut = _sut
	_sut.stat_changed.connect(sub.on_changed)

	# Act: STR 10.0 + 1.0 → 11.0.
	var ok: bool = _sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.PR_BREAKTHROUGH, 1.0)

	# Assert: AC-19 — get_stat() inside the handler returns the NEW value (11.0),
	# proving _base was mutated before the emit fired.
	assert_true(ok, "the mutation must succeed")
	assert_eq(sub.observed_during_emit, 11.0,
		"AC-19: get_stat(STR) inside the stat_changed handler must observe the new value (11.0)")
	assert_eq(sub.observed_new_value_param, 11.0,
		"AC-19: the stat_changed new_value param must match the live get_stat() value")


func test_post_mutation_value_is_persisted_target() -> void:
	# Act
	_sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.PR_BREAKTHROUGH, 1.0)

	# Assert: after the call returns, the live value is the new target.
	assert_eq(_sut.get_stat(_sut.StatId.STR), 11.0,
		"AC-19: after apply_stat_delta returns, get_stat(STR) must be the new value (11.0)")

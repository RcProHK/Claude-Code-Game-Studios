# Unit test — StatSystem re-entrance guard (Story 006 / AC-33).
# A subscriber connected to stat_changed that calls back into apply_stat_delta
# must be rejected by the _emit_depth guard (returns false, push_error, no
# unbounded recursion / stack overflow). The OUTER mutation completes normally.
#
# Uses an inline always-succeed persistence mock so the outer write proceeds and
# the stat_changed emit (which drives the re-entrant subscriber) actually fires.
extends GutTest

const StatSystem := preload("res://src/autoload/stat_system.gd")


## Minimal always-succeed persistence stub. write() returns true so the outer
## apply_stat_delta reaches its emit step (where the re-entrant call is triggered).
class _AlwaysOkPersistence extends RefCounted:
	signal critical_save_failed(key: String)
	var _data: Dictionary = {}
	func read(key: String) -> Variant:
		return _data.get(key)
	func write(key: String, value: Variant, _flush: bool = false) -> bool:
		_data[key] = value
		return true
	func delete(key: String) -> bool:
		return _data.erase(key)


## Minimal GSM stub — connect_for_initial_state is a no-op so boot completes.
class _StubGsm extends RefCounted:
	func connect_for_initial_state(_callable: Callable) -> void:
		pass


var _sut: Node = null
# Tracks how many times the re-entrant subscriber actually executed its nested
# call, and what that nested call returned.
var _nested_call_count: int = 0
var _nested_return: Variant = null


func before_each() -> void:
	_sut = StatSystem.new()
	_sut._persistence = _AlwaysOkPersistence.new()
	_sut._gsm = _StubGsm.new()
	add_child(_sut)
	_sut._ready()
	_nested_call_count = 0
	_nested_return = null


func after_each() -> void:
	_sut.queue_free()
	_sut = null


## The re-entrant subscriber: when it receives a stat_changed for STR, it tries
## to mutate STR again. This is the exact recursion AC-33 must prevent.
func _reentrant_handler(stat_id: StringName, _old: float, _new: float, _source, _flag) -> void:
	if stat_id != _sut.StatId.STR:
		return
	if _nested_call_count > 0:
		return  # safety: never loop in the test harness itself
	_nested_call_count += 1
	_nested_return = _sut.apply_stat_delta(
		_sut.StatId.STR, _sut.StatSource.PR_BREAKTHROUGH, 1.0)


## AC-33: a re-entrant apply_stat_delta from a stat_changed subscriber is rejected.
func test_reentrant_apply_stat_delta_is_rejected() -> void:
	# Arrange — connect the re-entrant subscriber to future mutations.
	_sut.stat_changed.connect(_reentrant_handler)
	var str_before: float = _sut.get_stat(_sut.StatId.STR)

	# Act — outer mutation fires stat_changed, which triggers the nested call.
	var outer_result: bool = _sut.apply_stat_delta(
		_sut.StatId.STR, _sut.StatSource.PR_BREAKTHROUGH, 1.0)

	# Assert — outer call succeeded; the nested re-entrant call was rejected.
	assert_true(outer_result, "AC-33: the outer (non-re-entrant) mutation must succeed")
	assert_eq(_nested_call_count, 1, "AC-33: the subscriber attempted exactly one nested call")
	assert_false(_nested_return, "AC-33: the nested re-entrant apply_stat_delta must return false")
	# Only the outer +1 landed; the rejected nested call added nothing.
	assert_eq(_sut.get_stat(_sut.StatId.STR), str_before + 1.0,
		"AC-33: only the outer mutation applied — the rejected nested call did not mutate")


## AC-33: _emit_depth returns to 0 after the guarded emit so subsequent
## (non-nested) mutations are NOT falsely rejected.
func test_emit_depth_resets_after_guarded_emit() -> void:
	# Act — two sequential (non-re-entrant) mutations.
	var first: bool = _sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.PR_BREAKTHROUGH, 1.0)
	var second: bool = _sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.PR_BREAKTHROUGH, 1.0)

	# Assert — both succeed; the guard does not leak depth across calls.
	assert_true(first, "AC-33: first sequential mutation succeeds")
	assert_true(second, "AC-33: second sequential mutation succeeds (_emit_depth reset to 0)")
	assert_eq(_sut.get_stat(_sut.StatId.STR), 12.0, "AC-33: both deltas applied (10 → 12)")

# StatSystem — Story 005 connect_for_initial_state observer (AC-08) Unit Tests.
#
# Scope:
#   AC-08  — a subscriber receives exactly 7 initial deliveries (one per locked
#            stat_id), each with source = INITIAL_STATE, is_initial = true, and
#            old == new == get_stat(stat_id).
#   AC-08b — two independent subscribers each receive their own 7-delivery burst.
#   AC-08c — a callable created with .bind() is rejected with push_error (debug).
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/stat-system.md §H AC-08 (Rule 6)
# Story: production/epics/stat-system/story-005-connect-for-initial-state.md
extends GutTest

const StatSystem := preload("res://src/autoload/stat_system.gd")


class MockGSM extends RefCounted:
	func connect_for_initial_state(_callable: Callable) -> void:
		pass


## Recording subscriber — captures every delivery as a Dictionary row so the
## test can assert count, order, source, and the is_initial flag. RefCounted so
## a Callable to record() can be passed to connect_for_initial_state.
class RecordingSubscriber extends RefCounted:
	var rows: Array = []

	func record(stat_id: StringName, old_value: float, new_value: float,
			source: int, is_initial: bool) -> void:
		rows.append({
			"stat_id": stat_id,
			"old": old_value,
			"new": new_value,
			"source": source,
			"is_initial": is_initial,
		})


var _sut
var _mock_persistence: MockPersistenceLayer
var _mock_gsm: MockGSM


func before_each() -> void:
	_mock_persistence = MockPersistenceLayer.new()
	_mock_gsm = MockGSM.new()
	_sut = StatSystem.new()
	_sut._persistence = _mock_persistence
	_sut._gsm = _mock_gsm
	add_child_autofree(_sut)  # boot to READY


func after_each() -> void:
	_sut = null
	_mock_persistence = null
	_mock_gsm = null


func test_connect_delivers_exactly_seven_initial_rows() -> void:
	# Arrange
	var sub := RecordingSubscriber.new()

	# Act
	_sut.connect_for_initial_state(sub.record)

	# Assert: AC-08 — one delivery per locked stat_id.
	assert_eq(sub.rows.size(), 7,
		"AC-08: a new subscriber must receive exactly 7 initial deliveries")


func test_connect_initial_rows_are_all_initial_state_source() -> void:
	# Arrange
	var sub := RecordingSubscriber.new()

	# Act
	_sut.connect_for_initial_state(sub.record)

	# Assert: AC-08 — every initial row uses source = INITIAL_STATE, is_initial = true.
	for row in sub.rows:
		assert_eq(row["source"], StatSystem.StatSource.INITIAL_STATE,
			"AC-08: initial delivery source must be INITIAL_STATE")
		assert_true(row["is_initial"],
			"AC-08: initial delivery 5th param (is_initial) must be true")


func test_connect_initial_rows_values_match_get_stat() -> void:
	# Arrange
	var sub := RecordingSubscriber.new()

	# Act
	_sut.connect_for_initial_state(sub.record)

	# Assert: AC-08 — old == new == current get_stat() for each delivered stat.
	for row in sub.rows:
		var current: float = _sut.get_stat(row["stat_id"])
		assert_eq(row["old"], current,
			"AC-08: initial row old_value must equal get_stat(%s)" % row["stat_id"])
		assert_eq(row["new"], current,
			"AC-08: initial row new_value must equal get_stat(%s)" % row["stat_id"])


func test_connect_covers_all_seven_locked_stat_ids() -> void:
	# Arrange
	var sub := RecordingSubscriber.new()

	# Act
	_sut.connect_for_initial_state(sub.record)

	# Assert: AC-08 — the delivered stat_ids are exactly the 7 locked ids.
	var delivered: Array = []
	for row in sub.rows:
		delivered.append(row["stat_id"])
	var expected: Array = [
		_sut.StatId.STR, _sut.StatId.DEX, _sut.StatId.VIT,
		_sut.StatId.MAX_HP, _sut.StatId.ATTACK_POWER, _sut.StatId.MOVE_SPEED, _sut.StatId.CRIT_CHANCE,
	]
	assert_eq(delivered, expected,
		"AC-08: deliveries must cover all 7 locked stat_ids in canonical order")


func test_connect_future_mutation_delivered_as_non_initial() -> void:
	# Arrange: connect, then perform a real base mutation. The 5th param of the
	# real stat_changed emit is is_base_change (false for apply_stat_delta), which
	# the unified signature treats as is_initial = false (Story 005 design note).
	var sub := RecordingSubscriber.new()
	_sut.connect_for_initial_state(sub.record)
	var initial_count: int = sub.rows.size()

	# Act: real mutation (STR +1 via PR_BREAKTHROUGH).
	var ok: bool = _sut.apply_stat_delta(_sut.StatId.STR, _sut.StatSource.PR_BREAKTHROUGH, 1.0)

	# Assert: the subscriber received one more row, flagged is_initial = false.
	assert_true(ok, "precondition: the mutation must succeed")
	assert_eq(sub.rows.size(), initial_count + 1,
		"a real mutation must deliver exactly one more row to the subscriber")
	var last: Dictionary = sub.rows[-1]
	assert_false(last["is_initial"],
		"AC-08: a real stat_changed emit must arrive with is_initial/is_base_change = false")


func test_connect_two_subscribers_each_get_seven() -> void:
	# Arrange
	var sub_a := RecordingSubscriber.new()
	var sub_b := RecordingSubscriber.new()

	# Act
	_sut.connect_for_initial_state(sub_a.record)
	_sut.connect_for_initial_state(sub_b.record)

	# Assert: AC-08b — each subscriber gets its own independent 7-delivery burst.
	assert_eq(sub_a.rows.size(), 7, "AC-08b: subscriber A must receive 7 initial deliveries")
	assert_eq(sub_b.rows.size(), 7, "AC-08b: subscriber B must receive 7 initial deliveries")


func test_connect_rejects_bound_callable_with_push_error() -> void:
	# Arrange: a callable carrying a bound arg shifts the positional callv layout
	# (AC-08c). In a debug build connect_for_initial_state must push_error.
	if not OS.is_debug_build():
		pass_test("AC-08c is a debug-build-only guard; skipped in release")
		return
	var sub := RecordingSubscriber.new()
	var bound: Callable = sub.record.bind(true)  # one bound arg

	# Act / Assert: GUT captures the push_error.
	_sut.connect_for_initial_state(bound)
	assert_push_error(
		"[StatSystem] connect_for_initial_state: callable must NOT use .bind() — "
		+ "bound args shift the positional callv layout (AC-08c)"
	)

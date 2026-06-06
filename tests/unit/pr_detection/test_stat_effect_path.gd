extends GutTest
## Story 009 — Rule 6.1-6.3 stat effect path.
## Covers AC-08 (EC-3 all-or-nothing) + AC-13 short-circuit half (capped player).

const PrDetectionScript := preload("res://src/autoload/pr_detection.gd")


class MockStat:
	extends RefCounted
	var stat_value: float = 12.0
	var apply_result: bool = true
	var calls: Array[Dictionary] = []

	func get_stat(_stat_id: StringName) -> float:
		return stat_value

	func apply_stat_delta(stat_id: StringName, source: int, delta: float) -> bool:
		calls.append({"stat_id": stat_id, "source": source, "delta": delta})
		return apply_result


class MockClassMapping:
	extends RefCounted
	func get_class_for_exercise(_exercise_id: StringName) -> int:
		return 0


class FlushSpyPersistence:
	extends RefCounted
	var writes: Array[Dictionary] = []

	func read(_key: String) -> Variant:
		return null

	func write(key: String, _value: Variant, flush: bool = false) -> bool:
		writes.append({"key": key, "flush": flush})
		return true


var _sut: Node
var _stat: MockStat
var _persistence: FlushSpyPersistence
var _signals: Array = []


func before_each() -> void:
	_stat = MockStat.new()
	_persistence = FlushSpyPersistence.new()
	_signals = []
	_sut = PrDetectionScript.new()
	_sut._persistence = _persistence
	_sut._stat_system = _stat
	_sut._class_mapping = MockClassMapping.new()
	add_child_autofree(_sut)
	_sut.pr_breakthrough.connect(func(_sid: StringName, m: float) -> void:
		_signals.append(m))


# --- AC-08: EC-3 all-or-nothing on apply failure ------------------------------------

func test_apply_failure_aborts_the_whole_event() -> void:
	# Arrange
	_sut._pr_state.baselines["bench_press"] = 70.0
	_stat.apply_result = false
	var writes_before: int = _persistence.writes.size()

	# Act — a PR-grade set while #11 rejects (persist fail / suspended).
	_sut._on_set_logged("bench_press", 5, 65.0)

	# Assert — the event never happened: baseline / signal / counters / summary / persist.
	assert_almost_eq(_sut._pr_state.baselines["bench_press"], 70.0, 0.001,
		"AC-08: baseline untouched on apply failure")
	assert_eq(_signals.size(), 0, "AC-08: zero signal")
	assert_eq(_sut._pr_state.lifetime_count, 0, "AC-08: lifetime count untouched")
	assert_almost_eq(_sut._pr_state.lifetime_pr_score, 0.0, 0.000001)
	assert_eq(_persistence.writes.size(), writes_before, "AC-08: zero persist write")

	# Re-judge works once #11 recovers (the un-raised baseline keeps it re-judgeable).
	_stat.apply_result = true
	_sut._on_set_logged("bench_press", 5, 65.0)
	assert_eq(_signals.size(), 1, "EC-3: the same set re-judges after recovery")


# --- AC-13 short-circuit half: capped player ----------------------------------------

func test_capped_stat_short_circuits_apply_but_keeps_recognition() -> void:
	# Arrange — stat at the 999 cap → PRDeltaCalc.compute yields EXACT 0.0.
	_sut._pr_state.baselines["bench_press"] = 70.0
	_stat.stat_value = 999.0

	# Act
	_sut._on_set_logged("bench_press", 5, 65.0)

	# Assert — zero apply call (never relies on #11's unpinned zero-delta path),
	# but the recognition chain still runs: baseline / signal / count.
	assert_eq(_stat.calls.size(), 0, "AC-13: delta==0 skips the #11 call entirely")
	assert_almost_eq(_sut._pr_state.baselines["bench_press"], 75.833, 0.001,
		"AC-13: baseline still ratchets")
	assert_eq(_signals.size(), 1, "AC-13: signal still fires (capped players keep recognition)")
	assert_eq(_sut._pr_state.lifetime_count, 1, "AC-13: count still increments")

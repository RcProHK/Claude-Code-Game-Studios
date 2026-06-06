extends GutTest
## Story 014 — G-PR-2 count chain (AC-22): #18 emit ×3 → #9 handler counts;
## daily rollover resets; stale-date reads answer 0.

const PrDetectionScript := preload("res://src/autoload/pr_detection.gd")
const WstScript := preload("res://src/autoload/workout_state_tracker.gd")


class MockStat:
	extends RefCounted
	func get_stat(_stat_id: StringName) -> float:
		return 12.0
	func apply_stat_delta(_s: StringName, _src: int, _d: float) -> bool:
		return true


class MockClassMapping:
	extends RefCounted
	func get_class_for_exercise(_exercise_id: StringName) -> int:
		return 0


var _today: String = "2026-06-06"


func _make_wst() -> Node:
	# Un-parented WST instance — _ready never runs; only the G-PR-2 additive
	# surface is exercised (handler + getter are boot-independent).
	var wst = WstScript.new()
	wst._pr_date_provider = func() -> String: return _today
	autofree(wst)
	return wst


func test_three_emits_count_three_and_day_rollover_resets() -> void:
	# Arrange — #18 reverse-wired into the #9 handler (D6 direction).
	var wst: Node = _make_wst()
	var sut: Node = PrDetectionScript.new()
	sut._persistence = MockPersistenceLayer.new()
	sut._stat_system = MockStat.new()
	sut._class_mapping = MockClassMapping.new()
	sut._wst_handler = Callable(wst, "_on_pr_breakthrough")
	add_child_autofree(sut)
	sut._pr_state.baselines["bench_press"] = 70.0

	# Act — three consecutive PRs (ascending: each independent, Rule 7).
	sut._on_set_logged("bench_press", 5, 65.0)
	sut._on_set_logged("bench_press", 5, 70.0)
	sut._on_set_logged("bench_press", 5, 75.0)

	# Assert — #18-side emit ×3 landed in the #9 counter (AC-22 #18-side + #9-side).
	assert_eq(wst.get_pr_count_today(), 3, "AC-22: PR ×3 → count 3")

	# Day rollover (per #9 daily semantics — UTC date window).
	_today = "2026-06-07"
	assert_eq(wst.get_pr_count_today(), 0, "stale-date read answers 0 (day rolled)")

	# A new-day PR starts a fresh count.
	sut._on_set_logged("bench_press", 5, 80.0)
	assert_eq(wst.get_pr_count_today(), 1, "new day → fresh count")


func test_getter_without_any_pr_is_zero() -> void:
	var wst: Node = _make_wst()
	assert_eq(wst.get_pr_count_today(), 0)

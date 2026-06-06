extends GutTest
## Story 006 — Formula 4 establishment window (INV-PR-1) + Baseline Forged.
## Covers AC-03 (warmup-ramp golden) + AC-28 (binding moment signal).

const PrDetectionScript := preload("res://src/autoload/pr_detection.gd")


class MockStat:
	extends RefCounted
	var calls: int = 0

	func get_stat(_stat_id: StringName) -> float:
		return 12.0

	func apply_stat_delta(_stat_id: StringName, _source: int, _delta: float) -> bool:
		calls += 1
		return true


class MockClassMapping:
	extends RefCounted
	func get_class_for_exercise(_exercise_id: StringName) -> int:
		return 0  # STRIKE


var _sut: Node
var _stat: MockStat
var _signals: Array = []
var _forged: Array = []


func before_each() -> void:
	_stat = MockStat.new()
	_signals = []
	_forged = []
	_sut = PrDetectionScript.new()
	_sut._persistence = MockPersistenceLayer.new()
	_sut._stat_system = _stat
	_sut._class_mapping = MockClassMapping.new()
	add_child_autofree(_sut)
	_sut.pr_breakthrough.connect(func(_sid: StringName, m: float) -> void:
		_signals.append(m))
	_sut.baseline_established.connect(func(ex: String, e1rm: float) -> void:
		_forged.append([ex, e1rm]))


func _events() -> Array:
	return _sut.get_telemetry().map(func(e: Dictionary) -> String: return e["event"])


# --- AC-03: warmup-ramp golden (INV-PR-1) ----------------------------------------

func test_warmup_ramp_first_workout_zero_pr_then_commit_then_normal() -> void:
	# Act 1 — new exercise, ascending ramp in ONE workout: 40→50→60 (×5 each).
	_sut._on_set_logged("bench_press", 5, 40.0)
	_sut._on_set_logged("bench_press", 5, 50.0)
	_sut._on_set_logged("bench_press", 5, 60.0)

	# Assert 1 — ZERO PRs (no stat calls, no signals, no count).
	assert_eq(_stat.calls, 0, "establishment window: ramp sets never PR (INV-PR-1)")
	assert_eq(_signals.size(), 0)
	assert_eq(_sut._pr_state.lifetime_count, 0)
	assert_almost_eq(_sut._pr_state.candidates["bench_press"], 70.0, 0.001,
		"candidate carries the session max e1rm")

	# Act 2 — workout completes: candidate commits to baseline.
	_sut._on_workout_completed(1764547300)

	# Assert 2 — baseline 70.0; Baseline Forged moment emitted (AC-28 binding).
	assert_almost_eq(_sut._pr_state.baselines["bench_press"], 70.0, 0.001)
	assert_true(_sut._pr_state.candidates.is_empty())
	assert_eq(_forged.size(), 1)
	assert_eq(_forged[0][0], "bench_press")
	assert_almost_eq(_forged[0][1], 70.0, 0.001)
	assert_has(_events(), "pr.baseline_established")

	# Act 3 — next workout: 65×5 (e1rm 75.833) → normal PR vs the forged baseline.
	_sut._on_set_logged("bench_press", 5, 65.0)

	# Assert 3 — confirmed: m ≈ 0.0833.
	assert_eq(_signals.size(), 1)
	assert_almost_eq(_signals[0], 0.0833, 0.001)


func test_candidate_only_rises_within_window() -> void:
	# Descending sets never lower the candidate (max semantics).
	_sut._on_set_logged("bench_press", 5, 60.0)   # e1rm 70
	_sut._on_set_logged("bench_press", 5, 40.0)   # e1rm 46.67 — lower
	assert_almost_eq(_sut._pr_state.candidates["bench_press"], 70.0, 0.001)


func test_commit_with_no_candidates_is_silent() -> void:
	_sut._on_workout_completed(1764547300)
	assert_eq(_forged.size(), 0)
	assert_false(_events().has("pr.baseline_established"))

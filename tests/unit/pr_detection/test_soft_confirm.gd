extends GutTest
## Story 007 — D8 soft-confirm (pending / corroborate / discard) + INV-PR-2.
## Covers AC-07 (three paths) / AC-29 (interleaved recompute) / AC-31 (property).

const PrDetectionScript := preload("res://src/autoload/pr_detection.gd")


class MockStat:
	extends RefCounted
	var calls: Array[Dictionary] = []

	func get_stat(_stat_id: StringName) -> float:
		return 12.0

	func apply_stat_delta(stat_id: StringName, source: int, delta: float) -> bool:
		calls.append({"stat_id": stat_id, "source": source, "delta": delta})
		return true


class MockClassMapping:
	extends RefCounted
	func get_class_for_exercise(_exercise_id: StringName) -> int:
		return 0


var _sut: Node
var _stat: MockStat
var _signals: Array = []


func before_each() -> void:
	_stat = MockStat.new()
	_signals = []
	_sut = PrDetectionScript.new()
	_sut._persistence = MockPersistenceLayer.new()
	_sut._stat_system = _stat
	_sut._class_mapping = MockClassMapping.new()
	add_child_autofree(_sut)
	_sut.pr_breakthrough.connect(func(_sid: StringName, m: float) -> void:
		_signals.append(m))


func _events() -> Array:
	return _sut.get_telemetry().map(func(e: Dictionary) -> String: return e["event"])


## weight that yields a given e1rm at 5 reps: w = e1rm × 6/7.
func _w5(e1rm: float) -> float:
	return e1rm * 6.0 / 7.0


# --- AC-07 (a): suspect → pending → corroborate → commit ---------------------------

func test_suspect_jump_holds_pending_then_corroborates() -> void:
	_sut._pr_state.baselines["bench_press"] = 70.0
	# Act 1 — raw m = (315−70)/70 = 3.5 (typo-grade) → PENDING.
	_sut._on_set_logged("bench_press", 5, _w5(315.0))
	# Assert 1 — full hold: zero delta/signal/count, baseline unchanged.
	assert_eq(_stat.calls.size(), 0)
	assert_eq(_signals.size(), 0)
	assert_eq(_sut._pr_state.lifetime_count, 0)
	assert_almost_eq(_sut._pr_state.baselines["bench_press"], 70.0, 0.001)
	assert_has(_events(), "pr.magnitude_anomaly")
	assert_has(_events(), "pr.pending_opened")

	# Act 2 — corroborating set: e1rm 300 ≥ 315 × 0.95 = 299.25.
	_sut._on_set_logged("bench_press", 5, _w5(300.0))

	# Assert 2 — committed: magnitude recomputed then clamped to 2.0; baseline = raw 315.
	assert_eq(_signals.size(), 1)
	assert_almost_eq(_signals[0], 2.0, 0.0001, "clamped magnitude reaches consumers")
	assert_almost_eq(_sut._pr_state.baselines["bench_press"], 315.0, 0.001,
		"baseline rises to the RAW pending e1rm (corroborated = real)")
	assert_has(_events(), "pr.pending_corroborated")
	assert_true(_sut._pr_state.pending.is_empty())


# --- AC-07 (b): no corroboration by the next workout's end → discard ----------------

func test_pending_discards_at_deadline() -> void:
	_sut._pr_state.baselines["bench_press"] = 70.0
	_sut._on_set_logged("bench_press", 5, _w5(315.0))  # pending @ seq 0
	# Same workout completes — NOT discarded (deadline is the NEXT workout's end).
	_sut._on_workout_completed(1)
	assert_false(_sut._pr_state.pending.is_empty(), "same-workout end keeps the pending")
	# Next workout starts (seq 1) and completes with no corroboration → discard.
	_sut._on_workout_started()
	_sut._on_workout_completed(2)
	assert_true(_sut._pr_state.pending.is_empty())
	assert_has(_events(), "pr.pending_discarded")
	assert_almost_eq(_sut._pr_state.baselines["bench_press"], 70.0, 0.001,
		"discard leaves the baseline untouched")
	assert_eq(_signals.size(), 0)


# --- AC-07 (c): sub-suspect anomaly confirms immediately ----------------------------

func test_quarter_magnitude_confirms_without_pending() -> void:
	_sut._pr_state.baselines["bench_press"] = 70.0
	# m = (87.5−70)/70 = 0.25 < SUSPECT 0.30 → immediate confirm.
	_sut._on_set_logged("bench_press", 5, _w5(87.5))
	assert_eq(_signals.size(), 1)
	assert_almost_eq(_signals[0], 0.25, 0.001)
	assert_true(_sut._pr_state.pending.is_empty())


# --- AC-29: interleaved recompute preserves INV-PR-2 --------------------------------

func test_interleaved_pending_commit_recomputes_magnitude() -> void:
	_sut._pr_state.baselines["bench_press"] = 70.0
	# Set A: e1rm 94.5 → raw m = 0.35 > SUSPECT → pending (stored claim m=0.35).
	_sut._on_set_logged("bench_press", 5, _w5(94.5))
	# Interleaved normal PR: e1rm 76.0 → m ≈ 0.0857 → confirmed, baseline → 76.
	_sut._on_set_logged("bench_press", 5, _w5(76.0))
	assert_eq(_signals.size(), 1)
	assert_almost_eq(_sut._pr_state.baselines["bench_press"], 76.0, 0.001)
	# Set B: e1rm 92.0 ≥ 94.5 × 0.95 = 89.775 → corroborates.
	_sut._on_set_logged("bench_press", 5, _w5(92.0))
	# Commit magnitude = (94.5 − 76) / 76 ≈ 0.2434 — NOT the stored 0.35 (AC-29).
	# Set B's own judgment afterwards is vs baseline 94.5 (negative m) → no 3rd signal.
	assert_eq(_signals.size(), 2, "interleaved PR + pending commit (set B's own m < 0)")
	assert_almost_eq(_signals[1], 0.2434, 0.001, "commit-time recompute (not stored 0.35)")
	assert_almost_eq(_sut._pr_state.baselines["bench_press"], 94.5, 0.001)
	# INV-PR-2 upper bound: Σm over the path 70→94.5 must not exceed (94.5−70)/70 = 0.35.
	var sigma: float = 0.0
	for m: Variant in _signals:
		sigma += m
	assert_almost_eq(sigma, 0.3291, 0.001)
	assert_true(sigma <= (94.5 - 70.0) / 70.0 + 0.000001,
		"INV-PR-2 upper bound preserved on the interleaved path (AC-29)")


# --- AC-31: INV-PR-2 property over a confirmed step sequence ------------------------

func test_inv_pr_2_log_additivity_bounds() -> void:
	_sut._pr_state.baselines["bench_press"] = 70.0
	for target: float in [75.83, 80.0, 90.0]:
		_sut._on_set_logged("bench_press", 5, _w5(target))
	var sigma: float = 0.0
	for m: Variant in _signals:
		sigma += m
	assert_eq(_signals.size(), 3)
	assert_true(sigma >= log(90.0 / 70.0) - 0.000001,
		"INV-PR-2 lower bound ln(final/initial) (raw m ≤ 2.0 regime)")
	assert_true(sigma <= (90.0 - 70.0) / 70.0 + 0.000001,
		"INV-PR-2 upper bound (final−initial)/initial — farming never beats one big step")


func test_inv_pr_2_micro_steps_stay_bounded() -> void:
	_sut._pr_state.baselines["bench_press"] = 100.0
	var current: float = 100.0
	for i: int in 20:
		current *= 1.011  # ~1.1% per step (just above the floor)
		_sut._on_set_logged("bench_press", 5, _w5(current))
	var sigma: float = 0.0
	for m: Variant in _signals:
		sigma += m
	assert_eq(_signals.size(), 20)
	assert_true(sigma <= (current - 100.0) / 100.0 + 0.000001,
		"micro-stepping gains no extra magnitude (INV-PR-2)")


# --- keep-highest replace -------------------------------------------------------------

func test_second_suspect_keeps_highest() -> void:
	_sut._pr_state.baselines["bench_press"] = 70.0
	_sut._on_set_logged("bench_press", 5, _w5(315.0))
	_sut._on_set_logged("bench_press", 5, _w5(105.0))  # raw m = 0.5 — suspect but LOWER claim
	assert_almost_eq(float(_sut._pr_state.pending["bench_press"]["e1rm_raw"]), 315.0, 0.001,
		"keep-highest: the bigger claim keeps the higher corroboration bar")
	var replaced: int = _events().filter(
		func(e: String) -> bool: return e == "pr.pending_replaced").size()
	assert_eq(replaced, 0, "lower claim does not replace")

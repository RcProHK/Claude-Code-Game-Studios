extends GutTest
## Story 005 — 判定 pipeline core (Rules 4-7).
## Covers AC-01 (confirm golden) / AC-02 (replay no-op) / AC-06 (noise floor)
## / AC-24 (exact-1% boundary) / AC-10 (連續 PR) / AC-05 pipeline half (rep clamp).

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
		return 0  # STRIKE → &"str"


## Local persistence mock that records the flush flag per write (the shared
## MockPersistenceLayer spy entry omits it).
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
	_sut.pr_breakthrough.connect(func(stat_id: StringName, m: float) -> void:
		_signals.append([stat_id, m]))


func _flush_count() -> int:
	return _persistence.writes.filter(
		func(w: Dictionary) -> bool: return w["flush"]).size()


func _events() -> Array:
	return _sut.get_telemetry().map(func(e: Dictionary) -> String: return e["event"])


# --- AC-01: confirm golden -------------------------------------------------------

func test_confirm_golden_full_chain() -> void:
	# Arrange — trusted baseline bench=70.0, STR=12.0.
	_sut._pr_state.baselines["bench_press"] = 70.0
	# Act — 65kg×5 → e1rm 75.833, m ≈ 0.0833.
	_sut._on_set_logged("bench_press", 5, 65.0)
	# Assert — apply called once with δ ≈ 0.500 (AC-12 golden reuse).
	assert_eq(_stat.calls.size(), 1)
	assert_eq(_stat.calls[0]["stat_id"], &"str")
	assert_eq(_stat.calls[0]["source"], 0, "StatSource.PR_BREAKTHROUGH ordinal 0")
	assert_almost_eq(_stat.calls[0]["delta"], 0.500, 0.001)
	# Signal once with magnitude ≈ 0.0833.
	assert_eq(_signals.size(), 1)
	assert_almost_eq(_signals[0][1], 0.0833, 0.001)
	# Baseline ratcheted to 75.833; exactly one flush=true write; pr.detected.
	assert_almost_eq(_sut._pr_state.baselines["bench_press"], 75.833, 0.001)
	assert_eq(_flush_count(), 1, "one PR = one flush (Rule 6.6)")
	assert_has(_events(), "pr.detected")
	assert_eq(_sut._pr_state.lifetime_count, 1)


# --- AC-02: replay no-op ----------------------------------------------------------

func test_replay_after_confirm_is_noop() -> void:
	_sut._pr_state.baselines["bench_press"] = 70.0
	_sut._on_set_logged("bench_press", 5, 65.0)
	var calls_after_first: int = _stat.calls.size()
	var flushes_after_first: int = _flush_count()
	# Act — exact same set replayed (bfcache / catch-up).
	_sut._on_set_logged("bench_press", 5, 65.0)
	# Assert — zero new calls / signals / writes; baseline unchanged (D5).
	assert_eq(_stat.calls.size(), calls_after_first, "zero stat calls on replay")
	assert_eq(_signals.size(), 1, "zero extra signals on replay")
	assert_eq(_flush_count(), flushes_after_first, "zero persist writes on replay")
	assert_almost_eq(_sut._pr_state.baselines["bench_press"], 75.833, 0.001)


# --- AC-06 / AC-24: noise floor + exact boundary ----------------------------------

func test_sub_floor_magnitude_is_not_a_pr() -> void:
	# 86.4×5 → e1rm 100.8 vs baseline 100.0 → m = 0.008 < 0.01.
	_sut._pr_state.baselines["bench_press"] = 100.0
	_sut._on_set_logged("bench_press", 5, 86.4)
	assert_eq(_stat.calls.size(), 0)
	assert_eq(_signals.size(), 0)
	assert_almost_eq(_sut._pr_state.baselines["bench_press"], 100.0, 0.0001)


func test_exact_one_percent_boundary_confirms() -> void:
	# e1rm exactly 101.0 vs 100.0 → m == 0.01 — epsilon guard must accept (AC-24).
	_sut._pr_state.baselines["bench_press"] = 100.0
	# weight × (1 + 5/30) = 101.0 → weight = 101 × 6/7 ≈ 86.5714285714
	_sut._on_set_logged("bench_press", 5, 101.0 * 6.0 / 7.0)
	assert_eq(_signals.size(), 1, "exact 1% must confirm (epsilon boundary guard)")


# --- AC-10: 連續 PR (same workout, each independent) -------------------------------

func test_consecutive_prs_each_judged_against_latest_baseline() -> void:
	_sut._pr_state.baselines["bench_press"] = 70.0
	_sut._on_set_logged("bench_press", 5, 65.0)   # e1rm 75.833, m1 ≈ 0.0833
	_sut._on_set_logged("bench_press", 2, 75.0)   # e1rm 80.0,  m2 = (80−75.833)/75.833 ≈ 0.0550
	assert_eq(_signals.size(), 2)
	assert_almost_eq(_signals[1][1], 0.0550, 0.001)
	assert_almost_eq(_sut._pr_state.baselines["bench_press"], 80.0, 0.001)


# --- AC-05 pipeline half: rep clamp semantics --------------------------------------

func test_rep_only_growth_past_cap_is_not_a_pr() -> void:
	# Baseline established at 100×12 (e1rm 140); 100×15 → identical e1rm → no PR.
	_sut._pr_state.baselines["leg_press"] = 140.0
	_sut._on_set_logged("leg_press", 15, 100.0)
	assert_eq(_signals.size(), 0, "rep-only growth past REP_CAP never PRs (honest)")


func test_added_weight_at_high_reps_confirms() -> void:
	# 110×15 → e1rm 154 vs 140 → m = 0.1 → PR.
	_sut._pr_state.baselines["leg_press"] = 140.0
	_sut._on_set_logged("leg_press", 15, 110.0)
	assert_eq(_signals.size(), 1)
	assert_almost_eq(_signals[0][1], 0.1, 0.001)

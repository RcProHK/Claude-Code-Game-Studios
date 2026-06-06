extends GutTest
## Story 010 — Formula 5 session summary + lifetime counters + Rule 9 milestone.
## Covers AC-18 / AC-19 / AC-20 + EC-13 (late set).

const PrDetectionScript := preload("res://src/autoload/pr_detection.gd")
const CONFIG_PATH := "res://assets/data/pr_milestone_config.tres"


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


var _sut: Node
var _milestones: Array = []


func before_each() -> void:
	_sut = PrDetectionScript.new()
	_sut._persistence = MockPersistenceLayer.new()
	_sut._stat_system = MockStat.new()
	_sut._class_mapping = MockClassMapping.new()
	add_child_autofree(_sut)
	_sut.pr_milestone_reached.connect(func(count: int) -> void:
		_milestones.append(count))
	_milestones = []


func _events() -> Array:
	return _sut.get_telemetry().map(func(e: Dictionary) -> String: return e["event"])


# --- AC-18: max-magnitude tuple + post-workout window + clear-on-next-start ---------

func test_summary_keeps_max_magnitude_tuple_and_survives_completion() -> void:
	_sut._pr_state.baselines["bench_press"] = 70.0
	_sut._on_workout_started()
	_sut._on_set_logged("bench_press", 5, 65.0)   # m ≈ 0.0833 (max)
	_sut._on_set_logged("bench_press", 2, 75.0)   # m ≈ 0.0550
	var summary: Dictionary = _sut.get_session_pr_summary()
	assert_eq(summary.size(), 1, "same exercise aggregates to ONE entry")
	var entry: Dictionary = summary["bench_press"]
	assert_almost_eq(entry["weight_kg"], 65.0, 0.001, "fields come from the MAX-m set")
	assert_eq(entry["reps"], 5)
	assert_almost_eq(entry["e1rm_kg"], 75.833, 0.001)
	assert_almost_eq(entry["magnitude"], 0.0833, 0.001)
	# Post-workout window: completion does NOT clear (receipt readers race-free).
	_sut._on_workout_completed(1)
	assert_eq(_sut.get_session_pr_summary().size(), 1, "summary survives workout_completed")
	# Next workout start clears.
	_sut._on_workout_started()
	assert_true(_sut.get_session_pr_summary().is_empty(), "cleared on NEXT workout_started")


func test_two_exercises_two_entries() -> void:
	_sut._pr_state.baselines["bench_press"] = 70.0
	_sut._pr_state.baselines["barbell_squat"] = 100.0
	_sut._on_workout_started()
	_sut._on_set_logged("bench_press", 5, 65.0)
	_sut._on_set_logged("barbell_squat", 5, 95.0)
	assert_eq(_sut.get_session_pr_summary().size(), 2)


# --- EC-13: late set never enters the summary ----------------------------------------

func test_late_set_judges_but_skips_summary() -> void:
	_sut._pr_state.baselines["bench_press"] = 70.0
	_sut._on_workout_started()
	_sut._on_workout_completed(1)
	# Retro-logged set arrives after completion: the PR stands, summary untouched.
	_sut._on_set_logged("bench_press", 5, 65.0)
	assert_eq(_sut._pr_state.lifetime_count, 1, "EC-13: the PR itself is honest")
	assert_true(_sut.get_session_pr_summary().is_empty(), "EC-13: never enters the summary")
	assert_has(_events(), "pr.late_set")


# --- AC-19: milestone crossing-only ----------------------------------------------------

func test_milestone_emits_on_crossing_10() -> void:
	_sut._pr_state.baselines["bench_press"] = 70.0
	_sut._pr_state.lifetime_count = 9
	_sut._on_workout_started()
	_sut._on_set_logged("bench_press", 5, 65.0)  # count 9 → 10
	assert_eq(_milestones, [10])


func test_boot_load_past_threshold_never_reemits() -> void:
	# Crossing-only by construction: emission only happens on the increment path —
	# a fresh boot with count already past a threshold emits nothing.
	var mock := MockPersistenceLayer.new()
	var state := PrState.new()
	state.lifetime_count = 10
	mock.write("pr.state", state.to_dict())
	var sut2: Node = PrDetectionScript.new()
	sut2._persistence = mock
	sut2._stat_system = MockStat.new()
	sut2._class_mapping = MockClassMapping.new()
	var fired: Array = []
	sut2.pr_milestone_reached.connect(func(c: int) -> void: fired.append(c))
	add_child_autofree(sut2)
	assert_eq(sut2._pr_state.lifetime_count, 10)
	assert_true(fired.is_empty(), "AC-19: boot load past a threshold never re-emits")


# --- AC-20: config validation-function form --------------------------------------------

func test_non_ascending_config_fails_validation() -> void:
	var bad := PrMilestoneConfig.new()
	bad.thresholds = [10, 5, 50] as Array[int]
	assert_false(_sut.validate_milestone_config(bad),
		"AC-20: non-ascending thresholds → validate returns false (no raw assert)")


func test_shipped_tres_config_is_valid() -> void:
	var config: PrMilestoneConfig = load(CONFIG_PATH)
	assert_not_null(config, "shipped pr_milestone_config.tres must load headlessly")
	assert_true(_sut.validate_milestone_config(config))
	assert_eq(config.thresholds, [10, 25, 50, 100] as Array[int])

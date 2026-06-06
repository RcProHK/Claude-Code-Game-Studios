extends GutTest
## Story 004 — Rule 2 eligibility gate + D4 class routing.
## Covers AC-04 (UNKNOWN skip) / AC-09 (class→stat routing) / AC-25 (input sanity).

const PrDetectionScript := preload("res://src/autoload/pr_detection.gd")


## Mock #10 — fixed routing table keyed by exercise_id.
class MockClassMapping:
	extends RefCounted
	var table: Dictionary = {}  # exercise_id (String) -> AbilityClass ordinal

	func get_class_for_exercise(exercise_id: StringName) -> int:
		return table.get(String(exercise_id), 3)  # default UNKNOWN


var _sut: Node
var _mapping: MockClassMapping


func before_each() -> void:
	_mapping = MockClassMapping.new()
	_mapping.table = {
		"bench_press": 0,      # STRIKE
		"bent_over_row": 1,    # CONTROL
		"barbell_squat": 2,    # MOBILITY
	}
	_sut = PrDetectionScript.new()
	_sut._persistence = MockPersistenceLayer.new()
	_sut._class_mapping = _mapping
	add_child_autofree(_sut)


func _events() -> Array:
	return _sut.get_telemetry().map(func(e: Dictionary) -> String: return e["event"])


# --- AC-09: D4 class → stat routing (StatId values are LOWERCASE StringNames) ---

func test_routing_strike_to_str() -> void:
	assert_eq(_sut._eligibility_stat_id("bench_press", 5, 60.0), &"str")


func test_routing_control_to_dex() -> void:
	assert_eq(_sut._eligibility_stat_id("bent_over_row", 5, 60.0), &"dex")


func test_routing_mobility_to_vit() -> void:
	assert_eq(_sut._eligibility_stat_id("barbell_squat", 5, 60.0), &"vit")


# --- AC-04: UNKNOWN class → skip, zero side effects ------------------------------

func test_unknown_exercise_skips_with_telemetry_and_zero_side_effects() -> void:
	var result: StringName = _sut._eligibility_stat_id("treadmill_run", 5, 60.0)
	assert_eq(result, &"", "UNKNOWN must skip (Pillar 1 cardio gate)")
	assert_has(_events(), "pr.unknown_exercise")
	assert_true(_sut._pr_state.baselines.is_empty(), "zero baseline write on skip")
	assert_true(_sut._pr_state.candidates.is_empty(), "zero candidate write on skip")


# --- AC-25: input sanity — four pinned vectors -----------------------------------

func test_input_sanity_rejects_all_four_vectors() -> void:
	# (reps=0) / (weight=0) / (weight=600 > MAX) / (weight=0.5 < MIN)
	assert_eq(_sut._eligibility_stat_id("bench_press", 0, 60.0), &"")
	assert_eq(_sut._eligibility_stat_id("bench_press", 5, 0.0), &"")
	assert_eq(_sut._eligibility_stat_id("bench_press", 5, 600.0), &"")
	assert_eq(_sut._eligibility_stat_id("bench_press", 5, 0.5), &"")
	var invalid_count: int = _events().filter(
		func(e: String) -> bool: return e == "pr.input_invalid").size()
	assert_eq(invalid_count, 4, "each rejected vector emits pr.input_invalid")


func test_high_reps_are_not_a_skip_condition() -> void:
	# D7: clamp, not skip — 15 reps must still route.
	assert_eq(_sut._eligibility_stat_id("bench_press", 15, 100.0), &"str")

# EnemyDirector — Story 020 test-helper validation (runs each helper's _static_check).
#
# The Story 020 helpers have no direct ACs (validated indirectly when Stories 011-019 tests
# pass). This file gives them explicit evidence by exercising each _static_check() self-test.
extends GutTest

const RngHelper := preload("res://tests/helpers/rng_determinism_helper.gd")
const SignalRecorder := preload("res://tests/helpers/enemy_signal_recorder.gd")
const ArchetypeFactory := preload("res://tests/helpers/archetype_resource_factory.gd")
const MockWST := preload("res://tests/helpers/mock_workout_state_tracker.gd")
const Harness := preload("res://tests/helpers/enemy_director_test_harness.gd")


func test_rng_determinism_helper_static_check() -> void:
	assert_true(RngHelper._static_check(), "rng_determinism_helper _static_check passes")


func test_enemy_signal_recorder_static_check() -> void:
	assert_true(SignalRecorder._static_check(), "enemy_signal_recorder _static_check passes")


func test_archetype_resource_factory_static_check() -> void:
	assert_true(ArchetypeFactory._static_check(), "archetype_resource_factory _static_check passes")


func test_mock_workout_state_tracker_static_check() -> void:
	assert_true(MockWST._static_check(), "mock_workout_state_tracker _static_check passes")


func test_enemy_director_test_harness_static_check() -> void:
	assert_true(Harness._static_check(), "enemy_director_test_harness _static_check passes")


# ---------------------------------------------------------------------------
# A couple of direct behaviour checks beyond the self-tests
# ---------------------------------------------------------------------------

func test_rng_helper_detects_length_mismatch() -> void:
	var r: Dictionary = RngHelper.compare_sequences([1.0, 2.0], [1.0, 2.0, 3.0])
	assert_false(r["match"], "length mismatch is unequal")
	assert_eq(r["diff_count"], 1, "the extra tail element counts as 1 diff")


func test_archetype_factory_baselines_match_shipped_values() -> void:
	var reg := ArchetypeFactory.make_registry([&"MOBILITY"] as Array)
	var wd: WaveDescriptor = reg.archetypes[&"MOBILITY"]
	assert_almost_eq(wd._template_move_speed, 280.0, 0.001, "MOBILITY speed 280")
	assert_almost_eq(wd.archetype_cadence_mult, 0.75, 0.001, "MOBILITY cadence 0.75")


func test_harness_director_has_injected_mocks() -> void:
	var h: Dictionary = Harness.make_harness(7, &"MOBILITY")
	var director: Node = h["director"]
	assert_eq(director.get(&"_wst_source"), h["mocks"]["wst"], "harness injected the WST mock")
	assert_eq(director.get(&"_combat_resolver"), h["mocks"]["resolver"], "harness injected the resolver mock")
	director.free()

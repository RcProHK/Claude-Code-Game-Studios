## test_alias_and_edge.gd — #10 Exercise→Class Mapping, Story 004
##
## Governing story : production/epics/exercise-class-mapping/story-004-alias-and-edge.md
## GDD             : design/gdd/exercise-class-mapping.md (Approved 2026-06-02) — Rule 5/7 + Edge Cases
## Governing ADRs  : ADR-0007 (no-fabrication — miss / empty / failure all resolve to UNKNOWN)
##
## Test strategy:
##   - SUT is the ExerciseClassMapping autoload SCRIPT (no class_name, not yet registered) —
##     preload + instantiate directly, same pattern as the other #10 tests.
##   - Most cases use the _create_test_registry() factory (same _validate_entries + _build_lookup
##     path as _ready). The FAILED-state case (AC-06) instead injects _registry_loader_override
##     so _ready() takes the null/FAILED branch in-process — no .tres needed.
##   - Deterministic: no random seeds, no time-dependent logic, no filesystem I/O.
##   - We assert observable results (resolved value / bool). GUT cannot spy push_error/
##     push_warning, so the "once" half of AC-06/AC-11 is verified by the degrade result.
##
## AbilityClass ordinals: STRIKE=0, CONTROL=1, MOBILITY=2, UNKNOWN=3
extends GutTest

const ECM := preload("res://src/autoload/exercise_class_mapping.gd")

const _STRIKE: int = 0
const _CONTROL: int = 1
const _MOBILITY: int = 2
const _UNKNOWN: int = 3

var _sut


func before_each() -> void:
	_sut = ECM.new()
	add_child_autofree(_sut)


# ── TC-004-01 / 02: Alias resolution + normalize-before-resolve (AC-05 / AC-05b) ──

func test_alias_title_case_resolves_to_canonical_class() -> void:
	## AC-05: alias "Bench Press" → canonical bench_press → STRIKE.
	_sut._create_test_registry([
		{exercise_id = "bench_press", movement_pattern = 0, ability_class = _STRIKE, aliases = ["Bench Press"]}
	])
	assert_eq(_sut.get_class_for_exercise("Bench Press"), _STRIKE,
		"TC-004-01 AC-05: alias 'Bench Press' must resolve to canonical bench_press → STRIKE(0)")


func test_alias_lowercase_query_resolves_same_as_canonical() -> void:
	## AC-05b: alias stored "Bench Press", query "bench press" (lowercase) → normalize runs
	## BEFORE alias resolution, so it matches the same canonical class.
	_sut._create_test_registry([
		{exercise_id = "bench_press", movement_pattern = 0, ability_class = _STRIKE, aliases = ["Bench Press"]}
	])
	assert_eq(_sut.get_class_for_exercise("bench press"), _STRIKE,
		"TC-004-02 AC-05b: 'bench press' (lowercase) must resolve via normalized alias → STRIKE(0)")


func test_alias_all_caps_query_resolves() -> void:
	## AC-05b edge: "BENCH PRESS" (all caps) normalizes to bench_press → resolves.
	_sut._create_test_registry([
		{exercise_id = "bench_press", movement_pattern = 0, ability_class = _STRIKE, aliases = ["Bench Press"]}
	])
	assert_eq(_sut.get_class_for_exercise("BENCH PRESS"), _STRIKE,
		"TC-004-02 edge AC-05b: 'BENCH PRESS' (all caps) must normalize + resolve → STRIKE(0)")


# ── TC-004-03: FAILED via injectable seam (AC-06) ─────────────────────────────

func test_failed_state_all_lookups_return_unknown() -> void:
	## AC-06: _load_registry() override returns null → FAILED → every lookup UNKNOWN, no crash.
	## Subsequent calls stay UNKNOWN (state persists; push_error fires once in _ready only).
	var failed_sut = ECM.new()
	failed_sut._registry_loader_override = func() -> Resource: return null
	add_child_autofree(failed_sut)  # _ready() takes the null/FAILED branch

	assert_eq(failed_sut.get_class_for_exercise("any"), _UNKNOWN,
		"TC-004-03 AC-06: FAILED state must return UNKNOWN(3) for any id")
	assert_eq(failed_sut.get_class_for_exercise("bench_press"), _UNKNOWN,
		"TC-004-03 AC-06: subsequent FAILED lookup still UNKNOWN(3) (no recovery, no crash)")
	assert_false(failed_sut.is_known_exercise("bench_press"),
		"TC-004-03 AC-06: is_known_exercise in FAILED state must be false")


# ── TC-004-04 / 05: Empty input → UNKNOWN + push_warning (AC-11) ──────────────

func test_empty_string_returns_unknown() -> void:
	## AC-11: "" → UNKNOWN(3), no crash (push_warning fires; GUT can't assert it directly).
	_sut._create_test_registry([
		{exercise_id = "bench_press", movement_pattern = 0, ability_class = _STRIKE}
	])
	assert_eq(_sut.get_class_for_exercise(""), _UNKNOWN,
		"TC-004-04 AC-11: empty String must return UNKNOWN(3)")


func test_empty_stringname_returns_unknown() -> void:
	## AC-11: &"" → normalize converts to "" → empty branch → UNKNOWN(3).
	_sut._create_test_registry([
		{exercise_id = "bench_press", movement_pattern = 0, ability_class = _STRIKE}
	])
	assert_eq(_sut.get_class_for_exercise(&""), _UNKNOWN,
		"TC-004-05 AC-11: empty StringName &\"\" must normalize to \"\" and return UNKNOWN(3)")


# ── TC-004-06..09: is_known_exercise (AC-14a/b/c/d) ──────────────────────────

func test_is_known_returns_true_for_known_id() -> void:
	## AC-14a: known canonical id → true.
	_sut._create_test_registry([
		{exercise_id = "bench_press", movement_pattern = 0, ability_class = _STRIKE}
	])
	assert_true(_sut.is_known_exercise("bench_press"),
		"TC-004-06 AC-14a: is_known_exercise('bench_press') must be true")


func test_is_known_returns_false_for_unknown_id() -> void:
	## AC-14b: unknown id → false.
	_sut._create_test_registry([
		{exercise_id = "bench_press", movement_pattern = 0, ability_class = _STRIKE}
	])
	assert_false(_sut.is_known_exercise("nonexistent"),
		"TC-004-07 AC-14b: is_known_exercise('nonexistent') must be false")


func test_is_known_returns_true_for_unnormalized_alias() -> void:
	## AC-14c: unnormalized alias query → true (shares normalize + alias path with get_class).
	_sut._create_test_registry([
		{exercise_id = "bench_press", movement_pattern = 0, ability_class = _STRIKE, aliases = ["Bench Press"]}
	])
	assert_true(_sut.is_known_exercise("Bench Press"),
		"TC-004-08 AC-14c: is_known_exercise('Bench Press') must resolve via alias → true")


func test_is_known_returns_false_for_empty_input_no_crash() -> void:
	## AC-14d: "" and &"" → false, no crash, no push_warning (warning belongs to get_class).
	_sut._create_test_registry([
		{exercise_id = "bench_press", movement_pattern = 0, ability_class = _STRIKE}
	])
	assert_false(_sut.is_known_exercise(""),
		"TC-004-09 AC-14d: is_known_exercise('') must be false")
	assert_false(_sut.is_known_exercise(&""),
		"TC-004-09 AC-14d: is_known_exercise(&\"\") must be false, no crash")


# ── TC-004-10: Alias collision — alias vs canonical (AC-15 A) ─────────────────

func test_alias_colliding_with_canonical_id_is_skipped() -> void:
	## AC-15 A: entry B aliases "bench_press" which is entry A's canonical id → alias skipped,
	## canonical A (STRIKE) wins; entry B's own id (lat_pulldown) still resolves to CONTROL.
	_sut._create_test_registry([
		{exercise_id = "bench_press", movement_pattern = 0, ability_class = _STRIKE},
		{exercise_id = "lat_pulldown", movement_pattern = 1, ability_class = _CONTROL, aliases = ["bench_press"]},
	])
	assert_eq(_sut.get_class_for_exercise("bench_press"), _STRIKE,
		"TC-004-10 AC-15A: canonical bench_press(STRIKE) wins over colliding alias")
	assert_eq(_sut.get_class_for_exercise("lat_pulldown"), _CONTROL,
		"TC-004-10 AC-15A: entry B's own id lat_pulldown still resolves to CONTROL(1)")


# ── TC-004-11: Alias collision — alias vs alias (AC-15 B) ─────────────────────

func test_alias_vs_alias_collision_first_listed_wins() -> void:
	## AC-15 B: two entries both alias "shared_alias" → first-listed (entry A) wins.
	_sut._create_test_registry([
		{exercise_id = "exercise_a", movement_pattern = 0, ability_class = _STRIKE, aliases = ["shared_alias"]},
		{exercise_id = "exercise_b", movement_pattern = 1, ability_class = _CONTROL, aliases = ["shared_alias"]},
	])
	assert_eq(_sut.get_class_for_exercise("shared_alias"), _STRIKE,
		"TC-004-11 AC-15B: alias-vs-alias collision — first-listed (exercise_a, STRIKE) wins")
	assert_eq(_sut.get_class_for_exercise("exercise_b"), _CONTROL,
		"TC-004-11 AC-15B: entry B's own id exercise_b still resolves to CONTROL(1)")


func test_three_entries_same_alias_first_listed_wins() -> void:
	## AC-15 B edge: three entries claim the same alias → first wins, rest skipped.
	_sut._create_test_registry([
		{exercise_id = "first_ex", movement_pattern = 2, ability_class = _MOBILITY, aliases = ["triple_alias"]},
		{exercise_id = "second_ex", movement_pattern = 0, ability_class = _STRIKE, aliases = ["triple_alias"]},
		{exercise_id = "third_ex", movement_pattern = 1, ability_class = _CONTROL, aliases = ["triple_alias"]},
	])
	assert_eq(_sut.get_class_for_exercise("triple_alias"), _MOBILITY,
		"TC-004-11 edge AC-15B: three same aliases — first-listed (first_ex, MOBILITY) wins")

## registry_lookup_test.gd — #10 Exercise→Class Mapping, Story 001
##
## Governing story : production/epics/exercise-class-mapping/story-001-registry-lookup.md
## GDD             : design/gdd/exercise-class-mapping.md (Approved 2026-06-02)
## Governing ADRs  : ADR-0007 (AbilityClass Classification enum — zero-default FORBIDDEN)
##
## Test strategy:
##   - Uses _create_test_registry(Array[Dictionary]) factory — zero ExerciseEntry.new(),
##     zero class_name cache dependency → headless GUT safe (no local Godot install needed).
##   - Deterministic: no random seeds, no time-dependent logic, no filesystem I/O.
##   - Each TC matches exactly one QA Test Case from the story (TC-001-01..06).
##
## AbilityClass ordinals (AbilitySystem inner enum — cannot cross-file import at boot):
##   STRIKE=0, CONTROL=1, MOBILITY=2, UNKNOWN=3
extends GutTest

# ── Shared fixture constants ─────────────────────────────────────────────────
const _STRIKE: int = 0    ## AbilitySystem.AbilityClass.STRIKE
const _CONTROL: int = 1   ## AbilitySystem.AbilityClass.CONTROL
const _MOBILITY: int = 2  ## AbilitySystem.AbilityClass.MOBILITY
const _UNKNOWN: int = 3   ## AbilitySystem.AbilityClass.UNKNOWN

# SUT instance — fresh per test via before_each
var _sut: ExerciseClassMapping


func before_each() -> void:
	_sut = ExerciseClassMapping.new()


func after_each() -> void:
	_sut = null


# ── TC-001-01: Registry exact hit (AC-01) ────────────────────────────────────

func test_registry_exact_hit_returns_strike() -> void:
	## TC-001-01: basic happy-path lookup.
	## GIVEN registry with {exercise_id:"test_push_a", ability_class:0 (STRIKE)}
	## WHEN  get_class_for_exercise("test_push_a")
	## THEN  returns 0 (STRIKE ordinal)
	# Arrange
	_sut._create_test_registry([
		{exercise_id = "test_push_a", movement_pattern = 0, ability_class = _STRIKE}
	])
	# Act
	var result: int = _sut.get_class_for_exercise("test_push_a")
	# Assert
	assert_eq(result, _STRIKE,
		"TC-001-01 AC-01: exact hit on 'test_push_a' must return STRIKE(0)")


func test_registry_exact_hit_returns_control() -> void:
	## TC-001-01 variant: verify CONTROL round-trip.
	_sut._create_test_registry([
		{exercise_id = "bent_over_row", movement_pattern = 1, ability_class = _CONTROL}
	])
	var result: int = _sut.get_class_for_exercise("bent_over_row")
	assert_eq(result, _CONTROL,
		"TC-001-01 variant: exact hit on 'bent_over_row' must return CONTROL(1)")


func test_registry_exact_hit_returns_mobility() -> void:
	## TC-001-01 variant: verify MOBILITY round-trip.
	_sut._create_test_registry([
		{exercise_id = "barbell_squat", movement_pattern = 2, ability_class = _MOBILITY}
	])
	var result: int = _sut.get_class_for_exercise("barbell_squat")
	assert_eq(result, _MOBILITY,
		"TC-001-01 variant: exact hit on 'barbell_squat' must return MOBILITY(2)")


# ── TC-001-02: Registry miss → UNKNOWN (AC-03 id-side) ──────────────────────

func test_empty_registry_returns_unknown() -> void:
	## TC-001-02a: empty registry — every query must return UNKNOWN.
	## GIVEN empty registry
	## WHEN  get_class_for_exercise("nonexistent_exercise")
	## THEN  returns 3 (UNKNOWN)
	# Arrange
	_sut._create_test_registry([])
	# Act
	var result: int = _sut.get_class_for_exercise("nonexistent_exercise")
	# Assert
	assert_eq(result, _UNKNOWN,
		"TC-001-02a AC-03: empty registry must return UNKNOWN(3) for any query")


func test_nonempty_registry_miss_returns_unknown() -> void:
	## TC-001-02b: registry has entries, but query id is absent.
	# Arrange
	_sut._create_test_registry([
		{exercise_id = "bench_press", movement_pattern = 0, ability_class = _STRIKE}
	])
	# Act
	var result: int = _sut.get_class_for_exercise("unknown_yoga_flow_x")
	# Assert
	assert_eq(result, _UNKNOWN,
		"TC-001-02b AC-03: missing id must return UNKNOWN(3) even when registry has other entries")


# ── TC-001-03: Precedence — ability_class overrides movement_pattern (AC-04) ─

func test_precedence_ability_class_wins_over_movement_pattern() -> void:
	## TC-001-03: exercise has PUSH pattern(0) but ability_class=CONTROL(1).
	## get_class_for_exercise reads ability_class, NOT movement_pattern.
	## GIVEN {exercise_id:"test_conflict", movement_pattern:0 (PUSH), ability_class:1 (CONTROL)}
	## WHEN  get_class_for_exercise("test_conflict")
	## THEN  returns 1 (CONTROL), NOT 0 (STRIKE)
	# Arrange
	_sut._create_test_registry([
		{exercise_id = "test_conflict", movement_pattern = _STRIKE, ability_class = _CONTROL}
	])
	# Act
	var result: int = _sut.get_class_for_exercise("test_conflict")
	# Assert
	assert_eq(result, _CONTROL,
		"TC-001-03 AC-04: ability_class=CONTROL must win over movement_pattern=PUSH(STRIKE ordinal)")
	assert_ne(result, _STRIKE,
		"TC-001-03 AC-04: must NOT return STRIKE (movement_pattern value) — two entry points independent")


# ── TC-001-04: Determinism (AC-08) ──────────────────────────────────────────

func test_determinism_same_id_two_lookups_identical() -> void:
	## TC-001-04: same exercise_id, two sequential lookups → identical result.
	## GIVEN registry with test_push_a
	## WHEN  get_class_for_exercise("test_push_a") twice
	## THEN  both return 0 (STRIKE), r1 == r2
	# Arrange
	_sut._create_test_registry([
		{exercise_id = "test_push_a", movement_pattern = 0, ability_class = _STRIKE}
	])
	# Act
	var r1: int = _sut.get_class_for_exercise("test_push_a")
	var r2: int = _sut.get_class_for_exercise("test_push_a")
	# Assert
	assert_eq(r1, _STRIKE, "TC-001-04 AC-08: first lookup must return STRIKE(0)")
	assert_eq(r2, _STRIKE, "TC-001-04 AC-08: second lookup must return STRIKE(0)")
	assert_eq(r1, r2, "TC-001-04 AC-08: both lookups must be identical (determinism)")


# ── TC-001-05: Normalize — space→underscore + lowercase (AC-10) ──────────────

func test_normalize_space_to_underscore_lookup_matches_canonical() -> void:
	## TC-001-05a: "bench press" (space) must resolve same as canonical "bench_press".
	## GIVEN registry with canonical "bench_press"
	## WHEN  get_class_for_exercise("bench press")
	## THEN  returns STRIKE(0) — same as canonical lookup
	# Arrange
	_sut._create_test_registry([
		{exercise_id = "bench_press", movement_pattern = 0, ability_class = _STRIKE}
	])
	# Act
	var result_space: int = _sut.get_class_for_exercise("bench press")
	var result_canonical: int = _sut.get_class_for_exercise("bench_press")
	# Assert
	assert_eq(result_space, _STRIKE,
		"TC-001-05a AC-10: 'bench press' (space) must normalize to 'bench_press' → STRIKE(0)")
	assert_eq(result_space, result_canonical,
		"TC-001-05a AC-10: space variant and canonical must return identical result")


func test_normalize_titlecase_underscore_lookup_matches_canonical() -> void:
	## TC-001-05b: "Bench_Press" (title case) must resolve same as canonical "bench_press".
	# Arrange
	_sut._create_test_registry([
		{exercise_id = "bench_press", movement_pattern = 0, ability_class = _STRIKE}
	])
	# Act
	var result_title: int = _sut.get_class_for_exercise("Bench_Press")
	# Assert
	assert_eq(result_title, _STRIKE,
		"TC-001-05b AC-10: 'Bench_Press' (title case) must normalize to 'bench_press' → STRIKE(0)")


func test_normalize_double_space_collapses_to_underscore() -> void:
	## TC-001-05c: "BENCH  PRESS" (double space) → "bench_press" → STRIKE.
	## Edge case from story QA Test Cases TC-001-05.
	# Arrange
	_sut._create_test_registry([
		{exercise_id = "bench_press", movement_pattern = 0, ability_class = _STRIKE}
	])
	# Act
	var result: int = _sut.get_class_for_exercise("BENCH  PRESS")
	# Assert
	assert_eq(result, _STRIKE,
		"TC-001-05c AC-10: 'BENCH  PRESS' (double space) must normalize to 'bench_press' → STRIKE(0)")


# ── TC-001-06: StringName cast (AC / _normalize first line) ─────────────────

func test_stringname_input_resolves_same_as_string() -> void:
	## TC-001-06: &"bench_press" (StringName) must return same result as String "bench_press".
	## GDScript 4.x: &"bench_press" != "bench_press" as Dictionary key without cast.
	## _normalize() first line: String(raw) forces the cast.
	## GIVEN registry with "bench_press"
	## WHEN  get_class_for_exercise(&"bench_press") — StringName
	## THEN  returns STRIKE(0) same as string input
	# Arrange
	_sut._create_test_registry([
		{exercise_id = "bench_press", movement_pattern = 0, ability_class = _STRIKE}
	])
	# Act — StringName literal
	var result_stringname: int = _sut.get_class_for_exercise(&"bench_press")
	var result_string: int = _sut.get_class_for_exercise("bench_press")
	# Assert
	assert_eq(result_stringname, _STRIKE,
		"TC-001-06: &'bench_press' (StringName) must resolve to STRIKE(0) after _normalize cast")
	assert_eq(result_stringname, result_string,
		"TC-001-06: StringName and String inputs must return identical result")


func test_empty_stringname_returns_unknown_no_crash() -> void:
	## TC-001-06 edge: &"" (empty StringName) → UNKNOWN, no crash.
	## AC-11 push_warning is a Story 004 addition; here we just verify no crash + UNKNOWN.
	# Arrange
	_sut._create_test_registry([
		{exercise_id = "bench_press", movement_pattern = 0, ability_class = _STRIKE}
	])
	# Act
	var result: int = _sut.get_class_for_exercise(&"")
	# Assert
	assert_eq(result, _UNKNOWN,
		"TC-001-06 edge AC-11: empty StringName must return UNKNOWN(3) without crash")


# ── AC-07: Invalid ability_class → force UNKNOWN (via _validate_entries) ─────

func test_invalid_ability_class_ordinal_forced_to_unknown() -> void:
	## AC-07: entry with ability_class=99 (∉ {0,1,2,3}) → forced to UNKNOWN(3).
	## Verifies _validate_entries() is called by factory (same path as _ready()).
	# Arrange
	_sut._create_test_registry([
		{exercise_id = "bad_entry", movement_pattern = 0, ability_class = 99}
	])
	# Act
	var result: int = _sut.get_class_for_exercise("bad_entry")
	# Assert
	assert_eq(result, _UNKNOWN,
		"AC-07: ability_class=99 (invalid ordinal) must be forced to UNKNOWN(3) by _validate_entries()")


func test_sentinel_minus_one_ability_class_forced_to_unknown() -> void:
	## AC-07: entry with ability_class=-1 (unset sentinel) → forced to UNKNOWN(3).
	## Prevents silent zero-default STRIKE fabrication (ADR-0007 FORBIDDEN).
	# Arrange
	_sut._create_test_registry([
		{exercise_id = "unset_entry", movement_pattern = 0, ability_class = -1}
	])
	# Act
	var result: int = _sut.get_class_for_exercise("unset_entry")
	# Assert
	assert_eq(result, _UNKNOWN,
		"AC-07: ability_class=-1 (unset sentinel) must be forced to UNKNOWN(3) — not silently fabricate STRIKE")


# ── AC-07b: Invalid movement_pattern coerced, but ability_class still served ─

func test_invalid_movement_pattern_does_not_discard_valid_ability_class() -> void:
	## AC-07b: movement_pattern=99 (invalid) → coerced to UNKNOWN_PATTERN(7),
	## but ability_class=STRIKE(0) is still served — invalid movement_pattern ≠ discard entry.
	# Arrange
	_sut._create_test_registry([
		{exercise_id = "bad_pattern_entry", movement_pattern = 99, ability_class = _STRIKE}
	])
	# Act
	var result: int = _sut.get_class_for_exercise("bad_pattern_entry")
	# Assert
	assert_eq(result, _STRIKE,
		"AC-07b: invalid movement_pattern=99 must NOT discard entry — ability_class=STRIKE must still be served")


# ── AC-12: Authored UNKNOWN(3) is legal — no error ───────────────────────────

func test_authored_unknown_ability_class_is_legal_returns_unknown() -> void:
	## AC-12: entry with ability_class=UNKNOWN(3) authored intentionally.
	## Must return UNKNOWN(3) with NO push_error (intentional, not a failure).
	## No way to assert absence of push_error in GUT — we verify the return value only.
	## (The absence of error is validated by the _validate_entries condition: ac > 3 → error;
	##  UNKNOWN=3 is NOT > 3, so no error branch fires.)
	# Arrange
	_sut._create_test_registry([
		{exercise_id = "intentional_unknown", movement_pattern = 7, ability_class = _UNKNOWN}
	])
	# Act
	var result: int = _sut.get_class_for_exercise("intentional_unknown")
	# Assert
	assert_eq(result, _UNKNOWN,
		"AC-12: authored ability_class=UNKNOWN(3) must return UNKNOWN(3) — intentional, not a failure")

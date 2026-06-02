## test_boot_validation.gd — #10 Exercise→Class Mapping, Story 003
##
## Governing story : production/epics/exercise-class-mapping/story-003-boot-validation.md
## GDD             : design/gdd/exercise-class-mapping.md (Approved 2026-06-02) — Rule 3 boot validation
## Governing ADRs  : ADR-0007 (zero-default fabrication FORBIDDEN — unset/invalid Classification
##                   field must be detected, never silently pass through as ordinal 0)
##
## Test strategy:
##   - SUT is the ExerciseClassMapping autoload SCRIPT (no class_name, not yet registered) —
##     preload + instantiate directly, same pattern as test_registry_lookup.gd.
##   - Boot validation is exercised through the _create_test_registry() factory, which runs the
##     SAME _validate_entries() + _build_lookup() path as _ready() (GDD AC-07 Pass-2 note: the
##     factory MUST trigger the same validation, otherwise boot validation is never tested).
##   - Deterministic: no random seeds, no time-dependent logic, no filesystem I/O.
##   - We assert the OBSERVABLE result of validation (resolved lookup value / first-wins).
##     GUT cannot spy the global push_error, so the "push_error once" half of each AC is verified
##     by the forced-coercion result rather than by intercepting the error (same convention as
##     Story 001's AC-12 test).
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


# ── TC-003-01: Invalid ability_class out-of-range (AC-07 case A) ──────────────

func test_out_of_range_ability_class_resolves_to_unknown() -> void:
	## AC-07 A: ability_class=99 (∉ {0,1,2,3}) → forced to UNKNOWN(3).
	_sut._create_test_registry([
		{exercise_id = "bad_ordinal", movement_pattern = 0, ability_class = 99}
	])
	assert_eq(_sut.get_class_for_exercise("bad_ordinal"), _UNKNOWN,
		"TC-003-01 AC-07: ability_class=99 must resolve to UNKNOWN(3)")


func test_ability_class_one_above_max_resolves_to_unknown() -> void:
	## AC-07 A edge: ability_class=4 (one above the valid max of 3) → UNKNOWN(3).
	_sut._create_test_registry([
		{exercise_id = "above_max", movement_pattern = 0, ability_class = 4}
	])
	assert_eq(_sut.get_class_for_exercise("above_max"), _UNKNOWN,
		"TC-003-01 edge AC-07: ability_class=4 (one above max) must resolve to UNKNOWN(3)")


func test_ability_class_below_sentinel_resolves_to_unknown() -> void:
	## AC-07 A edge: ability_class=-2 (below the -1 sentinel) → UNKNOWN(3).
	## Guards against an impl that only checks `> 3` and misses negatives.
	_sut._create_test_registry([
		{exercise_id = "below_sentinel", movement_pattern = 0, ability_class = -2}
	])
	assert_eq(_sut.get_class_for_exercise("below_sentinel"), _UNKNOWN,
		"TC-003-01 edge AC-07: ability_class=-2 (below sentinel) must resolve to UNKNOWN(3)")


# ── TC-003-02: Unset ability_class sentinel -1 (AC-07 case B) ─────────────────

func test_unset_sentinel_ability_class_resolves_to_unknown() -> void:
	## AC-07 B: ability_class=-1 (unset sentinel — author forgot to fill) → UNKNOWN(3).
	## Core zero-default fabrication guard (ADR-0007): -1 must NOT become STRIKE(0).
	_sut._create_test_registry([
		{exercise_id = "unset_entry", movement_pattern = 0, ability_class = -1}
	])
	assert_eq(_sut.get_class_for_exercise("unset_entry"), _UNKNOWN,
		"TC-003-02 AC-07: ability_class=-1 (unset) must resolve to UNKNOWN(3), never fabricate STRIKE")


# ── TC-003-03: Invalid movement_pattern — entry NOT discarded (AC-07b) ────────

func test_invalid_movement_pattern_entry_still_serves_ability_class() -> void:
	## AC-07b: movement_pattern=99 (∉ {0..7}) but ability_class=STRIKE(0) valid →
	## movement_pattern coerced to UNKNOWN_PATTERN(7) but entry NOT discarded; the valid
	## ability_class is still served (get_class_for_exercise reads ability_class, Formula 1a).
	_sut._create_test_registry([
		{exercise_id = "bad_pattern", movement_pattern = 99, ability_class = _STRIKE}
	])
	assert_eq(_sut.get_class_for_exercise("bad_pattern"), _STRIKE,
		"TC-003-03 AC-07b: invalid movement_pattern must NOT discard entry — ability_class=STRIKE served")


func test_unset_movement_pattern_entry_still_serves_ability_class() -> void:
	## AC-07b edge: movement_pattern=-1 (unset sentinel, ∉ {0..7}) but valid ability_class →
	## entry still served. Confirms the -1 unset path is treated as invalid (push_error) yet
	## does NOT discard the entry.
	_sut._create_test_registry([
		{exercise_id = "unset_pattern", movement_pattern = -1, ability_class = _CONTROL}
	])
	assert_eq(_sut.get_class_for_exercise("unset_pattern"), _CONTROL,
		"TC-003-03 edge AC-07b: movement_pattern=-1 must not discard entry — ability_class=CONTROL served")


func test_movement_pattern_eight_entry_still_serves_ability_class() -> void:
	## AC-07b edge: movement_pattern=8 (one above the valid max of 7) but valid ability_class.
	_sut._create_test_registry([
		{exercise_id = "pattern_eight", movement_pattern = 8, ability_class = _MOBILITY}
	])
	assert_eq(_sut.get_class_for_exercise("pattern_eight"), _MOBILITY,
		"TC-003-03 edge AC-07b: movement_pattern=8 must not discard entry — ability_class=MOBILITY served")


# ── TC-003-04: Duplicate exercise_id — first wins (AC-09) ─────────────────────

func test_duplicate_exercise_id_first_entry_wins() -> void:
	## AC-09: two entries with id "dup_entry" (1st STRIKE, 2nd CONTROL) → first wins.
	_sut._create_test_registry([
		{exercise_id = "dup_entry", movement_pattern = 0, ability_class = _STRIKE},
		{exercise_id = "dup_entry", movement_pattern = 1, ability_class = _CONTROL},
	])
	assert_eq(_sut.get_class_for_exercise("dup_entry"), _STRIKE,
		"TC-003-04 AC-09: duplicate exercise_id — first-listed (STRIKE) must win")


func test_triple_duplicate_exercise_id_first_entry_wins() -> void:
	## AC-09 edge: three duplicates — first wins, 2nd & 3rd skipped.
	_sut._create_test_registry([
		{exercise_id = "triple", movement_pattern = 2, ability_class = _MOBILITY},
		{exercise_id = "triple", movement_pattern = 0, ability_class = _STRIKE},
		{exercise_id = "triple", movement_pattern = 1, ability_class = _CONTROL},
	])
	assert_eq(_sut.get_class_for_exercise("triple"), _MOBILITY,
		"TC-003-04 edge AC-09: three duplicates — first-listed (MOBILITY) must win")


func test_duplicate_after_normalize_first_entry_wins() -> void:
	## AC-09 edge: ids that collide only after normalization ("Dup Entry" == "dup_entry").
	_sut._create_test_registry([
		{exercise_id = "norm_dup", movement_pattern = 0, ability_class = _STRIKE},
		{exercise_id = "NORM DUP", movement_pattern = 1, ability_class = _CONTROL},
	])
	assert_eq(_sut.get_class_for_exercise("norm_dup"), _STRIKE,
		"TC-003-04 edge AC-09: normalized-collision duplicate — first-listed (STRIKE) must win")


# ── TC-003-05: Authored UNKNOWN legal — no push_error (AC-12) ─────────────────

func test_authored_unknown_ability_class_is_legal() -> void:
	## AC-12: ability_class=UNKNOWN(3) authored intentionally → returns UNKNOWN(3).
	## Distinct from the AC-07 invalid path (99 / -1): 3 is a valid ordinal, so NO push_error
	## fires (3 is neither < 0 nor > 3). GUT cannot assert error-absence directly; we verify the
	## value resolves to 3 and rely on the validation condition (only < 0 or > 3 errors).
	_sut._create_test_registry([
		{exercise_id = "intentional_unknown", movement_pattern = 7, ability_class = _UNKNOWN}
	])
	assert_eq(_sut.get_class_for_exercise("intentional_unknown"), _UNKNOWN,
		"TC-003-05 AC-12: authored ability_class=UNKNOWN(3) must return UNKNOWN(3) — intentional, not a failure")


func test_authored_unknown_with_valid_pattern_no_coercion() -> void:
	## AC-12 companion: authored UNKNOWN(3) with a VALID movement_pattern(7=UNKNOWN_PATTERN)
	## must still resolve to UNKNOWN(3) and not be treated as an invalid entry.
	_sut._create_test_registry([
		{exercise_id = "valid_unknown_pair", movement_pattern = 2, ability_class = _UNKNOWN}
	])
	assert_eq(_sut.get_class_for_exercise("valid_unknown_pair"), _UNKNOWN,
		"TC-003-05 AC-12: authored UNKNOWN(3) with valid movement_pattern resolves to UNKNOWN(3)")

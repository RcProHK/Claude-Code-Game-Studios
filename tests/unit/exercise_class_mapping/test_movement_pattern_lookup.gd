## test_movement_pattern_lookup.gd — #10 Exercise→Class Mapping, Story 002
##
## Governing story : production/epics/exercise-class-mapping/story-002-movement-pattern-lookup.md
## GDD             : design/gdd/exercise-class-mapping.md (Approved 2026-06-02) — Rule 4b / Formula 1b
## Governing ADRs  : ADR-0007 (Classification enum — declaration order load-bearing,
##                   sentinel last, zero-default fabrication FORBIDDEN)
##
## Test strategy:
##   - SUT is the ExerciseClassMapping autoload SCRIPT (no class_name, not yet registered) —
##     preload + instantiate directly, same pattern as test_registry_lookup.gd.
##   - get_class_for_movement_pattern() is a pure function: no registry, no state, no I/O.
##   - Deterministic: no random seeds, no time-dependent logic.
##   - Each TC matches one QA Test Case from the story (TC-002-01..09) + the ADVISORY
##     enum-ordinal guard.
##
## AbilityClass ordinals: STRIKE=0, CONTROL=1, MOBILITY=2, UNKNOWN=3
extends GutTest

# ── SUT script (no class_name → preload) ─────────────────────────────────────
const ECM := preload("res://src/autoload/exercise_class_mapping.gd")

# ── AbilityClass result ordinals ─────────────────────────────────────────────
const _STRIKE: int = 0
const _CONTROL: int = 1
const _MOBILITY: int = 2
const _UNKNOWN: int = 3

var _sut


func before_each() -> void:
	_sut = ECM.new()
	add_child_autofree(_sut)


# ── TC-002-01..03: Spine mapping (AC-02) ─────────────────────────────────────

func test_push_pattern_returns_strike() -> void:
	## TC-002-01: PUSH(0) → STRIKE(0).
	# Act
	var result: int = _sut.get_class_for_movement_pattern(ECM.MovementPattern.PUSH)
	# Assert
	assert_eq(result, _STRIKE,
		"TC-002-01 AC-02: PUSH(0) must map to STRIKE(0)")


func test_pull_pattern_returns_control() -> void:
	## TC-002-02: PULL(1) → CONTROL(1).
	var result: int = _sut.get_class_for_movement_pattern(ECM.MovementPattern.PULL)
	assert_eq(result, _CONTROL,
		"TC-002-02 AC-02: PULL(1) must map to CONTROL(1)")


func test_leg_pattern_returns_mobility() -> void:
	## TC-002-03: LEG(2) → MOBILITY(2). Confirms LEG is a singular enum member.
	var result: int = _sut.get_class_for_movement_pattern(ECM.MovementPattern.LEG)
	assert_eq(result, _MOBILITY,
		"TC-002-03 AC-02: LEG(2) must map to MOBILITY(2)")


# ── TC-002-04: Unknown / out-of-range pattern → UNKNOWN (AC-03 pattern-side) ──

func test_unknown_pattern_value_returns_unknown() -> void:
	## TC-002-04: arbitrary unmapped value 99 → UNKNOWN(3), never fabricated.
	var result: int = _sut.get_class_for_movement_pattern(99)
	assert_eq(result, _UNKNOWN,
		"TC-002-04 AC-03: pattern 99 (unmapped) must return UNKNOWN(3) — never fabricate STRIKE")


func test_negative_pattern_returns_unknown() -> void:
	## TC-002-04 edge: -1 (authoring sentinel / negative) → UNKNOWN(3).
	var result: int = _sut.get_class_for_movement_pattern(-1)
	assert_eq(result, _UNKNOWN,
		"TC-002-04 edge AC-03: pattern -1 must return UNKNOWN(3) without crash")


func test_byte_max_pattern_returns_unknown() -> void:
	## TC-002-04 edge: 255 → UNKNOWN(3).
	var result: int = _sut.get_class_for_movement_pattern(255)
	assert_eq(result, _UNKNOWN,
		"TC-002-04 edge AC-03: pattern 255 must return UNKNOWN(3)")


func test_int_max_pattern_returns_unknown() -> void:
	## TC-002-04 edge: MAX_INT → UNKNOWN(3), no overflow/crash.
	var result: int = _sut.get_class_for_movement_pattern(9223372036854775807)
	assert_eq(result, _UNKNOWN,
		"TC-002-04 edge AC-03: pattern MAX_INT must return UNKNOWN(3)")


# ── TC-002-05..09: Non-spine ordinals → UNKNOWN (AC-13) ──────────────────────

func test_core_pattern_returns_unknown() -> void:
	## TC-002-05: CORE(3) → UNKNOWN(3).
	var result: int = _sut.get_class_for_movement_pattern(ECM.MovementPattern.CORE)
	assert_eq(result, _UNKNOWN,
		"TC-002-05 AC-13: CORE(3) must return UNKNOWN(3) — non-spine pattern")


func test_cardio_pattern_returns_unknown() -> void:
	## TC-002-06: CARDIO(4) → UNKNOWN(3).
	var result: int = _sut.get_class_for_movement_pattern(ECM.MovementPattern.CARDIO)
	assert_eq(result, _UNKNOWN,
		"TC-002-06 AC-13: CARDIO(4) must return UNKNOWN(3) — non-spine pattern")


func test_flexibility_pattern_returns_unknown() -> void:
	## TC-002-07: FLEXIBILITY(5) → UNKNOWN(3).
	var result: int = _sut.get_class_for_movement_pattern(ECM.MovementPattern.FLEXIBILITY)
	assert_eq(result, _UNKNOWN,
		"TC-002-07 AC-13: FLEXIBILITY(5) must return UNKNOWN(3) — non-spine pattern")


func test_compound_pattern_returns_unknown() -> void:
	## TC-002-08: COMPOUND(6) → UNKNOWN(3).
	## Design intent: compound exercises must use an explicit registry entry via
	## get_class_for_exercise(), NOT the pattern API — so COMPOUND is deliberately unmapped.
	var result: int = _sut.get_class_for_movement_pattern(ECM.MovementPattern.COMPOUND)
	assert_eq(result, _UNKNOWN,
		"TC-002-08 AC-13: COMPOUND(6) must return UNKNOWN(3) — must resolve via registry id-lookup, not pattern")


func test_sentinel_unknown_pattern_returns_unknown() -> void:
	## TC-002-09: UNKNOWN_PATTERN(7) sentinel → UNKNOWN(3), no crash.
	var result: int = _sut.get_class_for_movement_pattern(ECM.MovementPattern.UNKNOWN_PATTERN)
	assert_eq(result, _UNKNOWN,
		"TC-002-09 AC-13: UNKNOWN_PATTERN(7) sentinel must return UNKNOWN(3)")


# ── ADVISORY: enum declaration order guard ───────────────────────────────────

func test_movement_pattern_enum_ordinals_are_stable() -> void:
	## ADVISORY (story QA): guard against silent ordinal shift. The spine relies on
	## PUSH=0 / PULL=1 / LEG=2 aligning 1:1:1 with AbilityClass; UNKNOWN_PATTERN MUST
	## stay last (ADR-0007 sentinel-last + no zero-default fabrication).
	assert_eq(ECM.MovementPattern.PUSH, 0, "PUSH must be ordinal 0 (spine align with STRIKE)")
	assert_eq(ECM.MovementPattern.PULL, 1, "PULL must be ordinal 1 (spine align with CONTROL)")
	assert_eq(ECM.MovementPattern.LEG, 2, "LEG must be ordinal 2 (spine align with MOBILITY)")
	assert_eq(ECM.MovementPattern.CORE, 3, "CORE must be ordinal 3")
	assert_eq(ECM.MovementPattern.CARDIO, 4, "CARDIO must be ordinal 4")
	assert_eq(ECM.MovementPattern.FLEXIBILITY, 5, "FLEXIBILITY must be ordinal 5")
	assert_eq(ECM.MovementPattern.COMPOUND, 6, "COMPOUND must be ordinal 6")
	assert_eq(ECM.MovementPattern.UNKNOWN_PATTERN, 7, "UNKNOWN_PATTERN sentinel must stay last (ordinal 7)")


func test_movement_pattern_independent_from_exercise_lookup() -> void:
	## Rule 5 guard: pattern API must NOT touch the registry. With an empty registry,
	## the spine still resolves (proves no get_class_for_exercise fallback path).
	# Arrange — empty registry (would make all id-lookups UNKNOWN)
	_sut._create_test_registry([])
	# Act
	var push_result: int = _sut.get_class_for_movement_pattern(ECM.MovementPattern.PUSH)
	# Assert — spine still works independent of registry contents
	assert_eq(push_result, _STRIKE,
		"Rule 5: pattern API is independent of the registry — PUSH→STRIKE even with empty registry")

## test_transition_id_format_invariant.gd — Story 012 AC-37
##
## Governing story: production/epics/loot-drop-system/story-012-persistence-schema-migration.md
## Governing ADR  : ADR-0006 (Accepted) Contract 2 — transition_id format "%d_%d_%s_%s"
##
## AC-37: _validate_transition_id_format() must accept ADR-0006 Contract 2 formatted
## IDs and reject empty / too-short / special-char strings.
## The format is lenient: digits + hex chars + underscores + uppercase letters.
extends GutTest

## Autoload script preloaded as a const (shadows the LootDropSystem autoload
## global so tests can call .new() / access enums + constants on the class).
const LootDropSystem := preload("res://src/autoload/loot_drop_system.gd")


var _sut: LootDropSystem
var _config: LootRarityConfig


func _make_config() -> LootRarityConfig:
	var c := LootRarityConfig.new()
	c.workout_weight = 0.75
	c.rng_weight = 0.25
	c.target_exercises = 5
	c.pr_bonus_per_pr = 0.12
	c.max_pr_factor = 1.25
	c.streak_scale = 28.0
	c.max_streak_bonus = 0.20
	c.tier_thresholds = [0.0, 0.35, 0.55, 0.72, 0.88]
	c.tier_values = [0, 1, 2, 3, 4]
	return c


func before_each() -> void:
	_config = _make_config()
	_sut = LootDropSystem.new()
	_sut._config = _config
	add_child_autofree(_sut)
	await get_tree().process_frame


func after_each() -> void:
	_sut = null
	_config = null


# ── AC-37: valid formats ────────────────────────────────────────────────────────

func test_ac37_adr006_contract2_format_is_valid() -> void:
	# "%d_%d_%s_%s" example: "1234567_42_IDLE_COMBAT_ACTIVE"
	assert_true(
		_sut._validate_transition_id_format("1234567_42_IDLE_COMBAT_ACTIVE"),
		"AC-37: ADR-0006 Contract 2 format '1234567_42_IDLE_COMBAT_ACTIVE' must be valid"
	)


func test_ac37_simple_hex_string_is_valid() -> void:
	assert_true(
		_sut._validate_transition_id_format("abcdef01"),
		"Pure hex string must be valid"
	)


func test_ac37_numeric_only_four_chars_is_valid() -> void:
	# Story notes say numeric-only "1234" → valid (subset of hex).
	assert_true(
		_sut._validate_transition_id_format("1234"),
		"AC-37: Numeric-only 4-char string must be valid (subset of hex chars)"
	)


func test_ac37_underscores_and_uppercase_is_valid() -> void:
	assert_true(
		_sut._validate_transition_id_format("ABC_DEF_1234"),
		"Underscores and uppercase letters must be valid per lenient pattern"
	)


func test_ac37_minimum_four_chars_boundary() -> void:
	assert_true(
		_sut._validate_transition_id_format("abcd"),
		"Exactly 4 characters must be valid (minimum length)"
	)


# ── AC-37: invalid formats ─────────────────────────────────────────────────────

func test_ac37_empty_string_is_invalid() -> void:
	assert_false(
		_sut._validate_transition_id_format(""),
		"AC-37: Empty string must be invalid"
	)


func test_ac37_three_chars_below_minimum_is_invalid() -> void:
	assert_false(
		_sut._validate_transition_id_format("abc"),
		"AC-37: 3-char string is below minimum length (4) — invalid"
	)


func test_ac37_special_chars_invalid() -> void:
	assert_false(
		_sut._validate_transition_id_format("T!@#rollback"),
		"AC-37: String with '!@#' special chars must be invalid"
	)


func test_ac37_spaces_invalid() -> void:
	assert_false(
		_sut._validate_transition_id_format("T abc def"),
		"AC-37: String with spaces must be invalid"
	)


func test_ac37_dot_separator_invalid() -> void:
	# Dots are NOT in the valid character set.
	assert_false(
		_sut._validate_transition_id_format("T.abc.def"),
		"AC-37: String with '.' separators must be invalid (only _ allowed)"
	)


# ── Invariant verification ─────────────────────────────────────────────────────

func test_ac37_current_schema_constant_is_one() -> void:
	assert_eq(LootDropSystem.CURRENT_SCHEMA, 1,
		"CURRENT_SCHEMA must be 1 (first schema version)")

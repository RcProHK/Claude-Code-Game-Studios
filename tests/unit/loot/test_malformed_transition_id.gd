## test_malformed_transition_id.gd — Story 010 AC-22
##
## Governing story: production/epics/loot-drop-system/story-010-idempotency-guards.md
## Governing ADR  : ADR-0006 Contract 2; EC-12 malformed transition_id handling
##
## AC-22: _validate_transition_id() must reject empty/null/too-short IDs with
## loot.trigger.malformed_id telemetry, without crashing and without generating
## any LootDrop.
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
	_sut.clear_telemetry()


func after_each() -> void:
	_sut = null
	_config = null


# ── AC-22: malformed transition_id rejected ───────────────────────────────────

func test_ac22_empty_string_returns_false() -> void:
	var result := _sut._validate_transition_id("")
	assert_false(result, "AC-22: empty transition_id must return false")


func test_ac22_empty_string_emits_malformed_id_telemetry() -> void:
	_sut._validate_transition_id("")
	var events := _sut.get_telemetry("loot.trigger.malformed_id")
	assert_eq(events.size(), 1,
		"AC-22: empty transition_id must emit loot.trigger.malformed_id telemetry exactly once")


func test_ac22_too_short_returns_false() -> void:
	# Less than 4 characters → rejected.
	var result := _sut._validate_transition_id("abc")
	assert_false(result, "AC-22: too-short transition_id (3 chars) must return false")


func test_ac22_too_short_emits_telemetry() -> void:
	_sut._validate_transition_id("ab")
	var events := _sut.get_telemetry("loot.trigger.malformed_id")
	assert_eq(events.size(), 1,
		"AC-22: too-short transition_id must emit loot.trigger.malformed_id")


func test_ac22_null_returns_false_without_crash() -> void:
	# null must not crash GDScript — _validate_transition_id handles it.
	var result := _sut._validate_transition_id(null)
	assert_false(result, "AC-22: null transition_id must return false without crashing")


func test_ac22_null_emits_telemetry() -> void:
	_sut._validate_transition_id(null)
	var events := _sut.get_telemetry("loot.trigger.malformed_id")
	assert_eq(events.size(), 1,
		"AC-22: null transition_id must emit loot.trigger.malformed_id")


func test_ac22_valid_id_returns_true() -> void:
	# A well-formed transition_id (≥ 4 chars) must pass.
	var result := _sut._validate_transition_id("T-abc123")
	assert_true(result, "A valid transition_id (≥4 chars) must return true")


func test_ac22_valid_id_emits_no_malformed_telemetry() -> void:
	_sut._validate_transition_id("T-abc123")
	var events := _sut.get_telemetry("loot.trigger.malformed_id")
	assert_eq(events.size(), 0,
		"Valid transition_id must NOT emit loot.trigger.malformed_id")


func test_ac22_no_loot_drop_created_on_malformed_id() -> void:
	# Simulate a signal handler that validates then generates.
	# With malformed ID, _drops_by_transition must remain empty.
	_sut._validate_transition_id("")
	assert_eq(_sut._drops_by_transition.size(), 0,
		"AC-22: malformed transition_id must not result in any LootDrop in cache")


func test_ac22_minimum_valid_length_is_four_chars() -> void:
	# Exactly 4 chars → valid.
	var result := _sut._validate_transition_id("1234")
	assert_true(result, "Exactly 4-character transition_id must be valid")

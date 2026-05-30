## test_force_test_drop_release_guard.gd — Story 010 AC-25
##
## Governing story: production/epics/loot-drop-system/story-010-idempotency-guards.md
## Governing ADR  : ADR-0005; GDD Rule 12 + EC-34 (debug surface release guard)
##
## AC-25: _force_test_drop() in a simulated release build must emit
## loot.debug.production_leak CRITICAL telemetry and return null (no drop generated).
## In debug build it proceeds normally.
##
## NOTE: OS.is_debug_build() cannot be mocked directly — LootDropSystem exposes
## _debug_build_override var (bool, default = OS.is_debug_build()) that tests set
## to simulate release behavior. This is the same pattern used in StatSystem.
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


# ── AC-25: release guard ──────────────────────────────────────────────────────

func test_ac25_simulated_release_build_emits_production_leak_telemetry() -> void:
	# Arrange: simulate release build.
	_sut._debug_build_override = false
	# Act.
	_sut._force_test_drop(LootEnums.RarityTier.LEGENDARY)
	# Assert: CRITICAL telemetry emitted.
	var events := _sut.get_telemetry("loot.debug.production_leak")
	assert_eq(events.size(), 1,
		"AC-25: simulated release build must emit loot.debug.production_leak exactly once")


func test_ac25_simulated_release_build_returns_null() -> void:
	_sut._debug_build_override = false
	var result := _sut._force_test_drop(LootEnums.RarityTier.LEGENDARY)
	assert_null(result,
		"AC-25: _force_test_drop in simulated release build must return null (no drop generated)")


func test_ac25_simulated_release_build_no_drop_in_cache() -> void:
	_sut._debug_build_override = false
	_sut._force_test_drop(LootEnums.RarityTier.RARE)
	assert_eq(_sut._drops_by_transition.size(), 0,
		"AC-25: release build must not add any drop to _drops_by_transition cache")


func test_ac25_simulated_release_rarity_carried_in_telemetry() -> void:
	_sut._debug_build_override = false
	_sut._force_test_drop(LootEnums.RarityTier.EPIC)
	var events := _sut.get_telemetry("loot.debug.production_leak")
	assert_eq(events.size(), 1)
	assert_eq(events[0]["data"]["rarity"], LootEnums.RarityTier.EPIC,
		"AC-25: production_leak telemetry must carry the requested rarity tier")


func test_ac25_debug_build_proceeds_without_telemetry() -> void:
	# _debug_build_override defaults to OS.is_debug_build() (true in CI).
	# In debug mode: no production_leak telemetry; returns a drop.
	# NOTE: assert(false, ...) would crash in debug — our impl only fires in release.
	_sut._debug_build_override = true
	var result := _sut._force_test_drop(LootEnums.RarityTier.COMMON)
	var leak_events := _sut.get_telemetry("loot.debug.production_leak")
	assert_eq(leak_events.size(), 0,
		"Debug build must NOT emit production_leak telemetry")
	assert_not_null(result, "Debug build must return a non-null LootDrop")


func test_ac25_debug_build_returns_drop_with_correct_tier_string() -> void:
	_sut._debug_build_override = true
	var result := _sut._force_test_drop(LootEnums.RarityTier.RARE)
	assert_not_null(result)
	assert_eq(result.rarity_tier, "RARE",
		"Debug _force_test_drop must set rarity_tier to 'RARE' string name")

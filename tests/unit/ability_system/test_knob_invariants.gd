# Unit tests — AbilitySystem cross-knob invariants (Story 009 / AC-24..AC-27).
#
# Hard-pin the 8 cross-knob invariants by referencing the ACTUAL constants on ability_system.gd
# (never hardcoded knob literals), so a future knob change breaks exactly the invariant it
# violates. INV-2/INV-3 reference StatSystem's DEFAULT_BASE_VALUE (10) and MAX_STAT_VALUE (999)
# directly (cross-system invariant, same pattern as the GSM _assert_knob_invariants).
#
# Note: this file is distinct from tests/unit/stat_system/test_knob_invariants.gd (StatSystem) and
# tests/unit/state_machine/test_knob_invariants.gd (GSM).
extends GutTest

const AbilitySystem := preload("res://src/autoload/ability_system.gd")
const StatSystemScript := preload("res://src/autoload/stat_system.gd")

# Tier keys (AbilityTier ordinals) for the threshold / cooldown dictionaries.
var T1: int
var T2: int
var T3: int


func before_all() -> void:
	T1 = AbilitySystem.AbilityTier.TIER_1
	T2 = AbilitySystem.AbilityTier.TIER_2
	T3 = AbilitySystem.AbilityTier.TIER_3


# --- AC-24: INV-1 + INV-4 strict monotonic -----------------------------------------------------

func test_inv1_thresholds_strictly_monotonic() -> void:
	var th: Dictionary = AbilitySystem.TIER_THRESHOLDS
	assert_lt(th[T1], th[T2], "INV-1: TIER_1_THRESHOLD < TIER_2_THRESHOLD")
	assert_lt(th[T2], th[T3], "INV-1: TIER_2_THRESHOLD < TIER_3_THRESHOLD")


func test_inv4_cooldowns_strictly_monotonic() -> void:
	var cd: Dictionary = AbilitySystem.BASE_COOLDOWN_SEC
	assert_lt(cd[T1], cd[T2], "INV-4: TIER_1 cooldown < TIER_2 cooldown")
	assert_lt(cd[T2], cd[T3], "INV-4: TIER_2 cooldown < TIER_3 cooldown")


# --- AC-25: INV-2 anchor + INV-3 ceiling (cross-system with StatSystem) -------------------------

func test_inv2_tier1_threshold_at_least_stat_default() -> void:
	# INV-2: a first-boot character (stat default) must reach TIER_1 (auto-unlock onboarding moment).
	assert_gte(AbilitySystem.TIER_THRESHOLDS[T1], StatSystemScript.DEFAULT_BASE_VALUE,
		"INV-2: TIER_1_THRESHOLD must be >= StatSystem.DEFAULT_BASE_VALUE (%d)" % int(StatSystemScript.DEFAULT_BASE_VALUE))


func test_inv3_tier3_threshold_below_grind_ceiling() -> void:
	# INV-3: TIER_3 must be reachable within a quarter of the stat range (no grind ceiling).
	var ceiling: int = floori(StatSystemScript.MAX_STAT_VALUE * 0.25)
	assert_lte(AbilitySystem.TIER_THRESHOLDS[T3], ceiling,
		"INV-3: TIER_3_THRESHOLD must be <= floor(MAX_STAT_VALUE * 0.25) = %d" % ceiling)


# --- AC-26: INV-5 floor + INV-6 ceiling + INV-7 ratio ------------------------------------------

func test_inv5_tier1_cooldown_floor() -> void:
	assert_gte(AbilitySystem.BASE_COOLDOWN_SEC[T1], 2.0, "INV-5: TIER_1 cooldown >= 2.0 (anti-spam floor)")


func test_inv6_tier3_cooldown_ceiling() -> void:
	assert_lte(AbilitySystem.BASE_COOLDOWN_SEC[T3], 15.0, "INV-6: TIER_3 cooldown <= 15.0 (anti-dead-time)")


func test_inv7_cooldown_ratio_cap() -> void:
	var ratio: float = AbilitySystem.BASE_COOLDOWN_SEC[T3] / AbilitySystem.BASE_COOLDOWN_SEC[T1]
	assert_lte(ratio, 4.0, "INV-7: TIER_3/TIER_1 cooldown ratio (%f) must be <= 4.0" % ratio)


# --- AC-27: INV-8 all 8 owned knobs within their safe ranges (ADVISORY) ------------------------

func test_inv8_all_knobs_within_safe_range() -> void:
	# {name: [value, safe_min, safe_max]} — safe ranges from GDD Section G knob table.
	var knobs: Dictionary = {
		"TIER_1_THRESHOLD":         [float(AbilitySystem.TIER_THRESHOLDS[T1]), 5.0, 30.0],
		"TIER_2_THRESHOLD":         [float(AbilitySystem.TIER_THRESHOLDS[T2]), 30.0, 100.0],
		"TIER_3_THRESHOLD":         [float(AbilitySystem.TIER_THRESHOLDS[T3]), 100.0, 400.0],
		"TIER_1_BASE_COOLDOWN_SEC": [AbilitySystem.BASE_COOLDOWN_SEC[T1], 2.0, 5.0],
		"TIER_2_BASE_COOLDOWN_SEC": [AbilitySystem.BASE_COOLDOWN_SEC[T2], 4.0, 9.0],
		"TIER_3_BASE_COOLDOWN_SEC": [AbilitySystem.BASE_COOLDOWN_SEC[T3], 7.0, 15.0],
		"MINIMUM_ACTIVE_STAT":      [AbilitySystem.MINIMUM_ACTIVE_STAT, 3.0, 15.0],
		"MAX_EMIT_DEPTH":           [float(AbilitySystem.MAX_EMIT_DEPTH), 0.0, 4.0],
	}
	assert_eq(knobs.size(), 8, "AC-27: exactly 8 owned knobs are range-checked")
	for knob_name: String in knobs:
		var row: Array = knobs[knob_name]
		assert_between(row[0], row[1], row[2],
			"AC-27 (INV-8): %s = %f outside safe range [%f, %f]" % [knob_name, row[0], row[1], row[2]])

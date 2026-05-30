# StatSystem — Story 012 Cross-Knob Invariants (AC-30 / AC-31 / AC-32) Unit Tests.
#
# Scope: hard-pin the 9 cross-knob invariants (the assert subset INV-1/3/4/5/6/8 plus
# the INV-9 safe-range sweep). Every assertion references the ACTUAL constants from
# stat_system.gd (StatSystem.PR_BASE, etc.) — NEVER a hardcoded knob literal — so any
# future knob change breaks exactly the invariant it violates with a clear diagnostic.
# This mirrors the GSM _assert_knob_invariants pattern (ADR-0006 Contract 8).
#
# No instance / boot required — invariants are compile-time const relationships read
# straight off the script class.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/stat-system.md §G Cross-Knob Invariants (INV-1..INV-9)
# Story: production/epics/stat-system/story-012-cross-knob-invariants.md
extends GutTest

const StatSystem := preload("res://src/autoload/stat_system.gd")


# --- AC-30: INV-1 / INV-3 / INV-4 / INV-5 baseline invariants -----------------

func test_inv1_pr_base_bounded() -> void:
	# INV-1: a single PR can never swing a stat by more than half the [0,50] band.
	assert_lt(StatSystem.PR_BASE * 2.0, 50.0,
		"INV-1: PR_BASE*2 (%f) must stay below 50.0" % (StatSystem.PR_BASE * 2.0))


func test_inv3_hp_floor_reachable() -> void:
	# INV-3: a level-1 (VIT=10) entity must have at least 150 HP from the formula.
	var hp_at_ten_vit: float = StatSystem.HP_BASE + 10.0 * StatSystem.HP_PER_VIT
	assert_gte(hp_at_ten_vit, 150.0,
		"INV-3: HP_BASE + 10*HP_PER_VIT (%f) must be >= 150" % hp_at_ten_vit)


func test_inv4_str_dominates_dex_in_attack() -> void:
	# INV-4: DEX must never out-scale STR in ATTACK_POWER (DEX < STR/2 per unit).
	assert_lt(StatSystem.ATK_PER_DEX * 2.0, StatSystem.ATK_PER_STR,
		"INV-4: ATK_PER_DEX*2 (%f) must be < ATK_PER_STR (%f) — STR must dominate"
			% [StatSystem.ATK_PER_DEX * 2.0, StatSystem.ATK_PER_STR])


func test_inv5_attack_floor_reachable() -> void:
	# INV-5: a level-1 (STR=DEX=10) entity must have at least 25 ATTACK_POWER.
	var atk_at_ten: float = StatSystem.ATK_BASE + 10.0 * StatSystem.ATK_PER_STR + 10.0 * StatSystem.ATK_PER_DEX
	assert_gte(atk_at_ten, 25.0,
		"INV-5: ATK_BASE + 10*ATK_PER_STR + 10*ATK_PER_DEX (%f) must be >= 25" % atk_at_ten)


# --- AC-31: INV-6 / INV-8 stat-only cap reachable (CF-3) ----------------------

func test_inv6_move_cap_reachable_by_stat_alone() -> void:
	# INV-6: max DEX alone must exceed MOVE_CAP (the cap is reachable without equipment).
	var move_at_max_dex: float = StatSystem.MOVE_BASE + StatSystem.MAX_STAT_VALUE * StatSystem.MOVE_PER_DEX
	assert_gt(move_at_max_dex, StatSystem.MOVE_CAP,
		"INV-6: MOVE_BASE + MAX*MOVE_PER_DEX (%f) must exceed MOVE_CAP (%f)"
			% [move_at_max_dex, StatSystem.MOVE_CAP])


func test_inv8_crit_cap_reachable_within_stat_range() -> void:
	# INV-8: the DEX needed to hit MAX_CRIT_CHANCE must fall within [100, MAX_STAT_VALUE].
	var dex_for_max_crit: float = StatSystem.MAX_CRIT_CHANCE / StatSystem.CRIT_PER_DEX
	assert_between(dex_for_max_crit, 100.0, StatSystem.MAX_STAT_VALUE,
		"INV-8: DEX_FOR_MAX_CRIT (%f) must be within [100, MAX_STAT_VALUE]" % dex_for_max_crit)


# --- AC-32 (ADVISORY): INV-9 all 15 knobs within their safe ranges ------------

## Safe ranges are design documentation (GDD Section G), hardcoded here as the
## reference table. Each entry maps a knob's current value to its [min, max] band.
func test_inv9_all_knobs_within_safe_range() -> void:
	# {name: [value, safe_min, safe_max]}
	var knobs: Dictionary = {
		"MAX_STAT_VALUE":    [StatSystem.MAX_STAT_VALUE, 100.0, 9999.0],
		"DEFAULT_BASE_VALUE":[StatSystem.DEFAULT_BASE_VALUE, 1.0, 50.0],
		"VOLUME_TICK_BASE":  [StatSystem.VOLUME_TICK_BASE, 0.02, 0.20],
		"PR_BASE":           [StatSystem.PR_BASE, 3.0, 12.0],
		"PR_DIMINISH_EXP":   [StatSystem.PR_DIMINISH_EXP, 1.0, 4.0],
		"HP_BASE":           [StatSystem.HP_BASE, 40.0, 200.0],
		"HP_PER_VIT":        [StatSystem.HP_PER_VIT, 2.0, 20.0],
		"ATK_BASE":          [StatSystem.ATK_BASE, 1.0, 50.0],
		"ATK_PER_STR":       [StatSystem.ATK_PER_STR, 0.5, 5.0],
		"ATK_PER_DEX":       [StatSystem.ATK_PER_DEX, 0.0, 1.0],
		"MOVE_BASE":         [StatSystem.MOVE_BASE, 100.0, 300.0],
		"MOVE_PER_DEX":      [StatSystem.MOVE_PER_DEX, 0.1, 2.0],
		"MOVE_CAP":          [StatSystem.MOVE_CAP, 300.0, 800.0],
		"CRIT_PER_DEX":      [StatSystem.CRIT_PER_DEX, 0.0005, 0.005],
		"MAX_CRIT_CHANCE":   [StatSystem.MAX_CRIT_CHANCE, 0.30, 0.75],
	}

	assert_eq(knobs.size(), 15, "AC-32: exactly 15 tuning knobs are range-checked")
	for knob_name: String in knobs:
		var row: Array = knobs[knob_name]
		var value: float = row[0]
		var lo: float = row[1]
		var hi: float = row[2]
		assert_between(value, lo, hi,
			"AC-32: %s = %f is outside safe range [%f, %f]" % [knob_name, value, lo, hi])

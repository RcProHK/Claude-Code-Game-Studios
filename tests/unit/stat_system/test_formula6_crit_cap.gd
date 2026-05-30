# StatSystem — Story 010 Formula F6 CRIT_CHANCE cap (AC-29) Unit Tests.
#
# Scope: verifies _compute_derived(CRIT_CHANCE) implements F6:
#   CRIT_CHANCE = min(DEX * CRIT_PER_DEX + equipment_delta, MAX_CRIT_CHANCE)
# Focus on the probability ceiling: a high DEX (plus an equipment crit bonus) drives the
# raw term over MAX_CRIT_CHANCE, so the result clamps to MAX_CRIT_CHANCE.
#
# DEX is set white-box via _base (fresh un-parented instance, no _ready()).
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/stat-system.md §H AC-29 (Formula F6 cap)
# Story: production/epics/stat-system/story-010-derived-stat-formulas.md
extends GutTest

const StatSystem := preload("res://src/autoload/stat_system.gd")

var _sut


func before_each() -> void:
	_sut = StatSystem.new()


func after_each() -> void:
	_sut.free()
	_sut = null


## AC-29: DEX=400 (raw 400*0.0015 = 0.60) plus a +0.10 equipment crit delta → 0.70,
## which exceeds MAX_CRIT_CHANCE (0.50); min() clamps to 0.50.
func test_formula6_crit_chance_clamps_to_cap() -> void:
	# Arrange — DEX = 400, equipment CRIT_CHANCE +0.10.
	_sut._base[_sut.StatId.DEX] = 400.0
	_sut.apply_equipment_modifier(
		&"assassins_mask",
		_sut.StatModifier.new({ _sut.StatId.CRIT_CHANCE: 0.10 })
	)

	# Act
	var crit: float = _sut.get_stat(_sut.StatId.CRIT_CHANCE)

	# Assert — raw 0.70 clamps to MAX_CRIT_CHANCE (0.50).
	assert_almost_eq(crit, StatSystem.MAX_CRIT_CHANCE, 0.0001,
		"AC-29: CRIT_CHANCE must clamp to MAX_CRIT_CHANCE (0.50) when raw exceeds it")


## AC-29: DEX alone at the cap boundary. MAX_CRIT_CHANCE / CRIT_PER_DEX = 0.50/0.0015 ≈ 333.3,
## so DEX above that drives raw past the cap with NO equipment — proving the base term alone
## can reach the ceiling (this is INV-8's "cap reachable" precondition).
func test_formula6_crit_chance_cap_from_dex_alone() -> void:
	# Arrange — DEX = 500 → raw = 500 * 0.0015 = 0.75 > 0.50.
	_sut._base[_sut.StatId.DEX] = 500.0

	# Act
	var crit: float = _sut.get_stat(_sut.StatId.CRIT_CHANCE)

	# Assert — clamped to the cap from the base term alone.
	assert_almost_eq(crit, StatSystem.MAX_CRIT_CHANCE, 0.0001,
		"AC-29: DEX alone (500) reaches the CRIT cap (0.50) with no equipment")


## AC-29: a sub-cap value passes through unclamped (proves the cap is a min(), not a
## hard assignment). DEX=100 → raw = 0.15, below the 0.50 cap.
func test_formula6_crit_chance_below_cap_passes_through() -> void:
	# Arrange — DEX = 100 → raw = 100 * 0.0015 = 0.15.
	_sut._base[_sut.StatId.DEX] = 100.0

	# Act
	var crit: float = _sut.get_stat(_sut.StatId.CRIT_CHANCE)

	# Assert — unclamped raw value.
	var expected: float = 100.0 * StatSystem.CRIT_PER_DEX
	assert_almost_eq(crit, expected, 0.0001,
		"AC-29: a sub-cap CRIT_CHANCE (0.15) is returned unclamped")

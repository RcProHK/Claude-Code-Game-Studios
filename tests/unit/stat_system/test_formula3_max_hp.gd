# StatSystem — Story 010 Formula F3 MAX_HP (AC-26) Unit Tests.
#
# Scope: verifies _compute_derived(MAX_HP) implements F3:
#   MAX_HP = max(1, int(HP_BASE + VIT * HP_PER_VIT + equipment_delta))
# Default knobs + baseline VIT (10) → 160. VIT scaling and the floor are also covered.
#
# A fresh, un-parented instance is used so _ready() never runs — _base holds the
# hardcoded 10.0 defaults the F3 baseline is derived from. VIT is set white-box via
# _base for the scaling cases (test context only).
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/stat-system.md §H AC-26 (Formula F3)
# Story: production/epics/stat-system/story-010-derived-stat-formulas.md
extends GutTest

const StatSystem := preload("res://src/autoload/stat_system.gd")

var _sut


func before_each() -> void:
	_sut = StatSystem.new()
	watch_signals(_sut)


func after_each() -> void:
	_sut.free()
	_sut = null


## AC-26: baseline VIT=10 → MAX_HP = max(1, int(80 + 10*8)) = 160.
func test_formula3_max_hp_baseline_vit_ten_is_160() -> void:
	# Arrange — fresh instance, _base[VIT] is the 10.0 default.

	# Act
	var max_hp: float = _sut.get_stat(_sut.StatId.MAX_HP)

	# Assert — referenced against the knob constants, not a magic number.
	var expected: int = maxi(1, int(StatSystem.HP_BASE + 10.0 * StatSystem.HP_PER_VIT))
	assert_eq(max_hp, float(expected), "AC-26: MAX_HP baseline (VIT=10) must be 160")
	assert_eq(max_hp, 160.0, "AC-26: MAX_HP baseline equals the GDD-stated 160")


## AC-26: MAX_HP scales linearly with VIT (HP_PER_VIT per point).
func test_formula3_max_hp_scales_with_vit() -> void:
	# Arrange — VIT = 30 (white-box set; no _ready()).
	_sut._base[_sut.StatId.VIT] = 30.0

	# Act
	var max_hp: float = _sut.get_stat(_sut.StatId.MAX_HP)

	# Assert — 80 + 30*8 = 320.
	var expected: int = maxi(1, int(StatSystem.HP_BASE + 30.0 * StatSystem.HP_PER_VIT))
	assert_eq(max_hp, float(expected), "AC-26: MAX_HP at VIT=30 must be 320")


## AC-26: MAX_HP is floored at 1 even if the knobs/VIT would drive it to 0 or below.
func test_formula3_max_hp_floored_at_one() -> void:
	# Arrange — VIT = 0 and a negative equipment delta large enough to drive the
	# raw term below 1, proving the maxi(1, ...) floor holds.
	_sut._base[_sut.StatId.VIT] = 0.0
	_sut.apply_equipment_modifier(
		&"cursed_relic",
		_sut.StatModifier.new({ _sut.StatId.MAX_HP: -1000.0 })
	)

	# Act
	var max_hp: float = _sut.get_stat(_sut.StatId.MAX_HP)

	# Assert — raw would be 80 + 0 - 1000 < 0, floored to 1.
	assert_eq(max_hp, 1.0, "AC-26: MAX_HP must floor at 1, never 0 or negative")

# StatSystem — Story 010 default derived baseline (AC-27 / CF-1) Unit Tests.
#
# Scope: CF-1 canonical fixture — with all default knobs and the first-boot base stats
# (STR=DEX=VIT=10) and NO equipment, the 4 derived stats settle at:
#   MAX_HP=160, ATTACK_POWER=28, MOVE_SPEED=184.0, CRIT_CHANCE=0.015.
# This is the cross-formula baseline snapshot; the per-formula edge tests (F3-F6) cover
# scaling and caps separately.
#
# Fresh un-parented instance → _ready() does not run → _base holds the 10.0 defaults.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/stat-system.md §H AC-27 (CF-1 canonical fixture)
# Story: production/epics/stat-system/story-010-derived-stat-formulas.md
extends GutTest

const StatSystem := preload("res://src/autoload/stat_system.gd")

var _sut


func before_each() -> void:
	_sut = StatSystem.new()


func after_each() -> void:
	_sut.free()
	_sut = null


## AC-27 / CF-1: MAX_HP default baseline = 160.
func test_default_baseline_max_hp_is_160() -> void:
	assert_eq(_sut.get_stat(_sut.StatId.MAX_HP), 160.0,
		"CF-1: MAX_HP default baseline (STR=DEX=VIT=10, no eq) is 160")


## AC-27 / CF-1: ATTACK_POWER default baseline = 28.
##   max(1, int(10 + 10*1.5 + 10*0.3)) = max(1, int(28.0)) = 28.
func test_default_baseline_attack_power_is_28() -> void:
	var expected: int = maxi(1, int(
		StatSystem.ATK_BASE
		+ 10.0 * StatSystem.ATK_PER_STR
		+ 10.0 * StatSystem.ATK_PER_DEX
	))
	assert_eq(_sut.get_stat(_sut.StatId.ATTACK_POWER), float(expected),
		"CF-1: ATTACK_POWER default baseline is 28")
	assert_eq(_sut.get_stat(_sut.StatId.ATTACK_POWER), 28.0,
		"CF-1: ATTACK_POWER equals the GDD-stated 28")


## AC-27 / CF-1: MOVE_SPEED default baseline = 184.0 (well under the 420 cap).
func test_default_baseline_move_speed_is_184() -> void:
	var expected: float = minf(
		StatSystem.MOVE_BASE + 10.0 * StatSystem.MOVE_PER_DEX,
		StatSystem.MOVE_CAP
	)
	assert_almost_eq(_sut.get_stat(_sut.StatId.MOVE_SPEED), expected, 0.0001,
		"CF-1: MOVE_SPEED default baseline is 184.0")
	assert_almost_eq(_sut.get_stat(_sut.StatId.MOVE_SPEED), 184.0, 0.0001,
		"CF-1: MOVE_SPEED equals the GDD-stated 184.0")


## AC-27 / CF-1: CRIT_CHANCE default baseline = 0.015 (well under the 0.50 cap).
func test_default_baseline_crit_chance_is_0015() -> void:
	var expected: float = minf(
		10.0 * StatSystem.CRIT_PER_DEX,
		StatSystem.MAX_CRIT_CHANCE
	)
	assert_almost_eq(_sut.get_stat(_sut.StatId.CRIT_CHANCE), expected, 0.0001,
		"CF-1: CRIT_CHANCE default baseline is 0.015")
	assert_almost_eq(_sut.get_stat(_sut.StatId.CRIT_CHANCE), 0.015, 0.0001,
		"CF-1: CRIT_CHANCE equals the GDD-stated 0.015")

# StatSystem — Story 010 Formula F5 MOVE_SPEED cap (AC-28) Unit Tests.
#
# Scope: verifies _compute_derived(MOVE_SPEED) implements F5:
#   MOVE_SPEED = min(MOVE_BASE + DEX * MOVE_PER_DEX + equipment_delta, MOVE_CAP)
# Focus on the cap: a high DEX drives the raw term over MOVE_CAP, so the result clamps
# to MOVE_CAP. Below-cap scaling is covered by the CF-1 baseline test.
#
# DEX is set white-box via _base (fresh un-parented instance, no _ready()), which is the
# simplest way to reach the cap without driving DEX up through many apply_stat_delta calls.
# An equipment MOVE_SPEED modifier exercises the equipment term under the same cap.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/stat-system.md §H AC-28 (Formula F5 cap)
# Story: production/epics/stat-system/story-010-derived-stat-formulas.md
extends GutTest

const StatSystem := preload("res://src/autoload/stat_system.gd")

var _sut


func before_each() -> void:
	_sut = StatSystem.new()


func after_each() -> void:
	_sut.free()
	_sut = null


## AC-28: DEX=600 drives the raw term (180 + 600*0.4 = 420... actually 180+240=420) above/at
## the cap. Use DEX=600 → raw = 180 + 240 = 420, which equals MOVE_CAP. To prove the cap
## CLAMPS (not just coincidentally equals), push DEX higher so raw strictly exceeds the cap.
func test_formula5_move_speed_clamps_to_cap_at_high_dex() -> void:
	# Arrange — DEX = 700 → raw = 180 + 700*0.4 = 460 > MOVE_CAP (420).
	_sut._base[_sut.StatId.DEX] = 700.0

	# Act
	var move_speed: float = _sut.get_stat(_sut.StatId.MOVE_SPEED)

	# Assert — clamped to MOVE_CAP.
	assert_almost_eq(move_speed, StatSystem.MOVE_CAP, 0.0001,
		"AC-28: MOVE_SPEED must clamp to MOVE_CAP (420) when raw exceeds it")


## AC-28: DEX=600 lands the raw term exactly on the cap (180 + 600*0.4 = 420 == MOVE_CAP);
## min() returns the cap value (boundary case — equal, not exceeding).
func test_formula5_move_speed_at_exact_cap_boundary() -> void:
	# Arrange — DEX = 600 → raw = 180 + 240 = 420 == MOVE_CAP.
	_sut._base[_sut.StatId.DEX] = 600.0

	# Act
	var move_speed: float = _sut.get_stat(_sut.StatId.MOVE_SPEED)

	# Assert — exactly MOVE_CAP.
	assert_almost_eq(move_speed, StatSystem.MOVE_CAP, 0.0001,
		"AC-28: MOVE_SPEED at the exact cap boundary equals MOVE_CAP (420)")


## AC-28: the equipment MOVE_SPEED delta is folded into the raw term BEFORE the cap, so a
## big equipment bonus on top of a moderate DEX still clamps at MOVE_CAP.
func test_formula5_move_speed_cap_applies_after_equipment() -> void:
	# Arrange — DEX = 400 (raw 180 + 160 = 340, below cap), plus +200 equipment → 540 > cap.
	_sut._base[_sut.StatId.DEX] = 400.0
	_sut.apply_equipment_modifier(
		&"winged_boots",
		_sut.StatModifier.new({ _sut.StatId.MOVE_SPEED: 200.0 })
	)

	# Act
	var move_speed: float = _sut.get_stat(_sut.StatId.MOVE_SPEED)

	# Assert — equipment pushes it over the cap; result clamps to MOVE_CAP.
	assert_almost_eq(move_speed, StatSystem.MOVE_CAP, 0.0001,
		"AC-28: equipment delta is capped by MOVE_CAP (420)")

# StatSystem — AC-01 Stat surface LOCKED (Rule 1) Unit Tests
#
# Scope: verifies the 7-stat locked surface read path. get_stat() returns a
# float for each of the 3 base + 4 derived stats, and returns NAN (no crash)
# for an unknown stat_id.
#
# Surface note (Q1 / Q2 decision 2026-05-29; updated for Story 010):
#   Base stats read from _base (default 10.0). Derived stats now return their real
#   Formula F3-F6 baseline (Story 010 replaced the 0.0 placeholder). With the default
#   knobs and STR=DEX=VIT=10, no equipment: MAX_HP=160, ATTACK_POWER=28,
#   MOVE_SPEED=184.0, CRIT_CHANCE=0.015. The un-parented instance never runs _ready(),
#   so _base holds the hardcoded 10.0 defaults the formula baselines are computed from.
#
# Framework: GUT (Godot Unit Testing) v9.x
# Driving GDD: design/gdd/stat-system.md §H AC-01 (Rule 1)
extends GutTest


# A fresh, un-parented instance is used so _ready() (and any future boot
# reconciliation) never runs — the read path is tested against the load-bearing
# in-memory defaults, not whatever the live autoload happens to hold.
var _stat: Node = null


func before_each() -> void:
	_stat = preload("res://src/autoload/stat_system.gd").new()
	watch_signals(_stat)


func after_each() -> void:
	_stat.free()
	_stat = null


## AC-01: all 7 locked stat_ids return a float (base + derived).
func test_stat_system_get_stat_returns_float_for_all_seven_locked_stats() -> void:
	# Arrange
	var StatId = preload("res://src/autoload/stat_system.gd").StatId
	var locked_ids: Array[StringName] = [
		StatId.STR, StatId.DEX, StatId.VIT,
		StatId.MAX_HP, StatId.ATTACK_POWER, StatId.MOVE_SPEED, StatId.CRIT_CHANCE,
	]

	# Act + Assert
	for stat_id in locked_ids:
		var value: Variant = _stat.get_stat(stat_id)
		assert_true(value is float,
			"AC-01: get_stat('%s') must return a float" % stat_id)


## AC-01: the three base stats read back their first-boot default (10.0).
func test_stat_system_base_stats_default_to_ten() -> void:
	# Arrange
	var StatId = preload("res://src/autoload/stat_system.gd").StatId

	# Act + Assert
	assert_eq(_stat.get_stat(StatId.STR), 10.0, "AC-01: STR default is 10.0 (Rule 11)")
	assert_eq(_stat.get_stat(StatId.DEX), 10.0, "AC-01: DEX default is 10.0 (Rule 11)")
	assert_eq(_stat.get_stat(StatId.VIT), 10.0, "AC-01: VIT default is 10.0 (Rule 11)")


## Story 010 (AC-26..AC-29 baseline): derived stats now return their real Formula
## F3-F6 baseline (default knobs, STR=DEX=VIT=10, no equipment) — NOT the old 0.0
## placeholder. This locks the no-equipment baseline so a regression in the formula
## dispatch (or the knob constants) is caught here as well as in the dedicated F3-F6 tests.
func test_stat_system_derived_stats_return_formula_baseline() -> void:
	# Arrange
	var StatId = preload("res://src/autoload/stat_system.gd").StatId

	# Act + Assert — baselines per Story 010 derivation:
	#   MAX_HP        = max(1, int(80 + 10*8))            = 160
	#   ATTACK_POWER  = max(1, int(10 + 10*1.5 + 10*0.3)) = 28
	#   MOVE_SPEED    = min(180 + 10*0.4, 420)            = 184.0
	#   CRIT_CHANCE   = min(10*0.0015, 0.50)              = 0.015
	assert_eq(_stat.get_stat(StatId.MAX_HP), 160.0,
		"Story 010: MAX_HP baseline (VIT=10) is 160")
	assert_eq(_stat.get_stat(StatId.ATTACK_POWER), 28.0,
		"Story 010: ATTACK_POWER baseline (STR=DEX=10) is 28")
	assert_eq(_stat.get_stat(StatId.MOVE_SPEED), 184.0,
		"Story 010: MOVE_SPEED baseline (DEX=10) is 184.0")
	assert_almost_eq(_stat.get_stat(StatId.CRIT_CHANCE), 0.015, 0.0001,
		"Story 010: CRIT_CHANCE baseline (DEX=10) is 0.015")


## AC-01: unknown stat_id returns NAN, does NOT crash, and fires stat_mutation_rejected.
func test_stat_system_get_stat_unknown_id_returns_nan_no_crash() -> void:
	# Arrange — "luk" is not part of the locked surface (per AC-01 example).

	# Act
	var value: Variant = _stat.get_stat(&"luk")

	# Assert — NAN return + no crash + telemetry signal fires (AC-01 / Rule 1).
	assert_true(value is float, "AC-01: unknown-id return must still be a float")
	assert_true(is_nan(value), "AC-01: unknown stat_id must return NAN")
	assert_signal_emit_count(_stat, "stat_mutation_rejected", 1,
		"AC-01: stat_mutation_rejected must fire exactly once for unknown stat_id")
	var params: Array = get_signal_parameters(_stat, "stat_mutation_rejected", 0)
	assert_eq(params[3], "invalid_stat_id",
		"AC-01: rejection reason must be 'invalid_stat_id'")

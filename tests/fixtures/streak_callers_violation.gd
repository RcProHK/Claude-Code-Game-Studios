# Fixture — a forbidden get_streak_buff_multiplier() caller that check_streak_callers.gd
# MUST flag. Simulates an avatar-power system (e.g. abilities) reading the streak buff.
# NOT production code; consumed by test_streak_caller_whitelist.gd only.
extends Node

var _streak  # untyped autoload ref


func _bad() -> void:
	var buff: float = _streak.get_streak_buff_multiplier()   # FORBIDDEN — streak is not avatar power
	var _unused := buff

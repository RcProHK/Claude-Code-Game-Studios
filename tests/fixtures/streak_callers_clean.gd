# Fixture — legal forms that check_streak_callers.gd must NOT flag. A commented example
# of the banned call must not false-positive; ordinary streak reads (current streak, not
# the buff multiplier) are fine. NOT production code; consumed by test only.
extends Node

var _streak  # untyped autoload ref


func _good() -> void:
	var n: int = _streak.get_current_streak()        # reading current streak is fine
	var m: bool = _streak.is_milestone_unlocked(7)   # milestone query is fine
	var _unused := n
	var _unused2 := m


func _commented_ban_ignored() -> void:
	# _streak.get_streak_buff_multiplier()   ← commented example, must NOT match
	pass

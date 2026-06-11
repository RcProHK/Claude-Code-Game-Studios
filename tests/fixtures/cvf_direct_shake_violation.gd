extends Node
## FIXTURE — deliberate R-13 violation for check_cvf_no_direct_shake.gd detection test.
## NOT production code; never registered as an autoload. Mirrors what a buggy #25 would
## look like if it double-shook (direct shake on top of #6 auto-dispatch).

var _screen_fx = null


func _bad_route_heavy() -> void:
	# VIOLATION: #25 must never direct-shake — shake is #6 auto-dispatch (R-13).
	_screen_fx.shake(0.4, 0.12)
	_screen_fx.hit_pause(0.065)  # this line is legal (only hit_pause is allowed)

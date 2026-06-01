# Fixture — legal forms that check_screen_effects_callers.gd must NOT flag.
# Routes through ScreenEffects API; commented banned line must not false-positive.
# Consumed by test_screen_effects_ci_lint.gd.
extends Node


func _good() -> void:
	ScreenEffects.shake(0.4, 0.12)
	ScreenEffects.hit_pause(0.06)
	ScreenEffects.set_motion_intensity(0.7)
	var sprite_offset := Vector2(3, 4)  # plain `.offset` — not a Camera2D, must NOT match
	var _unused := sprite_offset


func _commented_bans_ignored() -> void:
	# get_tree().paused = true        ← commented example, must NOT match
	# Engine.time_scale = 0.0         ← commented example, must NOT match
	pass

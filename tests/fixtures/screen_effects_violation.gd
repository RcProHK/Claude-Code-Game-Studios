# Fixture — banned screen-feel mutations that check_screen_effects_callers.gd MUST flag.
# NOT production code; consumed by test_screen_effects_ci_lint.gd only. One line per pattern.
extends Node


func _bad() -> void:
	(get_node("Cam") as Camera2D).offset = Vector2(1, 2)               # Camera2D.offset
	Engine.time_scale = 0.0                                             # Engine.time_scale
	get_tree().paused = true                                            # get_tree().paused
	RenderingServer.global_shader_parameter_set("u_shake_offset", Vector2.ZERO)  # uniform literal
